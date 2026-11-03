import hashlib
import importlib.util
from pathlib import Path
import shutil
import struct
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("package_linux", ROOT / "scripts/package_linux.py")
PACKAGER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGER)
HEADER = bytearray(20)
HEADER[:6] = b"\x7fELF\x02\x01"
struct.pack_into("<H", HEADER, 18, 62)
METADATA = "[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]\nGLIBC_2.2.5 GLIBC_2.34 GLIBC_2.35\n"


class PackageLinuxTests(unittest.TestCase):
    def test_workflow_initializes_cargo_directory_at_runtime(self):
        workflow = (ROOT.parents[1] / ".github/workflows/kanata-controller-linux.yml").read_text()
        lines = workflow.splitlines()
        for index, line in enumerate(lines):
            if line != "    env:":
                continue
            for entry in lines[index + 1:]:
                if entry and not entry.startswith("      "):
                    break
                self.assertNotIn("runner.", entry, "runner context is unavailable in job-level env")
        self.assertIn('"$RUNNER_TEMP" >> "$GITHUB_ENV"', workflow)

    def test_compatible_gnu_elf_is_accepted(self):
        PACKAGER.validate_metadata(HEADER, METADATA)

    def test_nix_loader_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Nix-store"):
            PACKAGER.validate_metadata(HEADER, METADATA.replace("/lib64/", "/nix/store/fixture/lib/"))

    def test_nix_library_path_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Nix-store"):
            PACKAGER.validate_metadata(HEADER, METADATA + "(RUNPATH) [/nix/store/fixture/lib]")

    def test_other_runtime_search_paths_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "search path"):
            PACKAGER.validate_metadata(HEADER, METADATA + "(RPATH) [/home/build/lib]")

    def test_too_new_glibc_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "glibc 2.35"):
            PACKAGER.validate_metadata(HEADER, METADATA + "GLIBC_2.39")

    def test_non_gnu_loader_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "dynamic loader"):
            PACKAGER.validate_metadata(HEADER, METADATA.replace("/lib64/", "/custom/lib/"))

    def test_wrong_architecture_and_non_elf_are_rejected(self):
        arm = bytearray(HEADER)
        struct.pack_into("<H", arm, 18, 183)
        for header in [b"not ELF", arm]:
            with self.subTest(header=header), self.assertRaisesRegex(ValueError, "x86_64 ELF"):
                PACKAGER.validate_metadata(header, METADATA)

    @unittest.skipUnless(Path("/usr/bin/gcc").exists() and shutil.which("readelf"), "needs native gcc and readelf")
    def test_real_package_contents_checksum_and_repeatability(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "controller-fixture"
            subprocess.run(["/usr/bin/gcc", "-x", "c", "-o", str(binary), "-"],
                           input="int main(void) { return 0; }\n", text=True, check=True,
                           env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"})
            for directory in [root / "first", root / "second"]:
                PACKAGER.package(binary, "0.1.0", directory, 1234567890)
            name = "kanata-controller-0.1.0-x86_64-unknown-linux-gnu.tar.gz"
            archive = root / "first" / name
            self.assertEqual(archive.read_bytes(), (root / "second" / name).read_bytes())
            expected = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual((root / "first/SHA256SUMS").read_text(), f"{expected}  {name}\n")
            with tarfile.open(archive) as bundle:
                self.assertEqual(bundle.getnames(), ["kanata-controller", "README.md"])
                self.assertEqual(bundle.getmember("kanata-controller").mode, 0o755)
                self.assertEqual(bundle.extractfile("kanata-controller").read(), binary.read_bytes())
            with self.assertRaisesRegex(ValueError, "overwrite"):
                PACKAGER.package(binary, "0.1.0", root / "first", 1234567890)
            with self.assertRaisesRegex(ValueError, "package version"):
                PACKAGER.package(binary, "../invalid", root / "invalid", 1234567890)
            link = root / "link"
            link.symlink_to(binary)
            with self.assertRaisesRegex(ValueError, "symlink"):
                PACKAGER.package(link, "0.1.0", root / "link-output", 1234567890)


if __name__ == "__main__":
    unittest.main()
