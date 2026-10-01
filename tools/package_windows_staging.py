#!/usr/bin/env python3
"""Create a Windows release ZIP from GameMaker's completed staging payload.

GameMaker LTS 2026 can finish staging a Windows build and then fail while
writing its own ZIP. This tool packages the completed payload without copying
compiler cache directories into the release.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import zipfile

from verify_release_archive import validate_archive


REQUIRED_FILES = ("VillainsAndVelvet.exe", "data.win")


def package_staging(staging: Path, output: Path) -> dict:
    staging = staging.resolve()
    output = output.resolve()
    if not staging.is_dir():
        raise ValueError(f"Staging directory is missing: {staging}")

    missing = [name for name in REQUIRED_FILES if not (staging / name).is_file()]
    if missing:
        raise ValueError(f"Staging payload is incomplete; missing: {', '.join(missing)}")

    files = sorted(
        path for path in staging.rglob("*")
        if path.is_file()
        and not any(part.startswith(".") or part.endswith("-cache")
                    for part in path.relative_to(staging).parts)
        and path.resolve() != output
    )
    if not files:
        raise ValueError("Staging payload contains no release files")

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.unlink(missing_ok=True)
    try:
        with zipfile.ZipFile(
            temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
        ) as archive:
            for path in files:
                archive.write(path, path.relative_to(staging).as_posix())
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)

    return validate_archive(output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        result = package_staging(args.staging, args.output)
    except ValueError as exc:
        print(f"Windows staging package failed: {exc}", file=sys.stderr)
        return 1
    for key, value in result.items():
        print(f"{key}: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
