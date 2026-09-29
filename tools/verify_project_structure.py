"""Verify GameMaker resources, script ownership, and critical source invariants."""

from collections import Counter
from pathlib import Path
import re
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = PROJECT_ROOT / "VillainsAndVelvet.yyp"
RESOURCE_ORDER_FILE = PROJECT_ROOT / "VillainsAndVelvet.resource_order"


def script_functions() -> dict[str, list[str]]:
    owners: dict[str, list[str]] = {}
    pattern = re.compile(r"(?m)^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
    for source in sorted((PROJECT_ROOT / "scripts").glob("*/*.gml")):
        relative = source.relative_to(PROJECT_ROOT).as_posix()
        for name in pattern.findall(source.read_text(encoding="utf-8-sig")):
            owners.setdefault(name, []).append(relative)
    return owners


def main() -> int:
    errors: list[str] = []
    project_text = PROJECT_FILE.read_text(encoding="utf-8-sig")
    order_text = RESOURCE_ORDER_FILE.read_text(encoding="utf-8-sig")

    resource_paths = re.findall(
        r'"id":\{"name":"[^"]+","path":"([^"]+\.yy)"', project_text
    )
    for path in sorted(set(resource_paths)):
        if not (PROJECT_ROOT / path).is_file():
            errors.append(f"Missing declared resource: {path}")
    for path, count in sorted(Counter(resource_paths).items()):
        if count > 1:
            errors.append(f"Duplicate project resource: {path}")

    order_paths = set(re.findall(r'"path":"([^"]+\.yy)"', order_text))
    for path in sorted(order_paths - set(resource_paths)):
        errors.append(f"Stale resource-order entry: {path}")

    declared_groups = set(re.findall(r'"folderPath":"(folders/[^"]+\.yy)"', project_text))
    for metadata in sorted(PROJECT_ROOT.glob("scripts/*/*.yy")):
        text = metadata.read_text(encoding="utf-8-sig")
        parent = re.search(
            r'"parent"\s*:\s*\{.*?"path"\s*:\s*"([^"]+\.yy)"', text, re.S
        )
        relative = metadata.relative_to(PROJECT_ROOT).as_posix()
        if not parent:
            errors.append(f"Script has no declared parent: {relative}")
        elif parent.group(1) not in declared_groups:
            errors.append(f"Unknown script parent {parent.group(1)}: {relative}")

    owners = script_functions()
    for name, files in sorted(owners.items()):
        if len(files) > 1:
            errors.append(f"Duplicate global function {name}: {', '.join(files)}")

    script_folders = sorted((PROJECT_ROOT / "scripts").iterdir())
    for folder in script_folders:
        if not folder.is_dir():
            continue
        source = folder / f"{folder.name}.gml"
        metadata = folder / f"{folder.name}.yy"
        if source.is_file() != metadata.is_file():
            errors.append(f"Incomplete Script resource pair: scripts/{folder.name}")

    asset_source = (PROJECT_ROOT / "scripts/vv_assets/vv_assets.gml").read_text(
        encoding="utf-8-sig"
    )
    if "md5_string_utf8(_file)" not in asset_source:
        errors.append("Artwork cache key is not collision resistant")
    if "sprite_delete(sprite_id)" not in asset_source:
        errors.append("Dynamic artwork cleanup is missing")

    state_source = (PROJECT_ROOT / "scripts/vv_state/vv_state.gml").read_text(
        encoding="utf-8-sig"
    )
    if not re.search(r"array_length\(hand\) == CORE_HAND_SIZE", state_source):
        errors.append("Runtime state validation duplicates the Hand-size literal")
    if not re.search(r"array_length\(build\) == CORE_BUILD_SIZE", state_source):
        errors.append("Runtime state validation duplicates the Build-size literal")

    ai_data_source = (PROJECT_ROOT / "scripts/vv_ai_data/vv_ai_data.gml").read_text(
        encoding="utf-8-sig"
    )
    save_function = re.search(
        r"function vv_ai_data_save_if_dirty\(\) \{(.*?)\n\}", ai_data_source, re.S
    )
    if not save_function or not re.search(
        r"catch \(_error\).*?ai_data_dirty_frames = 0;", save_function.group(1), re.S
    ):
        errors.append("AI-data save failure does not reset its retry timer")

    if errors:
        print("Project structure verification failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "Project structure verification passed: "
        f"{len(resource_paths)} resources, {len(owners)} global functions, "
        f"{len(declared_groups)} resource groups."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
