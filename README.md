# Villains & Velvet

Villains & Velvet is a single-player card game prototype built with GameMaker. Build a three-card team from a growing roster of Heroes, manage incoming Minions, and defeat the Enemy Leader before the Enemy Deck runs out.

## Project Status

This project is an in-development prototype. Gameplay rules and content may change.

## Requirements

- GameMaker (the project metadata was last saved with IDE version `2026.0.0.16`)
- A GameMaker target available for the platform on which you want to run or export the game

## Open and Run

1. Clone or download this repository.
2. Open `cards.yyp` in GameMaker.
3. Select an available target and run the project from the GameMaker IDE.

`CardGamePrototype.exe` is a prebuilt Windows prototype. The GameMaker project is the source of truth for development.

## Documentation

- [Core Game Rules](CORE_GAME_RULES.md) — the basic gameplay rules shared by current and future content.
- [Architecture](ARCHITECTURE.md) — code organization and guidance about where changes belong.

## Repository Layout

- `objects/` — GameMaker objects and their events.
- `scripts/` — gameplay, state, UI, data, turn, and asset modules.
- `rooms/` — GameMaker room definitions.
- `card_art/` — source artwork used while preparing and reviewing cards.
- `datafiles/card_art/` — game-ready artwork included in exported builds.
- `tools/` — development utilities.

When changing playable artwork, update both `card_art/` and `datafiles/card_art/` so the source and exported copies remain synchronized.

## License

No license has been specified. Unless and until a license is added, the code and artwork remain under their respective owners' default copyright.
