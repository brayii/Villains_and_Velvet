# Code review — September 29, 2026

## Scope and outcome

This review inspected the GameMaker manifest and resource ordering, all Script assets,
controller events, architecture notes, prior audits, ignored build output, and available
verification tools. Gameplay and card balance were left unchanged.

The project remains well divided into Core, Gameplay, AI, and Interface responsibilities.
No unresolved high-severity gameplay defect was found by static review, compilation, or
the automated startup run. Two reliability defects and one consistency issue were fixed.

## Changes

- Artwork cache keys now hash the complete path. The prior replacement scheme mapped
  distinct paths such as `a/b.png` and `a_b.png` to the same struct member, allowing one
  image or a cached load failure to mask another.
- A failed delayed AI-data write now resets its retry timer. Previously, once the timer
  reached its threshold, every subsequent Step frame retried the failing write.
- Runtime Hand and Build length validation now uses `CORE_HAND_SIZE` and
  `CORE_BUILD_SIZE`, keeping validation aligned with the authoritative constants.
- `tools/verify_project_structure.py` now checks resource existence, stale resource-order
  entries, Script parent groups and metadata pairs, duplicate global function names, and
  critical cache, cleanup, retry, and size-constant invariants.
- The verifier has a small regression suite in `tools/tests/` and is part of the documented
  structural-change workflow.
- Ignored `output/` and `.release/` directories were removed with the repository's guarded
  cleanup tool: 116 regenerable files totaling 140.3 MB.

## Organization decisions

The large `vv_ai.gml` file contains production ranking, seeded evaluation, its exhaustive
oracle, and AI self-checks. The seeded development baseline calls the evaluator during
controlled runs, so merely moving those functions into another Script would not reduce
compiled code or runtime dependencies. This review documents that ownership rather than
creating a cosmetic split with additional resource metadata.

Workspace-level drafts, backups, APKs, source sheets, and signing material outside the
`Villains_and_Velvet` Git repository were not moved or deleted. Their ownership and current
use cannot be established from source references alone. The nested Git repository remains
the development source of truth.

## Verification

- Project structure: 28 resources, 375 unique global functions, 10 resource groups.
- Structure-tool regression tests: 2 passed.
- Artwork: 21 PNG files, 21 Included File entries, 21 code references.
- GameMaker VM compilation: passed with runtime 2026.0.0.23.
- Windows runner: reached the main loop with startup release checks enabled.
- Project-learning framework: 24 tests passed before final lifecycle recording.
- Git whitespace check: passed.

The command-line runner reported that it could not load the IDE user's local settings file,
then compiled and ran successfully using generated defaults. This affects the isolated CLI
test environment, not the project source.

## Remaining limits

The review did not perform a full interactive playthrough, Android compilation, performance
profiling on target hardware, or destructive cleanup outside the nested Git repository.
The fixed 1280-wide interface and the amount of AI development instrumentation remain
documented product and maintenance considerations rather than newly verified defects.
