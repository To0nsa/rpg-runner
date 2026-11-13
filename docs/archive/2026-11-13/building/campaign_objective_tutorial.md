# Campaign objectives introduction

Authorized November 13, 2026. Insert an objectives lesson between movement and
first-coin guidance, with a real collect-one-coin requirement for Reporting for
Duty. Preserve the existing dirty checkout and authored geometry; task baseline
is in ignored `build/objective_tutorial_baseline/`.

## Acceptance

- [x] Movement starts normally; the first committed horizontal movement pauses
  to reveal and spotlight the objectives panel. Existing held input cannot dismiss it.
- [x] The first objective is Collect a coin, owned by Core and satisfied by the
  actual pickup. Exit cannot complete the mission before this requirement.
- [x] Fresh movement resumes; first coin checks off the objective and shows the
  existing counters lesson. Manual/lifecycle/calibration pauses retain priority.
- [x] Three ordered lessons, translated text, persistent reveals and manual
  spotlights are editable through normal Save/Undo/captured Play.
- [x] Game and editor share objective presentation and tutorial progression;
  other missions default to no new requirement; restart resets attempt state.
- [x] Generated consumers, replay/Core/input/editor tests, docs and Windows build.

## Approach and validation

Add optional `requiresFirstCoin` (false when absent) to source and Core mission
contracts. CampaignSession observes committed pickup count during its existing
living-player objective phase, after pickup resolution and death precedence;
no system reordering or command encoding changes. Immutable CampaignSnapshot
exposes the required/completed coin goal. Content revision/digest fences bind this
new mission configuration; existing configurations with the default retain their
behavior. No service deployment is authorized.

Extend bounded tutorial triggers with movementStarted and target objectives.
Share fixed-panel lesson decoding/presentation between objective and coin lessons;
reuse the actual objective panel in the spotlight authoring canvas. Check the
real authored spawn-to-coin path, negative exit control, replay parity, all movement
adapters, pause/restart and source/authoring contracts. Root Core terminal regression
suite is required by the simulation workflow; use two workers to bound RAM.

## Evidence

Source/model, Core objective and three-step runtime/editor implementation complete.
Campaign catalog revision 9 → 10; Reporting for Duty revision 31 → 32. Parsed
comparison confirms both prior lessons and all other authored data/geometry are
unchanged. `generate_chunk_runtime_data.dart --dry-run` passed before route tests.

Root `flutter test test/ui/tutorial/campaign_tutorial_controller_test.dart
test/playtest/runner_chunk_playtest_host_test.dart
test/ui/runner_game_widget_startup_test.dart --no-pub --concurrency=2 --reporter expanded`:
38 passed. Actual Reporting spawn-to-coin path (seed 42, Éloïse, finite 300 ticks)
is tested with arrows, floating/fixed joysticks and hidden-HUD keyboard. Product
recorder/lifecycle and editor pause/calibration/restart retain priority. Visual
captures `build/test/objectives_tutorial.png` and `first_coin_tutorial.png` reviewed.

Additional validation, against this task's working tree (SDK/cache permissions;
no cloud calls):

| Working directory | Command / scope | Result |
| --- | --- | --- |
| Root | `flutter test test/core test/ui/tutorial/campaign_tutorial_controller_test.dart --no-pub --concurrency=2 --reporter expanded` | 526 passed, including neutral-input and real pickup guidance |
| `packages/runner_core` | `dart test test/campaign/campaign_runtime_test.dart --concurrency=2 --reporter expanded` | 5 passed; continuous negative exit → coin → successful exit and command replay, seed 42, Éloïse, at most 1,200 ticks per leg |
| `packages/runner_core` | `dart test test/playtest/campaign_construction_parity_test.dart --concurrency=2 --reporter expanded` | 2 passed, both characters, trusted/captured 360-tick parity |
| `packages/runner_content_pipeline` | `dart test test/campaign_source_test.dart test/campaign_tutorial_test.dart --concurrency=2 --reporter expanded` | 13 passed; strict optional objective and ordered lessons |
| `tools/editor` | `flutter test test/campaign_tutorial_dialog_test.dart test/campaign_authoring_test.dart test/campaign_settings_test.dart --no-pub --concurrency=2 --reporter expanded` | 35 passed; real panel, translation/reveals/spotlight, Save/Undo/frozen Play |
| `services/replay_validator` | `dart test test/validator_worker_test.dart --name 'campaign\|Reporting coin' --concurrency=2 --reporter expanded` | 3 passed; 1 existing fixture-gated generated-catalog test skipped because its environment fixture was not installed |
| Root / owning packages | `dart analyze` changed runtime/HUD/tests/generator, Core mission/snapshot, pipeline and editor paths separately | All passed; exact path lists and output in `build/objective_tutorial_*_analysis.log` |
| Root | `node functions/node_modules/typescript/bin/tsc -p functions/tsconfig.json --noEmit` | Passed |
| Root | `dart --packages=.dart_tool/package_config.json tool/localization.dart generate` and `check` | Passed, English/French |
| `services/replay_validator` | `dart compile exe bin/server.dart -o ../../build/objective_tutorial_validator.exe`, then that executable `benchmark --ticks=36000 --strict` | Passed all included levels, deterministic outcome and progress/throughput gates; local Windows evidence, not container/release acceptance |

The initial source test expected an ArgumentError; corrected it to the compiler's
existing FormatException wrapper, then passed. Initial mixed-context analysis was
cancelled without a result and replaced by successful scoped analysis. No runtime
failures or tolerances were hidden. Source/generated diff and spotlight screenshots
reviewed. Current logs are ignored under `build/objective_tutorial_*`.

Windows editor: `flutter build windows --release --no-pub` from `tools/editor`
passed (332.9 seconds). Artifact:
`tools/editor/build/windows/x64/runner/Release/runner_editor.exe` with rebuilt
`data/app.so`, SHA-256 `b777cc6a9d604dc9cced7b5052608748afd93e3acbd380f4536b84ca5ba73d36`.
Worker test analysis also passed. All acceptance items above are complete locally;
this record is archived.
No service deployment or physical-device acceptance is claimed. The authored
Reporting route is verified only from spawn to the first coin, not end-to-end or
through later ability introductions. Unrelated changes (including concurrent
character localization edits) remain untouched. The task depends on earlier
uncommitted tutorial/playtest work, so no isolated task commit is created.
