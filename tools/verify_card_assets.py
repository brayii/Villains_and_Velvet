from pathlib import Path
import binascii
import re
import struct
import sys
import zlib


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
    data = file.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("not a valid PNG")
    offset = 8
    width = height = 0
    idat = bytearray()
    saw_ihdr = saw_iend = False
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk_type = data[offset + 4:offset + 8]
        chunk_end = offset + 12 + length
        if chunk_end > len(data):
            raise ValueError("truncated PNG chunk")
        payload = data[offset + 8:offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length:chunk_end])[0]
        if binascii.crc32(chunk_type + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError("invalid PNG checksum")
        if chunk_type == b"IHDR":
            if saw_ihdr or length != 13 or offset != 8:
                raise ValueError("invalid PNG header")
            width, height = struct.unpack(">II", payload[:8])
            saw_ihdr = True
        elif chunk_type == b"IDAT":
            idat.extend(payload)
        elif chunk_type == b"IEND":
            if length != 0:
                raise ValueError("invalid PNG end chunk")
            saw_iend = True
            offset = chunk_end
            break
        offset = chunk_end
    if not saw_ihdr or not idat or not saw_iend or offset != len(data):
        raise ValueError("incomplete PNG")
    try:
        if not zlib.decompress(bytes(idat)):
            raise ValueError("empty PNG image data")
    except zlib.error as error:
        raise ValueError("invalid PNG image data") from error
    return width, height


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
