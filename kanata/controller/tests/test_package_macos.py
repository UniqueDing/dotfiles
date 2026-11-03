import hashlib
from pathlib import Path
import platform
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import package_macos as PACKAGER


def header(cpu=0x0100000C):
    value = bytearray(16)
    value[:4] = b"\xcf\xfa\xed\xfe"
    struct.pack_into("<I", value, 4, cpu)
    struct.pack_into("<I", value, 12, 2)
    return value


DEPENDENCIES = "controller:\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1336.0.0)\n\t/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 2575.0.0)\n"
COMMANDS = "Load command 1\n      cmd LC_BUILD_VERSION\n  cmdsize 32\n platform 1\n    minos 11.0\n      sdk 14.0\n"


class PackageMacosTests(unittest.TestCase):
    def test_apple_silicon_executable_is_accepted(self):
        PACKAGER.validate_metadata(header(), DEPENDENCIES, COMMANDS)
        PACKAGER.validate_metadata(header(), DEPENDENCIES, COMMANDS.replace("minos 11.0", "minos 11.0.0"))

    def test_non_macos_platform_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "macOS platform"):
            PACKAGER.validate_metadata(header(), DEPENDENCIES, COMMANDS.replace("platform 1", "platform 2"))

    def test_architecture_mismatch_and_fat_files_are_rejected(self):
        for value in [header(0x01000007), b"\xca\xfe\xba\xbe" + bytes(12)]:
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "Mach-O executable"):
                PACKAGER.validate_metadata(value, DEPENDENCIES, COMMANDS)

    def test_nix_libraries_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Nix-store"):
            PACKAGER.validate_metadata(header(),
                                       DEPENDENCIES.replace("/usr/lib/", "/nix/store/fixture/lib/"), COMMANDS)

    def test_homebrew_and_relative_libraries_are_rejected(self):
        for path in ["/opt/homebrew/lib/libiconv.dylib", "/usr/local/opt/libiconv/lib/libiconv.dylib",
                     "@rpath/libiconv.dylib", "@loader_path/libiconv.dylib"]:
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Apple system"):
                PACKAGER.validate_metadata(header(),
                                           f"controller:\n\t{path} (compatibility version 1.0.0)\n", COMMANDS)

    def test_runtime_search_path_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "search paths"):
            PACKAGER.validate_metadata(header(),
                                       DEPENDENCIES, COMMANDS + "      cmd LC_RPATH\n path /opt/homebrew/lib\n")

    def test_missing_or_new_deployment_target_is_rejected(self):
        for commands in [COMMANDS.replace("    minos 11.0\n", ""),
                         COMMANDS.replace("minos 11.0", "minos 14.0")]:
            with self.subTest(commands=commands), self.assertRaisesRegex(ValueError, "deployment target"):
                PACKAGER.validate_metadata(header(),
                                           DEPENDENCIES, commands)

    def test_package_contents_and_checksum_with_validated_fixture(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "controller-fixture"
            binary.write_bytes(header())
            binary.chmod(0o755)
            with patch.object(PACKAGER.subprocess, "check_output", side_effect=[DEPENDENCIES, COMMANDS]):
                PACKAGER.package(binary, "0.1.0", root / "dist", 1234567890)
            name = "kanata-controller-0.1.0-aarch64-apple-darwin.tar.gz"
            archive = root / "dist" / name
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual((root / "dist/SHA256SUMS").read_text(), f"{digest}  {name}\n")
            with tarfile.open(archive) as bundle:
                self.assertEqual(bundle.getnames(), ["kanata-controller", "README.md"])
                self.assertEqual(bundle.getmember("kanata-controller").mode, 0o755)

    @unittest.skipUnless(sys.platform == "darwin" and platform.machine() == "arm64",
                         "needs native Apple Silicon macOS SDK and tools")
    def test_native_macho_can_be_packaged(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "controller-fixture"
            subprocess.run(["/usr/bin/xcrun", "clang", "-arch", "arm64", "-mmacosx-version-min=11.0",
                            "-x", "c", "-o", str(binary), "-"],
                           input="int main(void) { return 0; }\n", text=True, check=True)
            PACKAGER.package(binary, "0.1.0", root / "dist", 1234567890)


if __name__ == "__main__":
    unittest.main()
