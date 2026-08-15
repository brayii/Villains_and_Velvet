from pathlib import Path
from shutil import copy2

from PIL import Image, ImageDraw


PROJECT_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = PROJECT_ROOT.parent
SOURCE = WORKSPACE_ROOT / "card_assets"
OUTPUT = PROJECT_ROOT / "datafiles" / "card_art"


HERO_CROPS = {
    "hero_a_normal_goblin.png": (8, 100, 342, 425),
    "hero_a_ability_goblin.png": (350, 100, 682, 425),
    "hero_a_special_goblin.png": (689, 100, 1073, 425),
    "hero_b_normal_skeleton.png": (8, 428, 342, 732),
    "hero_b_ability_skeleton.png": (350, 428, 682, 732),
    "hero_b_special_skeleton.png": (689, 428, 1073, 732),
    "hero_c_normal_orc.png": (8, 734, 342, 1021),
    "hero_c_ability_orc.png": (350, 734, 682, 1021),
    "hero_c_special_orc.png": (689, 734, 1073, 1021),
}

ENEMY_CROPS = {
    "minion_na_bunny.png": (30, 102, 284, 489),
    "minion_nb_corgi.png": (298, 102, 547, 489),
    "minion_nc_red_panda.png": (559, 102, 810, 489),
    "minion_aa_otter.png": (820, 102, 1076, 489),
    "minion_ab_highland_cow.png": (1090, 102, 1340, 489),
    "minion_sa_capybara.png": (30, 496, 284, 870),
    "minion_sb_raccoon.png": (297, 496, 547, 870),
    "minion_sc_harp_seal.png": (559, 496, 810, 870),
    "leader_velvet_queen.png": (30, 876, 810, 1024),
    "twist_reinforcements.png": (821, 773, 1121, 1018),
    "leader_strike_direct_assault.png": (1130, 773, 1442, 1018),
}


def extract(source_file: Path, destination: Path, crops: dict[str, tuple[int, int, int, int]]) -> list[Path]:
    image = Image.open(source_file).convert("RGBA")
    destination.mkdir(parents=True, exist_ok=True)
    created = []
    for filename, box in crops.items():
        output_file = destination / filename
        image.crop(box).save(output_file, optimize=True)
        created.append(output_file)
    return created


def make_preview(files: list[Path], output_file: Path) -> None:
    thumb_size = (180, 230)
    columns = 7
    rows = (len(files) + columns - 1) // columns
    preview = Image.new("RGB", (columns * 200, rows * 270), (20, 24, 34))
    draw = ImageDraw.Draw(preview)
    for index, file in enumerate(files):
        image = Image.open(file).convert("RGBA")
        image.thumbnail(thumb_size, Image.Resampling.LANCZOS)
        x = (index % columns) * 200 + (200 - image.width) // 2
        y = (index // columns) * 270 + 5
        preview.paste(image, (x, y), image)
        draw.text((index % columns * 200 + 8, index // columns * 270 + 240), file.stem, fill=(240, 240, 240))
    output_file.parent.mkdir(parents=True, exist_ok=True)
    preview.save(output_file, optimize=True)


def main() -> None:
    created = []
    created += extract(SOURCE / "heros" / "hero_set_1.png", OUTPUT / "heroes", HERO_CROPS)
    created += extract(SOURCE / "enemies" / "enemy_set_1.png", OUTPUT / "enemies", ENEMY_CROPS)

    background_dir = OUTPUT / "backgrounds"
    background_dir.mkdir(parents=True, exist_ok=True)
    background_file = background_dir / "battlefield.png"
    copy2(SOURCE / "backgrounds" / "background_1.png", background_file)
    created.append(background_file)

    make_preview(created[:-1], PROJECT_ROOT / ".build_temp" / "card_asset_preview.png")
    print(f"Created {len(created)} project assets in {OUTPUT}")


if __name__ == "__main__":
    main()
