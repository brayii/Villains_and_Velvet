# Villains & Velvet

Villains & Velvet is a single-player card game built with GameMaker. The complete design is recorded in the [core rules](../Core%20Game%20Rules%20%E2%80%93%20v1.0.md).

## How to Play

- Tap **Start Turn** to draw cards and begin the enemy sequence.
- Minions advance, escape, and enter play automatically.
- When several cards are highlighted, choose one to resolve the effect.
- During Build, select a Hand card and then a Build slot to place or swap it.
- Tap **Ready to Attack** when your Build is complete.
- During Attack, tap a Minion or the Enemy Leader.
- Tap **End Attack** when you are finished. The game discards the remaining Hand and ends the turn automatically.

## Turn Order

1. Draw Cards
2. Advance and Escape
3. Enemy Draw
4. Build
5. Player Attack
6. Discard
7. End Turn

## Important Rules

- Guard and Fortress must be attacked before other Build cards.
- If several priority cards are in play, the player chooses which one is attacked.
- A failed attack against a Minion does not spend the player's remaining Attack.
- If SB escapes while the Hand is empty, its Escape has no effect.
- Unused Attack is lost when the turn ends.

## Artwork Folders

- `card_art/` contains the source artwork used while preparing and reviewing cards.
- `datafiles/card_art/` contains the game-ready copies included in GameMaker builds.
- Add or replace playable artwork in both locations so the source files and exported game stay synchronized.
