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

For constructor examples, registration limits, artwork steps, and verification, see [`docs/ADDING_CONTENT.md`](docs/ADDING_CONTENT.md).

Runtime artwork is loaded with `sprite_add()` and owned by the cache in `vv_assets.gml`. The `obj_controller` Clean Up event calls `vv_assets_cleanup()` so each cached dynamic sprite is released once.

`datafiles/card_art/` is the single authoritative location for game-ready artwork. GameMaker packages those files as Included Files, so runtime card paths begin with `card_art/`. The extraction utility writes directly to this folder, and `tools/verify_card_assets.py` checks the files, project entries, and code references without maintaining a duplicate artwork tree.

## Fixed Deck Structure

The authoritative `CORE_*` constants are defined once at the top of `vv_data.gml`. They describe three Heroes with a 7/5/3 card distribution, the fixed eight Minion-slot copy counts, 25 total Minions, eight Enemy Events, a 45-card Player Deck, and a 33-card Enemy Deck.

`vv_state.gml` validates both totals and composition. Player validation discovers the three Hero IDs from the cards instead of assuming A/B/C. Enemy validation checks every structural Minion slot and requires Leader Strikes plus Twists to occupy exactly eight event slots.

Hero identity is a stable content ID. Player rules such as Unity compare IDs dynamically and count unique other Heroes; gameplay code does not maintain a fixed list of Hero IDs.

## Card Abilities

Every Hero and Minion card has an `abilities` array. Normal cards use an empty array; current Ability and Special cards contain one entry with a stable ability ID and a parameter struct reserved for future card-specific values. Gameplay checks abilities through `find_card_ability()` and `card_has_ability()` instead of relying on display text or a single ability field.

The current cards still have at most one ability. This representation allows later cards to hold multiple abilities without changing the card structure.

## Leader Definitions

Leader definitions live in `vv_data.gml`. Each Leader has a stable ID, display name, separate starting and maximum Health, basic Attack, artwork, ability and Special-move arrays, and its available Leader Strike definitions. `reset_game()` initializes the Leader from `starting_hp`; healing and state validation use `max_hp`.

The Velvet Queen currently owns Direct Assault with a default selection of three copies.

## Scenario Definitions

Scenario definitions live in `vv_data.gml`. A Scenario has a stable ID, display name, setup-rule array, Minion-slot definitions with their copy counts, and its available Twist definitions.

`make_scenario_the_assault()` owns the current eight Minion definitions and Reinforcements. The deck builder accepts the selected Leader and Scenario, iterates the Scenario's Minion slots, and clones every physical card. The setup screen validates the selected Leader, Scenario, Heroes, Leader Strikes, and Twists before starting a match.

Prototype Hero and Minion IDs remain only in content and setup definitions. Deck construction and validation iterate the selected Scenario's Minion slots, and gameplay behavior is selected by stable ability or effect IDs. Player-facing messages use card names and ability names from content instead of prototype codes.

## Enemy Event Resolution

Minion Escape effects, Leader Strikes, and Twists use reusable effect entries with a stable ID and parameter struct. Minions keep their effects in `escape_effects`; Enemy Event cards keep theirs in `effects`. Current definitions contain one effect, while the array structure permits future content to combine effects without adding one-off card fields.

Enemy Draw identifies only whether a card is a Leader Strike or Twist, then delegates to `resolve_leader_strike()` or `resolve_twist()` in `vv_enemy.gml`. Minion movement delegates Escape behavior to `resolve_minion_escape()`.

Direct Assault uses the reusable `leader_basic_attack` effect. Reinforcements uses the reusable `area_2_attack` effect. Adding another card that uses either existing effect requires only a content definition; a genuinely new effect requires one localized resolver case.

## Enemy Event Selection

Available Leader Strike definitions belong to the selected Leader, and available Twist definitions belong to the selected Scenario. Each definition supplies a default count and a maximum permitted count. The current selected IDs and copy counts live separately in `enemy_event_selection`.

`validate_enemy_event_selection()` in `vv_state.gml` rejects unavailable or duplicated IDs, invalid counts, copy-limit violations, and totals other than eight. It returns the current total and a clear add/remove/ready message. The Enemy Deck builder uses only the validated selection and never silently inserts, removes, or substitutes an Enemy Event.

The selected Hero IDs are also separate from the available Hero definitions. `validate_hero_selection()` requires exactly three different IDs that exist in the available content. `refresh_setup_validation()` combines the Hero and Enemy Event checks, and `command_start_game_from_setup()` is the only setup command that starts a match.

The setup screen is drawn and routed by `vv_ui.gml`; it does not decide legality. Touch controls send selection commands to `vv_state.gml`, which updates and validates the setup. The Start Game button reflects `setup_validation.valid` and cannot start an invalid match.

The current setup screen displays one active Leader, one active Scenario, and the first three Hero definitions. It adjusts the counts of the current Leader Strike and Twist definitions but does not yet provide Leader, Scenario, or Hero browsing controls. Adding more definitions is safe, but exposing player selection for them requires a separate setup-UI change.

## Runtime Flow and Ownership

`obj_controller` owns the live match variables. Its Create event builds the current content definitions, initializes setup state and the UI, and loads initial artwork without constructing a match. `command_start_game_from_setup()` validates the selections and is the only setup path that calls `reset_game()`. The Step event advances timers and routes taps. The Draw GUI event delegates the full screen to `vv_ui_draw_game()`. The Clean Up event releases dynamic sprites through `vv_assets_cleanup()`.

Rules that need a player choice set `prompt_mode`, `prompt_value`, and `prompt_source`, then return. The UI highlights only legal targets. After a valid command clears the prompt, `resume_after_prompts()` continues queued Enemy attacks or the suspended turn action. New prompt-producing rules must preserve this pause-and-resume pattern.

Every sprite created by `sprite_add()` belongs exclusively to the `vv_assets` cache. Other modules keep sprite IDs for drawing but never delete them. Cleanup enumerates the cache once, deletes valid dynamic sprites, and clears the cached references.

## Adding New Behavior

Existing abilities and effects are reusable content IDs. Assigning an existing ID to another card requires no new rule branch.

For a genuinely new Hero ability, add its stable `ABILITY_*` macro and implement its calculation or command behavior in `vv_player.gml`. For a new Minion ability, add the ID and implement Entry, targeting, or protection behavior in `vv_enemy.gml`. For a new Escape, Leader Strike, or Twist effect, add an `EFFECT_*` macro and the appropriate resolver case in `vv_enemy.gml`.

Display names never select behavior. Gameplay checks `abilities[]`, `escape_effects[]`, or Enemy Event `effects[]` by stable ID. Keep card-specific numeric values in the entry's `params` struct when the resolver supports them.

## Verification

After a content or structural change:

1. run `python tools/verify_card_assets.py` when artwork or artwork paths changed;
2. compile the GameMaker project;
3. open the setup screen and start a match;
4. exercise the changed rule or content; and
5. confirm the Player and Enemy deck-composition checks remain valid.
