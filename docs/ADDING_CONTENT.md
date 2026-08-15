# Adding Content to Villains & Velvet

This guide describes the content workflow supported by the current GameMaker project. Follow the existing definitions in `scripts/vv_data/vv_data.gml`; do not use displayed names or prototype card codes to select gameplay behavior.

## Before You Start

- Keep core deck counts in the existing `CORE_*` constants.
- Give every new content item a stable lowercase ID. Display names may change; IDs should not.
- Put game-ready PNG files only in `datafiles/card_art/`.
- Reuse existing ability and effect IDs when the behavior already exists.
- Add a new rule branch only when the behavior is genuinely new.

The current setup screen has one active Leader and Scenario and displays the first three Heroes. A fourth definition does not automatically add a selection control. To make multiple Leaders, Scenarios, or Hero rosters player-selectable, extend the setup state and UI as a separate feature.

## Card Constructors

Player cards use:

```gml
card_player(hero_id, display_name, kind, attack, health,
    abilities, ability_name, effect_text, art_path, theme_color)
```

Minions use:

```gml
card_minion(slot_code, display_name, kind, attack, health,
    abilities, ability_name, effect_text, escape_effects, art_path)
```

Leader Strikes and Twists use:

```gml
card_enemy(card_type, stable_id, display_name, effects, effect_text, art_path)
```

Normal cards use an empty `abilities` array. An Ability or Special card currently uses entries such as `[ability_entry(ABILITY_GUARD)]`. Effect entries include a stable effect ID and parameters, for example `[effect_entry(EFFECT_HEAL_LEADER, {amount:5})]`.

## Add or Replace a Hero

Hero definitions live in `make_hero_definitions()`. Each selected Hero must provide one Normal, one Ability, and one Special template. The deck builder clones seven Normal, five Ability, and three Special copies.

Use the current Goblin, Skeleton, or Orc definition as the working example. Give all three templates the same stable Hero ID so Unity and deck validation recognize them as one Hero. Add the Hero's artwork to `datafiles/card_art/heroes/` and pass the matching `card_art/heroes/...` runtime paths to the constructors.

`make_default_hero_selection()` selects the first three definitions. Reordering or replacing those definitions changes the current roster. Adding a fourth definition stores valid content but does not make it selectable until the setup screen gains Hero-selection controls.

## Add or Replace a Leader

Use `make_enemy_leader()` as the current complete Leader definition. A Leader needs:

- `id`, `name`, `starting_hp`, `max_hp`, and `attack`;
- an `art_file` runtime path;
- `abilities` and `special_moves` arrays, which may remain empty; and
- a `leader_strikes` array containing card definitions, default counts, and maximum counts.

The controller currently calls `make_enemy_leader()` directly. To activate a different Leader today, return the replacement from that function or create another factory and change the controller's Create event. A menu for choosing among multiple Leaders requires a later setup-UI feature.

## Add or Replace a Scenario

Use `make_scenario_the_assault()` as the complete Scenario example. A Scenario needs a stable ID, display name, setup rules, `minion_slots`, and Twist definitions.

Each Minion slot is stored as:

```gml
{card: minion_card_definition, copies: copy_count}
```

The copy counts across the Scenario must fill the fixed 25 Minion positions. The deck builder and state validator iterate this array; Minion codes remain content identifiers and do not control abilities.

The controller currently calls `make_scenario_the_assault()` directly. Activating another Scenario or exposing multiple Scenario choices follows the same limitation described for Leaders.

## Add a Minion

Add the Minion's `card_minion()` definition to the Scenario's `minion_slots`. Choose its Entry ability from the existing `ABILITY_*` IDs and its Escape behavior from the existing `EFFECT_*` IDs.

The current reusable Minion abilities are Disrupt, Crush, Protector, Shatter, and Devastate. The current reusable Escape effects heal the Leader or destroy a Hand card. Names such as Otter or Raccoon and codes such as AA or SB are content only; the resolver reads the stable ability and effect IDs.

If the Scenario still uses the fixed 25-card Minion structure, adjust another slot's copy count when adding a new one so the total remains 25.

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

The selected Leader Strike and Twist counts must total exactly eight. The current setup layout exposes the first Leader Strike and first Twist definition; displaying more event choices requires a setup-UI extension.

## Reuse or Add an Ability

To reuse a behavior, place its stable ID in the card's `abilities` array. Do not compare the card's name, displayed ability name, or slot code in gameplay code.

To implement a new behavior:

1. add a stable `ABILITY_*` or `EFFECT_*` macro in `vv_data.gml`;
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

## Test the Content

Before committing:

1. verify artwork if any image or path changed;
2. compile the project in GameMaker;
3. confirm the setup selection is valid and creates a 45-card Player Deck and 33-card Enemy Deck;
4. start a match and exercise every new Entry, Escape, attack, target-priority, or event effect;
5. test empty-target and insufficient-Attack cases where relevant;
6. confirm prompts explain what is happening and highlight only legal targets; and
7. confirm the game restarts cleanly from the setup screen.
