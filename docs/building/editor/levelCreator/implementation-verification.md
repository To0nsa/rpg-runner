# Level Creator implementation verification

## Domain / Save recovery — September 9, 2026

The baseline was committed as `9d958389` before implementation. The ledger below
records implemented contracts and completed automated/native verification. The independent creator session has not been performed.
Human time-to-first-Play and confusion measurements are not inferred from tests.

| Contract | Implemented evidence | Focused verification |
| --- | --- | --- |
| Structural Save versus runtime readiness | `ValidationIssue.blocks(operation)` remains strict by default. Level compound commands/export, coordinator preflight/installed checks, Chunk lifecycle/composition/export use Save admission. Capacity and reachable seam errors retain Play and applicable Build blockers. | `level_save_admission_test.dart`; `chunk_v2_domain_plugin_test.dart`; `chunk_v2_seam_analysis_test.dart`; `chunk_flat_starter_test.dart` |
| Save history and identity fences | Level/Parallax reconcile desired content over current baselines/dependencies. Save→Undo→Save advances persisted revisions; first Save seals created identities without recycling ordinals. Repeated-value sequences retain sequential undo targets. | `level_parallax_history_test.dart` |
| Atomic Level/background persistence | Canonical candidate and installed-source validation preserve schema, references, baseline drift, rollback and cleanup contracts. | `level_visual_theme_workflow_test.dart`; `level_save_admission_test.dart` |
| Source-drift intent recovery | Compatible edits reapply over fresh sources; conflicting values require choices. Pending copied backgrounds retain their captured layers while fresh shared backgrounds remain authoritative. A newly occupied theme identity requires a saved-only choice and cannot be overwritten. | `authoring_intent_reconciliation_test.dart`, including the two copied-background regressions |
| Readable repair targets | Typed current Chunk/Prefab documents and complete Parallax/material sources qualify. Missing, partial, malformed or migration-only source cannot suspend the origin. Computed image/value/runtime errors remain repairable. | `dependency_repair_admission_test.dart` |
| Inclusion and stable identity | Explicit strict v1→v2 migration adds required `includeInBuild`; existing records become true, New/Copy false. Ordinals and persisted identities cannot be reassigned/deleted. All sources compile structurally; only included active chunks enter runtime pools/readiness. Excluded ready content can materialize authored Play. | `level_build_inclusion_migration_test.dart`; root Level/generator tests, including actual generated-registry probes; pipeline repository-generation tests; Level admission tests |
| New/Copy and backgrounds | Friendly names allocate stable unique IDs in the domain. New uses standard numeric defaults. Copy settings resets to Automatic/default group; explicit design copy preserves section rules/groups. Empty/shared/copied backgrounds use compound commands; copied layers belong to a new identity without rewriting the source background. | `level_creation_workflow_test.dart`; `level_visual_theme_workflow_test.dart`; `level_save_admission_test.dart` |
| First chunk and group intent | Exact authored targets support empty Levels/current chunk trees. A flat starter uses 600×270, grid 16, Early/active, authored whole-pixel ground and validated `grass_dirt` source images. Empty custom creation uses the same default dimensions and remains deprecated. Requested groups survive create/metadata edits. | `chunk_flat_starter_test.dart`; `chunk_v2_save_plan_test.dart` |
| Starter retry and incomplete sections | A retained starter identity opens existing saved/unsaved content without duplicate sources, even after rename. Explicit designs seed their first referenced group. Saving a partial distinct pool and moving its final group member remain possible, with typed runtime blockers. | `chunk_flat_starter_test.dart`, including both authored Chunk and Level preparation before the first Chunk Save |
| Exact diagnostic destination | Level findings carry owner identity; section findings additionally carry stable `elementId` and authored `fieldKey`, and pacing findings expose their field key. | `level_save_admission_test.dart`; UI destination verification is separate |

Checks executed for these slices:

- Editor domain creation/admission/history/theme batch: 41 tests passed.
- Chunk starter/domain/seam batch: 25 tests passed; expanded starter suite: 7
  tests passed. The direct authored Chunk/Level starter preparation assertion
  also passed its targeted run.
- Chunk lifecycle/store/collision batch: 19 tests passed.
- Recovery/preflight/admission/starter batch: 28 cases passed initially; the
  remaining assertion incorrectly assumed diagnostic ordering matched section
  ordering. It now verifies all stable section IDs and passed its targeted rerun.
- Root schema/migration/generator batch: 32 tests passed at the inclusion milestone,
  including compiled lookup probes for excluded and included-deprecated levels.
  Later Build-service/generator changes are tracked by their owning slice.
- Shared content-pipeline suite: 46 tests passed at the inclusion milestone.
- Targeted editor analysis for domain, Level, Chunk, new recovery/creation tests
  and the shared fixture: no issues.

`test/test_support/chunk_level_fixture.dart` provides a disposable canonical
workspace with valid Level/background/Prefab/tile/material dependencies and a
real material PNG, initially without chunks. Shell journey tests can use the same
fixture rather than relying on evolving live authored content.

The implemented technical contracts are maintained in
`docs/tdd/level_visual_theme_authoring_pipeline.md` and
`docs/tdd/polygon_terrain_authoring_foundation.md`.

## Workspace, shell, and Play — September 9, 2026

