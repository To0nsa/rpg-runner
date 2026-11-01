# Training Field implementation

Completed locally on November 2, 2026. Current behavior is documented in the
[GDD](../../../gdd/training_field.md) and [TDD](../../../tdd/training_field.md).

Requested: a third Gear/Skills/Training Field tab, with all tabs visible, the
selected build, two normal-size chunks repeating continuously, normal camera
follow with zero automatic advance, resources/controls only, and a settings cog
beside resources. Only Library-unlocked regular enemies are selectable, one at a
time, at the next occurrence of the single marked chunk. Death Reset and leaving
the tab discard the session and enemy selection. No rewards or persistence.

The editor owns only the two-chunk layout and player/enemy positions, through a
dedicated domain sharing geometry tools. Runtime rules have no editor settings.

Existing unrelated changes to preserve: `.gitignore`, `AGENTS.md`, `README.md`.

- [x] Separate authored source, shared compilation, generator integration.
- [x] Core repeating field, zero camera advance, one-shot terrain enemy spawning.
- [x] Game tab, selected build, unlocked enemy picker, controls and reset lifecycle.
- [x] Dedicated editor plugin/page, shared geometry tools and guarded Save/Undo.
- [x] Focused source/Core/UI/editor checks, traversal controls and documentation.

Normal run identity, replay commands and existing level selection stay unchanged.
Training uses an explicit local construction boundary with no run ticket.

## Validation evidence

Source: task changes on `dev`, based on `d9d75edf`, recorded with this change.
All checks below are local. Flutter 3.47.1 / Dart 3.13.1 on Windows; the SDK's
`dart.exe` and `flutter_tools.snapshot` entry points were used directly because
the batch wrappers stalled in this execution environment. Root and independent
editor dependencies were resolved in their respective directories. The editor's
Cupertino constraint and lockfile were aligned with its existing game dependency.

| Working directory | Command / scope | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/training_field_source_test.dart` | 4 passed: strict layout schema, both loop joins, placement admission, start beneath a platform. |
| `packages/runner_core` | `dart test test/training/training_field_test.dart` | 12 passed: idle camera, empty field, continuous player movement, four regular enemy spawns, replacement/None, boss rejection, enemy traversal. |
| `packages/runner_core` | `dart test test/navigation/level_enemy_traversal_test.dart test/navigation/level_enemy_traversal_harness_test.dart test/ecs/derf_terrain_placement_test.dart` | 97 passed, including clear/blocked controls and existing Derf placement. |
| Repository root | `flutter test test/ui/pages/select_character/loadout_setup_page_phase4_test.dart --no-pub` | 4 passed: touch/Windows host variants, app bar, Library filtering, background/resume, death/reset, departure/re-entry, unchanged progression, existing Gear/Skills flows. |
| Repository root | `flutter test test/core/command_scheduling_test.dart test/core/determinism_test.dart --no-pub` | 4 passed; ordinary Field/Forest scheduling and determinism retained. |
| Repository root | `flutter test test/tool/generate_chunk_runtime_data_test.dart --name 'Training Field\|encounter source\|trap source\|excluded Field\|generator smoke\|missing\|unexpected' --no-pub` | 6 passed: separate training artifacts/freshness and normal generator/worker regressions. |
| `tools/editor` | `flutter test test/training_field_domain_plugin_test.dart test/chunk_v2_domain_plugin_test.dart test/home_route_plugin_switch_test.dart test/terrain_material_domain_plugin_test.dart --no-pub` | 38 passed: independent writes, drift rejection, Save/Undo/Redo, page controls and existing authoring/navigation behavior. |
| `tools/editor` | `flutter build windows --debug --no-pub -v` | Passed, including a final build after the Undo/Redo correction; `build/windows/x64/runner/Debug/runner_editor.exe`. Native dependency warnings, zero errors. |
| Owning root/editor directories | Targeted `dart analyze` on changed runtime, pipeline, UI, editor, generator and tests | No errors; reported style findings corrected, affected paths rechecked clean. |
| Repository root | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | Fresh generated outputs. |
| Repository root | `dart run tool/sync_assets.dart --check` | Passed. |
| Repository root | `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | Passed; existing revision `bd2274e0b71f13d538e131be959817d040eb11182da317b2db98903ed26a1e98` reused. |
| Repository root | `node tools/agents/check.mjs`; `git diff --check` | Passed. |

Traversal scope: Training Field seed 1, each of the four regular catalog enemies,
four consecutive chunks plus a fifth continuation chunk, crossing both loop
joins with continuous actor state. The player test crosses three repetitions.
Existing Forest complete-assembly checks use seeds 7, 42, and 2026 for all four
regular enemies; existing Field checks cover a 32-chunk Unoco route. These finite
checks do not establish arbitrary future authored layouts or full-run performance.

No physical Android/device playthrough, manual visual acceptance, or deployment
was performed.
