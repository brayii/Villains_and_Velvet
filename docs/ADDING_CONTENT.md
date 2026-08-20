# Adding Content to Villains & Velvet

This guide describes the content workflow supported by the current GameMaker project. Follow the existing definitions in `scripts/vv_data/vv_data.gml`; do not use displayed names or prototype card codes to select gameplay behavior.

## Before You Start

- Keep core deck counts in the existing `CORE_*` constants.
- Give every new content item a stable lowercase ID. Display names may change; IDs should not.
- Put game-ready PNG files only in `datafiles/card_art/`.
- Reuse existing ability and effect IDs when the behavior already exists.
- Add a new rule branch only when the behavior is genuinely new.

Battle Settings reads Leaders, Scenarios, Minion Sets, and Heroes from their registries. Registered Leaders, Scenarios, and Minion Sets automatically become selectable. When more than three Heroes are registered, each of the three Hero slots can cycle through the available Heroes while preventing duplicate selections.

The project validates all registries during startup. Duplicate or non-lowercase IDs, missing required fields, malformed card templates, and incomplete Minion Sets produce a setup error and keep Start Game unavailable. Correct the reported content definition and restart the game.

## Card Constructors

Player cards use:

```gml
card_player(hero_id, display_name, kind, attack, health,
    abilities, effect_text, art_path, theme_color)
```

Minions use:

```gml
card_minion(stable_id, display_name, kind, attack, health,
    abilities, effect_text, escape_effects, art_path)
```

The Minion's stable ID identifies the character, such as `bunny` or `red_panda`. The surrounding Minion Set entry separately assigns that card to a structural slot such as `NA` or `SC`.

Leader Strikes and Twists use:

```gml
card_enemy(card_type, stable_id, display_name, effects, effect_text, art_path)
```

Normal cards use an empty `abilities` array. Ability entries include their stable behavior ID, player-facing presentation, and parameters, for example `ability_entry(ABILITY_RALLY, "Rally", "Your other Build cards gain +1 Attack.", {amount:1})`. Put multiple entries in the array in the order they should resolve and appear. Overpower, Relentless, and Rally use `amount`; Unity uses `amount_per_hero`. Abilities without adjustable values use `{}`. Effect entries include a stable effect ID and parameters, for example `[effect_entry(EFFECT_HEAL_LEADER, {amount:5})]`.

## Add or Replace a Hero

Hero definitions live in `make_hero_definitions()`. Each selected Hero must provide one Normal, one Ability, and one Special template. The deck builder clones seven Normal, five Ability, and three Special copies.

Use the current Goblin, Skeleton, or Orc definition as the working example. Give all three templates the same stable Hero ID so Unity and deck validation recognize them as one Hero. Add the Hero's artwork to `datafiles/card_art/heroes/` and pass the matching `card_art/heroes/...` runtime paths to the constructors.

`make_default_hero_selection()` selects the first three definitions. When more than three Heroes are registered, the setup arrows let the player replace each Hero slot while preventing duplicates.

## Add or Replace a Leader

Use `make_enemy_leader()` as the current complete Leader definition. A Leader needs:

- `id`, `name`, `starting_hp`, `max_hp`, and `attack`;
- an `art_file` runtime path;
- `abilities` and `special_moves` arrays, which may remain empty; and
- a `leader_strikes` array containing card definitions, default counts, and maximum counts.

`abilities` and `special_moves` are reserved extension points. The current game does not resolve generic Leader abilities or Special moves. Add their gameplay hook when the first real Leader mechanic needs one instead of placing an entry in these arrays and expecting it to run automatically.

Add each Leader constructor to `make_enemy_leader_registry()`. Every registered Leader automatically appears in setup. Its Leader Strike `default_copies` values supply the normal Leader Strike contribution to the eight Enemy Event cards.

## Add or Replace a Scenario

Use `make_scenario_the_assault()` as the complete Scenario example. A Scenario needs a stable ID, display name, setup rules, and Twist definitions. It does not define the Minion cast.

`setup_rules` is a reserved extension point. The current game stores and validates the array but does not execute generic setup rules. Implement the smallest required setup hook when a real Scenario introduces one.

Add each Scenario constructor to `make_scenario_registry()`. Every registered Scenario automatically appears in Battle Settings. Its Twist `default_copies` values supply the recommended Twist contribution to the eight Enemy Event cards.

## Add or Replace a Minion Set

Use `make_minion_set_velvet_menagerie()` as the complete Minion Set example. Each Minion slot is stored as:

```gml
{slot: "NA", card: minion_card_definition}
```

