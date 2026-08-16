# Code Review — August 15, 2026

## Scope

This review covered the complete GameMaker project on `main`: project and resource metadata, controller events, all seven Script Assets, the seven-step turn flow, Hero and Minion behavior, Enemy Events, prompts, card gestures, setup and match navigation, dynamic artwork ownership, documentation, and Windows/Android packaging.

The implementation was compared with `CORE_GAME_RULES.md` and the current card definitions in `vv_data.gml`.

## Results

No unresolved gameplay-rule defect was found. The following behavior was traced through its complete state transition:

- Player draw and discard recycling;
- Area 1 movement, Area 2 push-based Escape, and the rule that an unpushed Area 2 Minion remains;
- Leader Strike and Twist resolution until a Minion enters or the Enemy Deck empties;
- final-chance Build and Attack after Enemy Deck exhaustion;
- Hand/Build placement, swapping, and drag-and-drop;
- Rally, Unity, Overpower, Relentless, Guard, and Fortress;
- Disrupt, Crush, Protector, Shatter, and Devastate;
- Escape healing, Overflow Attack, and Hand destruction;
- whole-card enemy damage, priority targeting, and unused Attack handling;
- victory, defeat, Play Again, Game Options, match-menu pause, and application exit;
- press-and-hold inspection without conflicting with tap actions or Build dragging.

## Changes Made

- Removed the unreferenced `count_live_minions()` helper.
- Removed the obsolete `restart_rect` layout value left behind by the old single-button result screen.
- Removed the legacy singular `ability` property from Player and Minion card instances. The authoritative `abilities[]` entries already contain the stable behavior ID, display name, rules text, and parameters.
- Removed the unused direction parameter from the setup selector rectangle helper.
- Centralized transient card gesture, popup, Build/Attack confirmation, and menu cleanup in `vv_ui_reset_match_interaction()`.
- Applied that reset to Play Again and Game Options transitions so a prior match cannot leave touch or menu state active.
- Reused one Leader-protection lookup per draw frame instead of scanning the two Minion Areas twice.
- Kept Exit Game visible even when invalid content places the setup screen in its safe error state.
- Updated player controls and architecture documentation for the navigation flow.

## Code Kept Intentionally

- The event log remains disabled by default but is retained as a small diagnostic facility.
- Runtime state validation remains enabled because it checks the conserved 45-card Player set, 33-card Enemy set, deck composition, area sizes, Leader Health, and Attack after important state changes.
- Compatibility display text in each card's `effect` field remains because Enemy Event details and artwork fallbacks use it. Gameplay behavior does not branch on this text.
- `array_remove_index()` remains because it is used for both the bounded six-line diagnostic log and the short queued-attack list; replacing it would not materially improve runtime performance.
- Dynamic artwork loading remains cached. Each file is loaded once, missing files are cached as unavailable, and the controller Clean Up event releases every owned sprite exactly once.

## Static Verification

- GameMaker resources declared in `VillainsAndVelvet.yyp`: 9
- Missing declared resources: 0
- Global GML functions after cleanup: 155
- Duplicate function definitions: 0
- Unreferenced function definitions: 0
- Artwork verification: 21 PNG files, 21 Included File entries, and 21 code references
- Whitespace/error check: passed

## Build Verification

- Windows GameMaker compile and release packaging: passed.
- Android GameMaker source generation and compilation: passed.
- Android tester APK assembly: passed. The private release-keystore step remains unavailable, so the tester APK uses the Android debug key.
- APK signature verification: passed.
- Windows ZIP SHA-256: `04F9596E5767DC1E257212B0121A5B52DFBF5D8C086A69D61EB398F07F78EDE7`
- Android APK SHA-256: `3B85508087212E02175CC0EBF7D36CEA5AFB4E08DBA39B377344D18E231E96E0`

## Remaining Product Considerations

These are not current defects:

- The Android download is a tester build signed with the Android debug key until a private release keystore is configured.
- Automated gameplay simulation is not yet part of the project. The existing runtime validators catch card-count and composition corruption, while interaction and visual behavior still require playtesting.
- The UI uses a fixed 1280×720 landscape canvas scaled by GameMaker. Additional device aspect-ratio testing will be useful as the mobile tester pool grows.
