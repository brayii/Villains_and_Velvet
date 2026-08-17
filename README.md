# Villains & Velvet

Villains & Velvet is a single-player card game prototype built with GameMaker. Build a three-card Hero team, manage incoming Minions, and defeat the Enemy Leader before the Enemy Deck runs out.

## Project Status

This project is an in-development prototype. Gameplay rules and content may change.

## Requirements

- GameMaker (the project metadata was last saved with IDE version `2026.0.0.16`)
- A GameMaker target available for the platform on which you want to run or export the game
- Optional: Python 3 for the artwork verification tool, plus Pillow for the source-sheet extraction tool

## Open and Run

1. Clone or download this repository.
2. Open `VillainsAndVelvet.yyp` in GameMaker.
3. Select an available target and run the project from the GameMaker IDE.

The game opens on a battle setup screen. The current build displays The Velvet Queen, The Assault, and the three current Heroes. Use the plus and minus controls to adjust Leader Strike and Twist counts. Exactly eight Enemy Events are required before **Start Game** is enabled.

Installable Windows and Android builds are published on the repository's GitHub Releases page. Packaged builds are not stored with the source project; the GameMaker project is the source of truth for development.

## Documentation

- [Core Game Rules](CORE_GAME_RULES.md) — the basic gameplay rules shared by current and future content.
- [Architecture](ARCHITECTURE.md) — code organization and guidance about where changes belong.
- [Adding Content](docs/ADDING_CONTENT.md) — the tested workflow for extending cards, Leaders, Scenarios, effects, and artwork.

## Basic Controls

- Tap the large action button when it is offered. Automatic resolutions pause briefly between steps so the current step and its result remain visible.
- Tap a card to perform its current action. Press and hold any visible card or the Enemy Leader to enlarge it for reading, then tap anywhere to close the enlarged view.
- During Build, tap a Hand card and then a Build space, or drag between legal Hand and Build spaces. Occupied destinations swap cards.
- During Player Attack, tap a Minion the available Attack can defeat or tap the Enemy Leader. Failed Minion attacks do not spend Attack.
- During an Enemy effect, tap one of the highlighted legal cards. Cards that cannot be defeated or targeted are not highlighted.
- The turn-step list in the upper-right corner always shows the full seven-step sequence and highlights the current step.
- Use the small gear on the battlefield to pause, resume, return to Game Options, or exit the game. Leaving an active match requires confirmation.
- The checked **AUTO** box beside the gear lets the Enemy choose legal attack targets. Clear it at any time to choose Enemy targets manually; Auto is enabled by default on a clean install.
- After a victory or defeat, choose **Play Again**, **Game Options**, or **Exit Game**.

## Repository Layout

- `objects/` — GameMaker objects and their events.
- `scripts/` — gameplay, state, UI, data, turn, and asset modules.
- `rooms/` — GameMaker room definitions.
- `datafiles/card_art/` — the authoritative game-ready artwork included in exported builds.
- `tools/` — development utilities.

## Artwork Workflow

Keep each playable image only in `datafiles/card_art/`. GameMaker's Included Files list packages artwork directly from this location, and card definitions use the matching runtime path beginning with `card_art/`.

To replace one image, overwrite its file in `datafiles/card_art/` without changing the filename. To add an image, place it there, add it to GameMaker's Included Files, and reference its `card_art/...` path in the card definition.

The optional `tools/extract_card_assets.py` utility crops the current workspace source sheets from `../card_assets/` directly into the authoritative folder. It no longer creates or synchronizes a second project copy.

Run `python tools/verify_card_assets.py` after artwork changes. It verifies that every PNG is readable, every file has a GameMaker Included Files entry, and every artwork path used by the game exists.

## License

No license has been specified. Unless and until a license is added, the code and artwork remain under their respective owners' default copyright.