- Level UI regression covers focused A→B Save, invalid raw text, neutral
  selection, retained values across Undo/Save/reload, friendly creation, copied
  background choices, Automatic versus explicit section design, and complete
  typed diagnostic navigation including compact Settings.
- Source-generation reconciliation refreshes actual Chunk geometry/counts after
  repair while preserving invalid raw Level buffers. Shared panel tests prove
  mounted state survives resizing and repeated diagnostic visibility requests.
- `level_chunk_shell_journey_test.dart` uses real domain stores and a disposable
  current-schema workspace: New Level, document-wide Save, starter handoff,
  Undo/Redo before first Chunk Save, Save and return to the exact Level, and
  reopen the same saved starter without duplicate or changed files.
- `level_second_chunk_authoring_journey_test.dart` provides one existing starter
  and reusable art/Prefab assets, then uses visible Chunk controls and pointer
  drawing to create a second empty owner, draw its ground polygon, place a
  Prefab and compatible flying enemy marker, activate it, assign a group, and
  Save/return. The persisted composition matches the accepted design, and the
  actual Core sample contains both source chunks. This automated journey passed.
- Shell tests verify whole-domain Save/departure outcomes, Build Save admission,
  source-action locks, local text Undo, modal shortcut guards, and no repeated
  write after committed-refresh failure. Transaction tests cover real occupied
  target and changed-backup recovery preflight, rollback retry and idempotence.
- Shared authored Play, Level Play, and Chunk integration tests exercise actual
  Core scenarios, valid unsaved input, invalid-buffer refusal, no source Save,
  immutable Restart, late preparation cancellation, warnings, retained editor
  state, and selected Chunk marker semantics. The Core sample regression
  compares the first 12 source choices to canonical selection for the seed;
  seed changes/New variation remain presentation-only.
- Runtime fixtures cover never-generated identities, Level settings, background
  definitions, material IDs/regions and image bytes, later-streamed render
  assets, active/deprecated pools, widths, source drift, and exact availability
  failures in normal app/ghost/validator consumers.

## Repository Build — September 9, 2026

The structured generator report and shell-owned service are covered by process,
filesystem-watch, source-snapshot, cancellation, output-transaction, and dialog
fixtures. Generated status is invalidated by source/output edits and never
inferred from process exit alone. A real production-service smoke check resolved
the SDK, checked the repository, built all seven generated outputs, and retained
Built and verified after its own filesystem events; output bytes stayed equal.

The report exposes Open/Add content, Exclude, and Restore as guarded source-domain
navigation/actions. Inclusion changes remain normal pending Level edits. Sources
are saved before replacement, and cancellation becomes unavailable at the atomic
replacement boundary. SDK/report/transaction failures remain explicit outcomes.

## Desktop inspection and acceptance limits

`level_shell_visual_acceptance_test.dart` rendered the actual Home/Level shell
with Segoe UI, MaterialIcons, real repository images, and the Windows target at
1440×900, 1280×800, 1024×768, and 800×600, each at 100%, 125%, and 150% text scale.
All 12 cases passed without layout exceptions. Captures were inspected at wide,
compact, and extreme settings; scrolling exposes Contents/Flow and Settings at
small sizes. Local raster artifacts are under `.tmp/level-shell-visuals` and can
be regenerated with the opt-in test's documented environment setting.

This validates rendered reachability and state, not a human's ease or speed.
The Phase 6 session still requires a creator who did not implement the editor to
build a second useful chunk, edit terrain, place a Prefab/enemy, organize groups,
repair incomplete flow, compare Chunk/Level Play, and report confusion/time.
The active plan is intentionally retained until that acceptance is completed.

## Final automated verification

- Final Core snapshot: analyzer clean, all 389 tests passed.
- Final content-pipeline snapshot: analyzer clean, all 46 tests passed.
- Final recovery/history/departure/Build-focused batch: 37 tests passed.
- Entity Save admission and existing pipeline/scene regression: 14 tests passed.
- Real second-chunk UI authoring/sample journey: passed.
- Native Windows release build: initial build passed in 129.4 seconds; the
  final source rebuild passed in 70.5 seconds. The executable is
  `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
- Full editor regression suite: 749 passed, one opt-in screenshot test skipped.
  The screenshot matrix was run separately: all 12 cases passed.
- Final editor analyzer: no issues found.
- Final suite corrections: the Prefab Save assertion now reflects focused-input
  finalization; the checked-in source baseline includes its existing polygon
  capacity warning. Terrain Materials reuses an already loaded controller on
  mount, preventing a redundant asynchronous reload from blocking edits.

Additional affected-layer validation completed during implementation:

- Generator/artifact transaction and captured-source fixtures: 30 passed.
- App selection/start and ghost regression batch: 37 passed.
- Runtime host/captured asset bundle regression batch: 12 passed.
- Replay validator: all 102 tests passed; analyzer and AOT compilation passed.
  Three 36,000-tick replay benchmarks completed in 0.43–0.54 seconds.
- Required affected-layer analyzers passed. Backend callable and shared wire
  contracts were unchanged; no production deployment was performed.

The remaining work is the Phase 6 independent creator session, including real
workflow observations and responsiveness measurements. Address findings from
that session before closing and archiving the Level plan.