Every Minion Set must define each of the eight slots exactly once and must use a different stable Minion ID for every card. Core code—not the Minion Set—owns the permanent distribution: NA ×7, NB ×3, NC ×2, AA ×5, AB ×3, SA ×2, SB ×2, and SC ×1. The deck builder and state validator reject missing, duplicated, or unknown slots and duplicated or missing Minion IDs.

Add each complete Minion Set constructor to `make_minion_set_registry()`. It then appears independently in Battle Settings and may be combined with any Scenario.

Selecting a Leader or Scenario restores the normal counts from both choices. If those defaults do not total eight, Start Game remains unavailable until the player opens **Battle Settings** and adjusts the Enemy Events to a legal total.

## Add a Minion

Add the Minion's `card_minion()` definition to a Minion Set's `minion_slots`. Choose its Entry ability from the existing `ABILITY_*` IDs and its Escape behavior from the existing `EFFECT_*` IDs.

The current reusable Minion abilities are Disrupt, Crush, Protector, Shatter, and Devastate. The current reusable Escape effects heal the Leader or destroy a Hand card. Names such as Otter or Raccoon and codes such as AA or SB are content only; the resolver reads the stable ability and effect IDs.

Escape effects run in their listed order. `EFFECT_HEAL_LEADER` uses `{amount:N}`. `EFFECT_DESTROY_HAND_CARD` uses `{count:N}` and requests up to that many separate Hand-card choices; if the Hand empties first, the sequence continues to the next effect.

To replace a Minion, change the card assigned to its structural slot. Do not add or adjust Minion copy counts in content data.

## Add a Leader Strike or Twist

Leader Strikes belong to a Leader's `leader_strikes` array. Twists belong to a Scenario's `twists` array. Each selectable definition contains:

```gml
{
    card: card_enemy(...),
    default_copies: number,
    max_copies: number
}
```

Direct Assault demonstrates `EFFECT_LEADER_BASIC_ATTACK`. Reinforcements demonstrates `EFFECT_AREA_2_ATTACK`. Reuse those effect IDs for different names or artwork with identical behavior.

Current Leader Strike and Twist effects resolve synchronously. If a new Enemy Event requires a player choice, give Enemy Event resolution a resumable effect index like Minion Entry and Escape sequencing; do not add one-off continuation state to the turn controller.

The selected Leader Strike and Twist counts must total exactly eight. The setup screen automatically generates paged rows for every available definition and safely handles a Leader or Scenario with no events in one category.

## Reuse or Add an Ability

To reuse a behavior, place its stable ID in the card's `abilities` array. Do not compare the card's name, displayed ability name, or slot code in gameplay code.

To implement a new behavior:

1. add a stable `ABILITY_*` or `EFFECT_*` macro in `vv_data.gml` and add it to the appropriate supported-ID list in content validation;
2. add the entry to the card definition;
3. implement Player abilities in `vv_player.gml` or Enemy abilities/effects in `vv_enemy.gml`;
4. use entry parameters for values that vary by card;
5. add prompts through the existing `prompt_mode` and `resume_after_prompts()` flow; and
6. test the new behavior with differently named content to prove it does not depend on display text.

## Add Artwork

1. Save the game-ready PNG under `datafiles/card_art/heroes/`, `enemies/`, or `backgrounds/`.
2. Use a descriptive stable lowercase filename.
3. Add the file under **Included Files** in GameMaker.
4. Reference it from content with a runtime path beginning `card_art/`; do not include `datafiles/` in the runtime path.
5. Run `python tools/verify_card_assets.py`.

The optional `tools/extract_card_assets.py` utility crops the current source sheets from the workspace's `../card_assets/` folder directly into `datafiles/card_art/`. It does not create a second project copy.

## Add or Replace Audio

Audio is stored as normal GameMaker Sound Assets under `sounds/`. Short effects use `snd_*` resources and are preloaded. Music uses `mus_*` resources and streams. Import or replace audio through GameMaker so sample format, duration, channel format, and compression metadata stay synchronized with the source file. Gameplay should reference the Sound Asset directly; do not add Included File audio or parse WAV data in GML.

The guided training profile in `vv_tutorial.gml` deliberately uses fixed known content. New selectable Heroes, Minion Sets, Leaders, or Scenarios do not automatically replace its lesson cards. Change that profile only when intentionally redesigning and retesting the training sequence.

## Test the Content

Before committing:

1. verify artwork if any image or path changed;
2. compile the project in GameMaker;
3. confirm the setup selection is valid and creates a 45-card Player Deck and 33-card Enemy Deck;
4. start a match and exercise every new Entry, Escape, attack, target-priority, or event effect;
5. test empty-target and insufficient-Attack cases where relevant;
6. confirm prompts explain what is happening and highlight only legal targets; and
7. confirm the game restarts cleanly from the setup screen.
