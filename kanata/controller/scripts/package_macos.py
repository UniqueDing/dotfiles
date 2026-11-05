#!/usr/bin/env python3
"""Package thin macOS controller binaries without non-system dylib dependencies."""
import argparse
from pathlib import Path
import re
import struct
import subprocess

from package_common import package_binary


TARGET = "aarch64-apple-darwin"
MAX_MACOS = (11, 0, 0)


def validate_metadata(header, dependencies, load_commands):
    if (len(header) < 16 or header[:4] != b"\xcf\xfa\xed\xfe"
            or struct.unpack_from("<I", header, 4)[0] != 0x0100000C
            or struct.unpack_from("<I", header, 12)[0] != 2):
        raise ValueError("expected a thin ARM64 Mach-O executable")
    if "/nix/store/" in dependencies + load_commands:
        raise ValueError("executable depends on a Nix-store runtime")
    if re.search(r"^\s*cmd LC_RPATH\s*$", load_commands, re.MULTILINE):
        raise ValueError("executable must not embed runtime library search paths")
    if not re.search(r"^\s*platform (?:1|macos)\s*$", load_commands, re.MULTILINE | re.IGNORECASE):
        raise ValueError("executable must target the macOS platform")
    libraries = [line.strip().split(" (", 1)[0] for line in dependencies.splitlines()[1:] if line.strip()]
    if not libraries or any(not path.startswith(("/usr/lib/", "/System/Library/")) for path in libraries):
        raise ValueError("executable must link only Apple system libraries and frameworks")
    versions = re.findall(r"^\s*minos ([0-9.]+)\s*$", load_commands, re.MULTILINE)
    minimums = [(tuple(map(int, value.split("."))) + (0, 0, 0))[:3] for value in versions]
    if len(minimums) != 1 or minimums[0] > MAX_MACOS:
        raise ValueError("executable must have a macOS deployment target no newer than 11.0")


def validate_binary(binary):
    env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C"}
    dependencies = subprocess.check_output(["/usr/bin/otool", "-L", str(binary)], text=True, env=env)
    commands = subprocess.check_output(["/usr/bin/otool", "-l", str(binary)], text=True, env=env)
    with binary.open("rb") as source:
        validate_metadata(source.read(16), dependencies, commands)


def package(binary, version, output, epoch):
    package_binary(binary, version, TARGET, output, epoch, validate_binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-date-epoch", required=True, type=int)
    args = parser.parse_args()
    try:
        package(args.binary, args.version, args.output, args.source_date_epoch)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"package-macos: {error}\n")


if __name__ == "__main__":
    main()
