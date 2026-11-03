"""Shared deterministic archives for pre-validated controller executables."""
import gzip
import hashlib
from pathlib import Path
import re
import tarfile


def package_binary(binary, version, target, output, epoch, validator):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("expected a stable three-component package version")
    if not re.fullmatch(r"[a-z0-9_]+(?:-[a-z0-9_]+)+", target):
        raise ValueError("invalid package target")
    if binary.is_symlink() or not binary.is_file() or not binary.stat().st_mode & 0o111:
        raise ValueError("binary must be a regular executable, not a symlink")
    if epoch < 0:
        raise ValueError("source-date-epoch must not be negative")
    validator(binary)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"kanata-controller-{version}-{target}.tar.gz"
    checksum = output / "SHA256SUMS"
    if archive.exists() or checksum.exists():
        raise ValueError("refusing to overwrite existing package or checksums")
    readme = Path(__file__).resolve().parents[1] / "README.md"
    with archive.open("xb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as bundle:
                for source, name, mode in [(binary, "kanata-controller", 0o755), (readme, "README.md", 0o644)]:
                    info = bundle.gettarinfo(str(source), arcname=name)
                    info.uid = info.gid = 0
                    info.uname = info.gname = ""
                    info.mtime = epoch
                    info.mode = mode
                    with source.open("rb") as stream:
                        bundle.addfile(info, stream)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum.write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    print(f"Wrote verified package {archive.name}")
