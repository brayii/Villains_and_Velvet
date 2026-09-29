"""Verify repository-controlled settings required before a release candidate."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ANDROID_OPTIONS = PROJECT_ROOT / "options/android/options_android.yy"
WINDOWS_OPTIONS = PROJECT_ROOT / "options/windows/options_windows.yy"
PROJECT_FILE = PROJECT_ROOT / "VillainsAndVelvet.yyp"
GITIGNORE = PROJECT_ROOT / ".gitignore"


def load_gamemaker_json(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def verify_release_config(root: Path = PROJECT_ROOT) -> list[str]:
    errors: list[str] = []
    android = load_gamemaker_json(root / "options/android/options_android.yy")
    windows = load_gamemaker_json(root / "options/windows/options_windows.yy")
    project = load_gamemaker_json(root / "VillainsAndVelvet.yyp")
    ignore_text = (root / ".gitignore").read_text(encoding="utf-8-sig")

    package_parts = [
        android.get("option_android_package_domain", ""),
        android.get("option_android_package_company", ""),
        android.get("option_android_package_product", ""),
    ]
    placeholders = {"", "com", "company", "game", "example", "yourstudio"}
    if any(str(part).lower() in placeholders for part in package_parts):
        errors.append("Android package identifier still contains placeholder values")

    expected_android = {
        "option_android_compile_sdk": "36",
        "option_android_target_sdk": "36",
        "option_android_gradle_version": "8.13",
        "option_android_gradle_plugin_version": "8.13.0",
        "option_android_arch_arm64": True,
        "option_android_tv_isgame": False,
        "option_android_tv_supports_leanback": False,
        "option_android_permission_bluetooth": False,
        "option_android_permission_internet": False,
    }
    for key, expected in expected_android.items():
        if android.get(key) != expected:
            errors.append(f"Android option {key} must be {expected!r}")

    if not str(windows.get("option_windows_company_info", "")).strip():
        errors.append("Windows company/publisher metadata is empty")
    if not str(windows.get("option_windows_copyright_info", "")).strip():
        errors.append("Windows copyright metadata is empty")

    for pattern in ("*.jks", "*.keystore", "keystore.properties", "local.properties"):
        if pattern not in ignore_text.splitlines():
            errors.append(f".gitignore does not protect {pattern}")

    resources = {
        entry["id"]["path"]
        for entry in project.get("resources", [])
        if isinstance(entry, dict) and isinstance(entry.get("id"), dict)
    }
    sound_metadata = sorted((root / "sounds").glob("*/*.yy"))
    for metadata in sound_metadata:
        relative = metadata.relative_to(root).as_posix()
        if relative not in resources:
            errors.append(f"Sound resource is not registered in the YYP: {relative}")
            continue
        definition = load_gamemaker_json(metadata)
        sound_file = metadata.parent / str(definition.get("soundFile", ""))
        if not sound_file.is_file():
            errors.append(f"Sound source file is missing: {sound_file.relative_to(root).as_posix()}")

    registered_sounds = sorted(path for path in resources if path.startswith("sounds/"))
    metadata_paths = {path.relative_to(root).as_posix() for path in sound_metadata}
    for path in registered_sounds:
        if path not in metadata_paths:
            errors.append(f"YYP references a missing Sound resource: {path}")

    included_files = project.get("IncludedFiles", [])
    for included in included_files:
        file_path = str(included.get("filePath", "")).replace("\\", "/").lower()
        name = str(included.get("name", "")).lower()
        if file_path.startswith("datafiles/audio") or name.endswith((".wav", ".ogg", ".mp3")):
            errors.append(f"Obsolete audio Included File remains: {file_path}/{name}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=PROJECT_ROOT)
    args = parser.parse_args()
    errors = verify_release_config(args.root.resolve())
    if errors:
        print("Release configuration verification failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Release configuration verification passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
