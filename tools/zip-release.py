#!/usr/bin/env python3
"""ZIP a directory with its top-level name, UTF-8 names and Unix file modes."""

import argparse
import os
import stat
import time
import zipfile
from pathlib import Path


def archive(source: Path, destination: Path) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if not source.is_dir():
        raise ValueError(f"Not a directory: {source}")
    if destination == source or source in destination.parents:
        raise ValueError("Archive must be outside the source directory")
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Python writes ZIP's UTF-8 flag for non-ASCII entry names. ZipFile.write
    # preserves executable bits; symlinks must be stored rather than followed.
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=9,
                         strict_timestamps=False) as output:
        paths = [source, *sorted(source.rglob("*"))]
        for path in paths:
            if path.name == ".DS_Store" or path.name.startswith("._"):
                continue
            name = path.relative_to(source.parent).as_posix()
            metadata = path.lstat()
            if stat.S_ISLNK(metadata.st_mode):
                date = time.localtime(max(metadata.st_mtime, 315532800))[:6]
                entry = zipfile.ZipInfo(name, date)
                entry.create_system = 3
                entry.external_attr = metadata.st_mode << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                output.writestr(entry, os.readlink(path).encode("utf-8"))
            else:
                output.write(path, name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    archive(arguments.source, arguments.destination)
