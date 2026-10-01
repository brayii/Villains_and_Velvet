#!/usr/bin/env python3
"""Validate a packaged Windows release ZIP before publishing it."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile


def validate_archive(path: Path) -> dict:
    if not path.is_file():
        raise ValueError(f"Release archive is missing: {path}")
    digest = hashlib.sha256(path.read_bytes()).hexdigest().upper()
    try:
        with zipfile.ZipFile(path) as archive:
            corrupt_member = archive.testzip()
            if corrupt_member:
                raise ValueError(f"Release archive has a corrupt member: {corrupt_member}")
            files = [entry for entry in archive.infolist() if not entry.is_dir()]
            if not files:
                raise ValueError("Release archive contains no files")
            names = [entry.filename.replace("\\", "/") for entry in files]
            executables = [name for name in names if name.lower().endswith(".exe")]
            game_data = [name for name in names
                         if name.lower() == "data.win" or name.lower().endswith(".win")]
            if not executables:
                raise ValueError("Release archive contains no Windows executable")
            if not game_data:
                raise ValueError("Release archive contains no GameMaker data file")
            if any(entry.file_size <= 0 for entry in files):
                raise ValueError("Release archive contains an empty file")
    except zipfile.BadZipFile as exc:
        raise ValueError(f"Release archive is not a readable ZIP: {exc}") from exc
    return {
        "path": str(path.resolve()),
        "bytes": path.stat().st_size,
        "sha256": digest,
        "file_count": len(files),
        "executables": executables,
        "game_data": game_data,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(validate_archive(args.archive), indent=2))
    except ValueError as exc:
        print(f"Release archive verification failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
