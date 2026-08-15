from pathlib import Path
import re
import struct
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ART_ROOT = PROJECT_ROOT / "datafiles" / "card_art"
PROJECT_FILE = PROJECT_ROOT / "VillainsAndVelvet.yyp"
DATA_FILE = PROJECT_ROOT / "scripts" / "vv_data" / "vv_data.gml"


def relative_art_files() -> set[str]:
    return {
        file.relative_to(PROJECT_ROOT / "datafiles").as_posix()
        for file in ART_ROOT.rglob("*.png")
    }


def included_art_files() -> set[str]:
    text = PROJECT_FILE.read_text(encoding="utf-8")
    entries = re.findall(
        r'"filePath":"(datafiles/card_art/[^"]+)"[^\n]+"name":"([^"]+\.png)"',
        text,
    )
    return {f"{folder.removeprefix('datafiles/')}/{name}" for folder, name in entries}


def referenced_art_files() -> set[str]:
    text = DATA_FILE.read_text(encoding="utf-8")
    return set(re.findall(r'"(card_art/[^"]+\.png)"', text))


def png_dimensions(file: Path) -> tuple[int, int]:
    with file.open("rb") as image:
        header = image.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("not a valid PNG")
    return struct.unpack(">II", header[16:24])


def main() -> int:
    files = relative_art_files()
    included = included_art_files()
    referenced = referenced_art_files()
    errors: list[str] = []

    for label, missing in (
        ("GameMaker included-file entry", files - included),
        ("file on disk for GameMaker entry", included - files),
        ("file on disk for code reference", referenced - files),
    ):
        for path in sorted(missing):
            errors.append(f"Missing {label}: {path}")

    for path in sorted(files):
        try:
            width, height = png_dimensions(PROJECT_ROOT / "datafiles" / path)
            if width < 1 or height < 1:
                errors.append(f"Invalid image dimensions: {path}")
        except (OSError, ValueError) as error:
            errors.append(f"Unreadable artwork {path}: {error}")

    if errors:
        print("Artwork verification failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        f"Artwork verification passed: {len(files)} PNG files, "
        f"{len(included)} GameMaker entries, {len(referenced)} code references."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
