# Villains & Velvet Architecture

`obj_controller` remains the main controller. Its events only initialize, update, draw, and clean up the game; the rules live in focused Script Assets.

## Where Changes Belong

- `scripts/vv_data/vv_data.gml`: permanent core deck-count constants, Leader data, card definitions, names, stats, stable ability IDs, artwork paths, and deck construction.
- `scripts/vv_state/vv_state.gml`: game reset, deck-composition and runtime-state validation, card-space counts, and event-log storage.
- `scripts/vv_enemy/vv_enemy.gml`: Enemy targeting, Minion entry and escape effects, Enemy attacks, Leader Strike, Twist, Overflow, and Enemy prompts.
- `scripts/vv_player/vv_player.gml`: Player drawing and recycling, Build placement and swapping, attack totals, Hero abilities, and Player attacks.
- `scripts/vv_turn/vv_turn.gml`: the seven turn steps, automatic timing, prompt continuation, and action-button commands.
- `scripts/vv_ui/vv_ui.gml`: board layout, colors, drawing, highlighting, hit testing, and translating taps into gameplay commands.
- `scripts/vv_assets/vv_assets.gml`: loading, caching, and releasing dynamically loaded artwork.

## Adding or Changing Content

- Change Hero, Minion, or Leader values in `vv_data.gml`.
- Add the stable ID and displayed card data in `vv_data.gml` when adding an ability.
- Implement Player ability behavior in `vv_player.gml`.
- Implement Minion or Enemy-event behavior in `vv_enemy.gml`.
- Change turn sequencing only in `vv_turn.gml`.
- Keep UI code limited to presentation and input routing; gameplay legality belongs in the relevant gameplay module.

Runtime artwork is loaded with `sprite_add()` and owned by the cache in `vv_assets.gml`. The `obj_controller` Clean Up event calls `vv_assets_cleanup()` so each cached dynamic sprite is released once.

## Fixed Deck Structure

The authoritative `CORE_*` constants are defined once at the top of `vv_data.gml`. They describe three Heroes with a 7/5/3 card distribution, the fixed eight Minion-slot copy counts, 25 total Minions, eight Enemy Events, a 45-card Player Deck, and a 33-card Enemy Deck.

`vv_state.gml` validates both totals and composition. Player validation discovers the three Hero IDs from the cards instead of assuming A/B/C. Enemy validation checks every structural Minion slot and requires Leader Strikes plus Twists to occupy exactly eight event slots.

Hero identity is a stable content ID. Player rules such as Unity compare IDs dynamically and count unique other Heroes; gameplay code does not maintain a fixed list of Hero IDs.

## Leader Definitions

Leader definitions live in `vv_data.gml`. Each Leader has a stable ID, display name, separate starting and maximum Health, basic Attack, artwork, ability and Special-move arrays, and its available Leader Strike definitions. `reset_game()` initializes the Leader from `starting_hp`; healing and state validation use `max_hp`.

The Velvet Queen currently owns Direct Assault with a default selection of three copies.

## Scenario Definitions

Scenario definitions live in `vv_data.gml`. A Scenario has a stable ID, display name, setup-rule array, definitions for the fixed NA/NB/NC/AA/AB/SA/SB/SC Minion slots, and its available Twist definitions.

`make_scenario_the_assault()` owns the current eight Minion definitions and Reinforcements. The deck builder accepts the selected Leader and Scenario, applies the permanent core copy counts, and clones every physical card. The controller currently selects The Velvet Queen and The Assault before reset; a later setup phase will make those selections configurable.

## Enemy Event Resolution

Leader Strike and Twist definitions contain stable card IDs, stable effect IDs, display text, and artwork paths. Enemy Draw identifies only whether a card is a Leader Strike or Twist, then delegates to `resolve_leader_strike()` or `resolve_twist()` in `vv_enemy.gml`.

Direct Assault uses the reusable `leader_basic_attack` effect. Reinforcements uses the reusable `area_2_attack` effect. Adding another card that uses either existing effect requires only a content definition; a genuinely new effect requires one localized resolver case.

## Enemy Event Selection

Available Leader Strike definitions belong to the selected Leader, and available Twist definitions belong to the selected Scenario. Each definition supplies a default count and a maximum permitted count. The current selected IDs and copy counts live separately in `enemy_event_selection`.

`validate_enemy_event_selection()` in `vv_state.gml` rejects unavailable or duplicated IDs, invalid counts, copy-limit violations, and totals other than eight. It returns the current total and a clear add/remove/ready message. The Enemy Deck builder uses only the validated selection and never silently inserts, removes, or substitutes an Enemy Event.

The selected Hero IDs are also separate from the available Hero definitions. `validate_hero_selection()` requires exactly three different IDs that exist in the available content. `refresh_setup_validation()` combines the Hero and Enemy Event checks, and `command_start_game_from_setup()` is the only setup command that starts a match.

The setup screen is drawn and routed by `vv_ui.gml`; it does not decide legality. Touch controls send selection commands to `vv_state.gml`, which updates and validates the setup. The Start Game button reflects `setup_validation.valid` and cannot start an invalid match.
