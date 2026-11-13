# Campaign blessing objective and tutorial — 2026-11-13

Reporting for Duty revision **43**, content digest
`2336ee12c6d6dd2d2cdb0159a27fe366390e9cb588115fba5bffca2fb4a760fc`.
Task baseline revision was 42. The authored delta is one three-page lesson, one
`blessingObjectiveShrineId` and one revision increment. Terrain, shrine marker,
regeneration rates, abilities and replay encoding are unchanged. Existing dirty
work and concurrent hub/localization work are preserved; this task remains
uncommitted alongside its uncommitted framework dependencies.

## Delivered behavior and design

The grounded approach pauses at world X 3732–3738, 96 units before the selected
basin top at X 3828–3852/Y 160. Page one reveals **Receive a blessing 0/1** and Jump.
Fresh movement resumes practice. Only actual top-contact activation satisfies
the exact authored shrine goal. Passing it leaves practice pending; returning
and landing works. An unrelated shrine cannot satisfy it. The goal gates the exit
even with guidance disabled/removed, and persists through the attempt.

The activation snapshot shows the lit fire, blessing and **Receive a blessing 1/1 ✓**
together. Page two explains the grant; Next opens resource and blessing-indicator
guidance. Fresh movement resumes; completed rows hold for three seconds plus a
250 ms fade measured in committed gameplay ticks. Coin/blessing ages are independent.
Restart clears both Core progress and presentation. A late-attaching view skips an
obsolete objective prompt when Core already recorded the grant.

Jump and blessing use shared immutable steps and one editor dialog. The shrine
marker, distance, bilingual text, reveals and three independent spotlights join
revision-guarded Apply, Undo/Redo, Save/reopen and captured Play. Required references
remain strict even when disabled; marker deletion requires explicit reassignment.
The resource page previews the same bars and badge widgets used in game.

The landing test found objective evaluation previously preceded shrine activation.
World interactions now run after death/Campaign failure checks and before the
living-player objective/exit gate; regeneration remains after that gate. The
simultaneous shrine/exit case completes on the activation tick. Include this local
ordering change in the next coordinated gameplay compatibility release; nothing
was deployed here.

## Local verification

| Directory | Command | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_blessing_tutorial_test.dart test/campaign_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 23 passed: strict languages/pages/reveals, exact shrine binding, moved targets, disabled/missing reference checks, immutable capture, source regressions |
| `packages/runner_core` | `dart test test/campaign/campaign_runtime_test.dart test/playtest/campaign_construction_parity_test.dart test/interactions/world_interaction_game_core_test.dart --reporter expanded` | 16 passed: required versus unrelated shrine, exit gate, same-tick exit, reset, command replay, generated/captured parity, actual contact at 30/60/120 Hz |
| Root | `flutter test --no-pub test/core --concurrency=2 --reporter expanded` | 525 passed after the ordering change |
| Root | `flutter test --no-pub test/ui/tutorial/campaign_tutorial_controller_test.dart test/ui/campaign/campaign_hud_test.dart --concurrency=1 --reporter expanded` | 8 passed: continuous route, bypass/return, late guidance, pauses/input, independent row aging, compact French HUD |
| Root | `flutter test --no-pub test/playtest/runner_chunk_playtest_host_test.dart --plain-name 'ordered tutorials' --concurrency=1 --reporter expanded` | 4 passed: arrows, fixed/floating joystick and hidden-HUD keyboard; actual grant, Next/fresh-input gates, post-basin travel, fade and restart |
| Root | `flutter test --no-pub test/ui/tutorial/movement_tutorial_overlay_test.dart --reporter expanded` | 8 passed: French blessing pages with enlarged text, reachable Next, existing projection and layout regressions |
| `tools/editor` | `flutter test --no-pub test/campaign_tutorial_dialog_test.dart --reporter expanded` | 7 passed: jump/blessing shared form, hidden French validation, spotlight dragging, missing shrine and Cancel |
| `tools/editor` | `flutter test --no-pub test/campaign_authoring_test.dart --plain-name 'tutorial' --reporter expanded`, then `--plain-name 'Tutorial sequences tab'` | 2 passed: Save/reopen/captured Play, actual tab Apply/Undo and source objective binding |
| `services/replay_validator` | `dart test test/validator_worker_test.dart --name 'Reporting|campaign missing catalog' --reporter expanded` | 4 passed with current recording environment below; actual Core/worker replay, fake transport/storage/settlement |
| Root | `flutter test --no-pub test/tool/generate_chunk_runtime_data_test.dart --plain-name 'campaign generates' --reporter expanded` | 1 passed: generated exact-shrine requirement and terminal campaign replay through real worker at 30/120 Hz |

For the source-bound UI-to-worker recording, set PowerShell
`$env:REPORTING_BLESSING_REPLAY_PATH='C:/dev/Lothringen/long-run/build/reporting_blessing_replay.json'`
before the controller test and worker test above. The first writes its actual
applied command stream through the seven-chunk horizon; the worker rejects a
mismatched content digest, reproduces exact position/health/resource/stamina and
both objectives, then validates the give-up outcome. This is a bounded prefix,
not a full Reporting for Duty clear. Without that environment the recording-dependent
worker case is explicitly skipped. The generated fixture separately proves a
complete mission outcome at two tick rates.

Root, editor and worker scoped analysis pass. Root
`dart run tool/generate_chunk_runtime_data.dart --dry-run` validates 166 chunks and
fresh outputs; `dart run tool/localization.dart check` passes English/French;
`corepack pnpm --dir functions build` passes. Logs are in ignored
`build/blessing_*.log`. Geometry/navigation inputs did not change, so existing
navigation evidence is reused rather than rerun.

Reviewed `build/test/blessing_objective.png`, `blessing_received.png`, and
`blessing_resources.png`. Screenshot review exposed a covered fire; shared card
placement now avoids the world spotlight when side/upper space is available.
The final four-mode run asserts that the reward card does not overlap the actual
opening. These are widget-rendered mobile previews with authored artwork, not a
native executable, phone or physical-monitor calibration check.

Continuous traversal uses seed 42 and catalog Éloïse, ordinary inputs and finite
budgets, from authored spawn through X ≥4200. It includes the previous lessons,
three fourth-chunk platform tops, the fifth-chunk pool via two platforms, both
sixth-chunk dry gaps, the basin and following statue. No teleportation, collision
changes or tolerance widening. There is no enemy, full-mission, performance,
physical-device or live backend acceptance claim.

## Windows artifact

`flutter build windows --release --no-pub` from `tools/editor` succeeded in
258.7 seconds. Two concurrent Town UI source edits were preserved; a final
incremental build succeeded in **114.5 seconds**. All 1811 captured source
inputs and the final file inventory match through that build.

Ready executable: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
Its `data/app.so` is 17,056,648 bytes, SHA-256
`5a309baef18f755ab3e620b90394999655060f0484375fd7c120bd6f30acf321`.
The payload contains the blessing lesson, trigger and objective label. Local
provenance is in `build/blessing_windows_artifact.json`; scoped whitespace and
Markdown link checks pass. No native executable launch or backend deployment
is claimed.
