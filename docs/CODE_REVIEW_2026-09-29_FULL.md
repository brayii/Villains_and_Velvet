# Full Code Review — 2026-09-29

## Scope

This review covered all 17 maintained GML source files, the controller object
events, GameMaker resource structure, persistence code, content validation,
player and enemy turn flow, tutorial flow, dynamic artwork ownership, and the
Python verification tools. Executable behavior was checked against
`CORE_GAME_RULES.md` and the current card definitions.

## Finding fixed

### Persistence file handles could remain open after an exception

**Severity:** Low

`vv_settings_load`, `vv_settings_save_if_dirty`, `vv_ai_data_load`, and
`vv_ai_data_save_if_dirty` opened text files inside `try` blocks but returned
from their `catch` blocks without closing a handle that had already opened.
An interrupted read or write could therefore leak a handle. Repeated save
retries made the AI-data write path the most exposed instance.

Each function now initializes its handle to `-1`, clears it after a successful
close, and closes an opened handle on the error path. Existing recovery and
retry behavior is unchanged.

## Review outcome

No additional correctness defect was confirmed. The current code preserves
the 45-card player-deck invariant, whole-card damage, Build-only Overflow and
Full Assault targeting, two-area Minion advance and escape order, event-deck
composition, tutorial resume behavior, and dynamic sprite cleanup.

The fixed 1280-wide presentation layout and retained dormant Hand-attack
machinery remain deliberate product and architecture choices. They are not
correctness defects in the current ruleset.

## Verification

- Project structure verifier: 28 resources, 375 global functions, 10 groups.
- Structure tests: 2 passed.
- GML call audit: 17 files, 375 functions, 57 macros, zero undefined calls.
- GameMaker 2026.0.0.23 Windows VM compilation: passed.
- Windows runner: reached the main loop with startup self-checks enabled.

The sandboxed runner could not write its normal settings and AI-data files in
the user profile. Both failures followed the intended recovery path and did
not prevent startup.

## Project-learning champion evaluation

The relevant-file objective still uses the deterministic `lexical-v1`
baseline. The generated dataset contains one usable task and no held-out test
examples. Configuration requires at least 10 usable tasks for TF-IDF training
and at least 10 held-out examples for promotion. No challenger can be trained
or promoted from the current evidence without violating the promotion rules.
