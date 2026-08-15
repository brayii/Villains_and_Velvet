# Villains & Velvet Architecture

`obj_controller` remains the main controller. Its events only initialize, update, draw, and clean up the game; the rules live in focused Script Assets.

## Where Changes Belong

- `scripts/vv_data/vv_data.gml`: Leader data, card definitions, card counts, names, stats, stable ability IDs, artwork paths, and deck construction.
- `scripts/vv_state/vv_state.gml`: game reset, state validation, card-space counts, and event-log storage.
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
