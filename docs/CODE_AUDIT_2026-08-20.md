# Code Audit — 2026-08-20

## Scope

This audit reviewed the complete GameMaker project manifest, every Script resource, the controller events, the room, all Sound resources, shared runtime variables, function ownership, repeated constants, and build metadata. Gameplay rules and card balance were kept unchanged.

## Project organization

The GameMaker resource tree is organized as follows:

- Scripts
  - Core: data definitions, state, settings, and dynamic artwork
  - Gameplay: turn flow, Player rules, Enemy rules, and training
  - AI: Enemy Auto policy and persistent learning data
  - Interface: shared UI, battle UI, and setup UI
- Sounds
  - Music
  - Effects
- Objects
- Rooms

The groups change only how resources appear in GameMaker. Files remain in their established repository folders, avoiding unnecessary path churn.

## Code cleanup completed

- Removed three unused Enemy Auto convenience wrappers whose parameterized implementations are the real call sites.
- Removed an obsolete training callback duplicated by the completed Enemy-phase callback.
- Confirmed that no duplicate function definitions remain.
- Retained four apparently uncalled functions because they are intentional development entry points for deterministic playtests, exploration seeding, and learning-data reset.
- Added named constants for Hand size, Build size, gesture thresholds, inspection timing, delayed-choice reminders, Escape animation duration, and training WATCH duration.
- Replaced repeated Hand/Build size literals in active Player, Enemy, state, turn, and interface paths.
- Replaced the remaining hardcoded Bunny training Attack text with the live Minion value.

## Variable review

Runtime state remains owned by `obj_controller` and initialized through the Core, Interface, training, and Enemy Auto initialization functions. Temporary calculations use local variables. No shared variable was removed unless it had no remaining reader or caller.

The project intentionally uses instance variables for the single controller because GameMaker scripts execute in that controller's context. Converting those fields into unrelated global variables or wrapper structs would add indirection without improving ownership.

## Hardcoded values

Gameplay quantities belong to card, Leader, Scenario, and Minion Set definitions. Active ability resolution reads those values from effect parameters rather than duplicating card numbers in rule code.

Fixed screen coordinates remain in the Interface modules because they define the current 1280-wide designed layout. They are presentation geometry, not gameplay balance values. A future responsive-layout project should replace them as one coordinated layout change instead of scattering partial scaling logic through gameplay code.

Development-only expected values remain in self-checks. Those literals are deliberate regression assertions and should not be replaced with the same values being tested.

## Retained development interfaces

The following functions have no normal gameplay caller but remain intentionally available for controlled development work:

- `enemy_ai_start_seeded_playtest`
- `enemy_ai_stop_seeded_playtest`
- `enemy_ai_set_exploration_seed`
- `vv_ai_data_reset_enemy_learning`

They are documented test controls, not dead production paths.

## Verification requirements

Before this audit is considered complete:

- every resource parent must resolve to a declared GameMaker group;
- all resource paths in the project manifest must resolve;
- GameMaker compilation must succeed;
- startup release self-checks must pass;
- the Windows runner must reach its main loop without a runtime exception;
- the Git working tree must contain no generated package or cache changes.
