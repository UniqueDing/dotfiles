#!/usr/bin/env python3
"""Package a GNU/Linux x86_64 controller only after checking its runtime ABI."""
import argparse
from pathlib import Path
import re
import struct
import subprocess

from package_common import package_binary


TARGET = "x86_64-unknown-linux-gnu"
MAX_GLIBC = (2, 35)


def validate_metadata(header, metadata):
    if len(header) < 20 or header[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", header, 18)[0] != 62:
        raise ValueError("expected a little-endian x86_64 ELF executable")
    if "/nix/store/" in metadata:
        raise ValueError("executable depends on a Nix-store runtime")
    if "[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]" not in metadata:
        raise ValueError("expected the standard GNU/Linux x86_64 dynamic loader")
    if re.search(r"\((?:RPATH|RUNPATH)\)", metadata):
        raise ValueError("executable must not embed a runtime library search path")
    versions = [tuple(map(int, value.split(".")))
                for value in re.findall(r"GLIBC_([0-9]+(?:\.[0-9]+)+)", metadata)]
    if not versions or max(versions) > MAX_GLIBC:
        raise ValueError("executable must require no newer than glibc 2.35")


def validate_binary(binary):
    metadata = subprocess.check_output(
        ["readelf", "--file-header", "--program-headers", "--dynamic", "--version-info", str(binary)],
        text=True, env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"},
    )
    with binary.open("rb") as source:
        validate_metadata(source.read(20), metadata)


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
        parser.exit(1, f"package-linux: {error}\n")


if __name__ == "__main__":
    main()
