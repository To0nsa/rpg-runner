# Campaign movement introduction

Completed locally November 13, 2026. Current behavior is documented in the
[tutorial contract](../../../tdd/campaign_tutorials.md).

Requested November 13, 2026. Implement only the first mission-start movement
lesson, authored under Campaign → Tutorial sequences. Existing Campaign/runtime
work is uncommitted and must be preserved; baseline copies are in ignored
`build/tutorial_baseline/`.

## Acceptance

- [x] Reporting for Duty has an enabled localized movement introduction.
- [x] The Campaign tab supports guarded edits, Undo/Redo, Save and captured Play.
- [x] Authors can drag/resize an ellipse or rounded spotlight relative to the
  actual arrows, fixed joystick or floating activation area.
- [x] Game and editor share the overlay; device scaling never changes its anchor.
- [x] World/HUD load at tick zero. Only movement begins play; the dismissing
  pointer/key remains held without a second gesture. Unrelated input cannot start.
- [x] Restart repeats the introduction; pause/resume does not. Focus, lifecycle,
  loading and calibration gates remain authoritative.
- [x] Hidden mobile HUD uses keyboard instructions without an invisible target.
- [x] Strict source/generation, gesture, lifecycle and editor tests pass; current
  GDD/TDD and editor instructions describe the delivered workflow.

## Implementation order

1. Shared pure-Dart authored presentation model and Campaign projection/capture.
2. Shared spotlight presentation and movement-only start handshake.
3. Campaign sequence editor, anchored spotlight authoring and initial content.
4. Focused validation, generated freshness, documentation and full task review.

No practice conditions, world targets, arrows, account persistence or new rewards.
Tutorials affect presentation/start gating only; deterministic movement and replay
commands continue through the existing dispatcher.

## Evidence

Local verification on November 13, 2026. Commands use Flutter 3.47.1 / Dart
3.13.1, invoking the SDK executable directly because the batch launcher stalled.
Context7 was unavailable; official Flutter Listener and RenderBox coordinate
documentation was checked directly. No deployment or phone acceptance was run.

| Check | Working directory / scope | Result |
| --- | --- | --- |
| Dart test | `packages/runner_content_pipeline`; `test/campaign_tutorial_test.dart`, `test/campaign_source_test.dart` | 11 passed |
| Flutter test, concurrency 2 | Root; `test/playtest/runner_chunk_playtest_host_test.dart`, `test/ui/input/desktop/runner_desktop_input_adapter_test.dart`, `test/ui/runner_game_widget_startup_test.dart` | 49 passed |
| Flutter test | Root; `test/ui/tutorial/movement_tutorial_overlay_test.dart` | French, enlarged text and compact-phone card layout passed |
| Flutter test | `tools/editor`; `test/campaign_tutorial_dialog_test.dart`, selected `test/campaign_authoring_test.dart` cases | Three dialog cases passed, including oversized movement/redraw; edit/Undo/Save/capture, Campaign layout and tab-to-preview workflow passed |
| Dart analyze | Root and editor; changed runtime/input/pipeline/editor code and tests | No issues found |
| Runtime generator `--dry-run` | Root; `tool/generate_chunk_runtime_data.dart` | Generated catalogs current |
| TypeScript compiler | `functions`; `node node_modules/typescript/bin/tsc` | Passed |
| Localization check | Root; `tool/localization.dart check` | English/French passed |
| Instruction validation | Root; `node tools/agents/check.mjs` | Passed |
| Windows Release build | `tools/editor`; `flutter build windows --release --no-pub` | Final build passed in 261.2 seconds, including the boundary fix |

Ignored local logs are under `build/tutorial_*`. The root runtime test renders
all three movement variants in an 844×390 Play viewport; all three images were
visually inspected. Tests exercise same-pointer/key retention, foreground and
calibration rejection, focus reacquisition, no ability/arrow-gap dismissal,
restart repetition and hidden-HUD keyboard fallback. Product startup coverage
also waits for recording readiness before admitting movement.

The first Campaign tab test timed out on `pumpAndSettle` because the preview is
animated. Using the existing bounded workspace pump and scoping modal finders
fixed the test harness; the final isolated tab test passed. Final dialog geometry
evidence is `build/tutorial_editor_dialog_boundary.log`; tab evidence is
`build/tutorial_editor_tab_final.log`. Earlier failed logs are retained as history,
not counted as passes. No native interactive or real-phone acceptance is claimed.
The final editor bundle is under
`tools/editor/build/windows/x64/runner/Release/`; source and bundle hashes are
recorded in ignored `build/tutorial_verified_sources.json` and
`build/tutorial_verified_artifacts.json`. Final build evidence is
`build/tutorial_editor_windows_final.log`.

## Review decisions

- Relative geometry uses the mounted control bounds and the existing display
  transform. The authoring diagram explicitly fits its panel; calibrated Play
  retains physical size. No calibration policy was changed.
- A fresh admitted movement event enables the host before ordinary input tracking.
  Deferred focus may preserve only this new gesture; normal cancellation remains
  authoritative on pause, exit, focus loss and lifecycle transitions.
- Manual openings are clipped to the device. Card scrolling stays above the
  floating joystick activation area, including enlarged translated text.
- Final review found that the rectangle helper assumes nonnegative canvas bounds.
  Spotlight authoring now translates its full allowed relative envelope into that
  helper's coordinate space; oversized openings and negative offsets remain
  editable. A regression verifies movement and redraw through the actual canvas.
- Campaign editing reuses document identity/revision guards and frozen Play
  capture. No second persistence owner or Core tutorial state was introduced.
- Localization validation exposed stale exception paths from the earlier runtime
  refactor. Three existing replay diagnostic exemptions were moved to their
  current owner and obsolete exemptions removed; behavior was unchanged.
- Existing uncommitted work was preserved. This milestone is not committed because
  its shared files depend on that earlier uncommitted runtime/Campaign work.
