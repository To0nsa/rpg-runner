# Campaign progressive HUD and first coin

Implemented and locally validated November 13, 2026. Extend the existing movement lesson with an ordered
first-coin explanation. Preserve the pre-existing dirty tree, including the first
tutorial and shared runtime work; baseline is in ignored `build/coin_tutorial_baseline/`.

## Acceptance

- [x] Reporting for Duty initially shows only movement; normal Pause/Exit
  lifecycle remains available (the start lesson already holds simulation pause).
- [x] Other abilities are unavailable through touch, keyboard and mouse.
- [x] The first collected coin is committed, then pauses play and reveals the
  Distance/Collectibles panel with localized guidance and an anchored spotlight.
- [x] Existing held input cannot dismiss the lesson. A fresh movement gesture
  resumes and remains held. Introduced HUD remains visible through the attempt.
- [x] Game and editor share one attempt-owned tutorial progression controller;
  restart resets it; manual/lifecycle pauses, readiness and calibration retain priority.
- [x] Campaign authoring supports initial HUD, two ordered lessons, reveal settings,
  translated text, manual anchored spotlights, history/Save and frozen Play capture.
- [x] Ordinary missions/modes retain their normal HUD and input policy.
- [x] The authored first coin is reachable by walking; checks declare their scope.
- [x] Focused source/runtime/input/editor tests and targeted analysis pass.
- [x] Current documentation and source preservation reviewed.
- [x] Final generated freshness.
- [x] Final Windows release rebuild after the mobility-aim correction.

## Sequence

1. Extend authored contracts and migrate every producer/consumer together.
2. Add shared progression, tick-boundary interruption and semantic action gating.
3. Extend HUD/spotlight/editor composition and author Reporting for Duty content.
4. Verify real pickup progression and lifecycle edges; update current docs, review
   task diff and rebuild the Windows editor. Archive this checklist on completion.

Scope remains two triggers (mission start and first collected coin), two spotlight
targets (movement and run counters), and per-attempt progression. No account
persistence, arbitrary scripting or new reward rules. Physical calibration is unchanged.

## Evidence

Local automated evidence, November 13, 2026. Commands used the installed Dart
executable and `flutter_tools.snapshot` to avoid Windows batch-launch delays.

- Root Flutter regression set: semantic dispatcher, desktop input, bindings,
  GameController input/readiness, tutorial overlay/controller, score overlay and
  full playtest-host suite. 87 cases passed; the initial invocation also reported
  one startup-test compilation error (nullable test callback). After fixing that
  test, the entire startup suite passed (15 cases). Final committed-tick retirement
  and real-coin tests passed together (11 cases, overlapping earlier coverage).
  Logs: `build/coin_tutorial_regression.log`, `coin_tutorial_product.log`,
  `coin_tutorial_tick.log`.
- Pipeline (cwd `packages/runner_content_pipeline`):
  `dart test test/campaign_tutorial_test.dart test/campaign_source_test.dart`:
  12 passed. Null/unknown HUD fields, ordering, immutable values, legacy source
  compatibility and campaign compilation covered. Route-replacement fixtures now
  remove original placements instead of retaining references to absent chunks.
- Editor (cwd `tools/editor`): `flutter test test/campaign_tutorial_dialog_test.dart
  test/campaign_authoring_test.dart --name "lesson|translation|opening|Tutorial
  sequences|tutorial edits" --concurrency=2`: 6 passed. Movement/coin spotlight,
  translations, initial/revealed HUD, Undo, Save and frozen capture checked.
- Targeted Dart analysis passed for changed runtime, pipeline, editor and tests;
  two test-style infos were corrected and that file reanalyzed cleanly.
- Generated backend catalog: `node functions/node_modules/typescript/bin/tsc
  -p functions/tsconfig.json --noEmit` passed. No services deployed.
- Real Reporting for Duty, seed 42, catalog Éloïse, continuous state from authored
  spawn to first coin within a finite 300-tick horizon. No teleport, jump, geometry
  changes or tolerance changes. Touch variants and keyboard/HUD-off all verified;
  this is not full-route completion or later-lesson traversal coverage.
- Screenshot `build/test/first_coin_tutorial.png` inspected. The first copy was
  too long at phone size, so English/French text was shortened and continuation
  moved first. Card remains scrollable for longer authored translations.
- Source comparison against task baseline confirms every non-tutorial authored
  field and the original movement lesson remain unchanged apart from revisions.
- `git diff --check` passed. Generated source remains generator-owned; its
  canonical formatting was restored after the formatter touched the UI catalog.

## Adaptations and limits

- Added a committed-tick observer on GameController so a coin lesson cannot leak
  later ticks from a batched frame. Retirement during an observer now stops before
  further simulation/notification; explicit regression coverage was added.
- Editor transitions set phase before enabling input, preserving the accepted
  gesture across synchronous binding notifications. Manual/calibration resume
  restores guidance without advancing simulation. Product exit confirmation and
  mobile lifecycle follow the same rule.
- Extracted shared counter panel/action row and generic tutorial overlay; editor
  shelf, dialog and HUD picker have separate focused owners. No general scripting.
- A pre-existing/new concurrent GoldCoin icon call blocked Flutter compilation;
  corrected its named constructor arguments to the existing positional signature.
- Global localization check currently flags unrelated Achievements files and
  exemptions (`build/coin_tutorial_localization.log`). Tutorial source/translation
  validation passes. Those concurrent changes were left intact.
- No native interactive/phone or ruler calibration acceptance is claimed. Existing
  physical calibration is unchanged. The running editor was asked to save/close
  before replacing build output. The build succeeded while that instance remained
  open; restart is required to load the new code.
- No commit: this task extends uncommitted earlier tutorial/runtime work, and other
  work continues in the same checkout. Staging only this delta would not produce
  an independently buildable milestone; all unrelated edits/staging are preserved.


## Final review and Windows artifact

The initial HUD checkbox was also exercised through the editor page and Undo
(1 passed, `build/coin_tutorial_initial_hud.log`). The test waits for scrolling
layout before interacting with the header after Undo. Reviewing independent feature
reveals found directional mobility must participate in the aim gate. That correction
and all semantic-dispatcher tests plus the real-coin gate passed (25 cases,
`build/coin_tutorial_mobility.log`). Final analysis was clean
(`build/coin_tutorial_last_analysis.log`).

`flutter build windows --release --no-pub` from `tools/editor` passed. The first
build took 349.3 s; the final rebuild after the mobility correction took 168.6 s
(`build/coin_tutorial_windows_final.log`). The native launcher was reused; the Dart
AOT payload was rebuilt. Final generator `--dry-run` passed
(`build/coin_tutorial_freshness.log`). Documentation local-link checks,
`git diff --check` and source-preservation comparisons passed.

Final AOT payload: `tools/editor/build/windows/x64/runner/Release/data/app.so`, 16860040 bytes,
SHA-256 `AC80D9DF676B834A4B6B46E20898026DB5AA3F695D32D6D988BC8735C329C5E3`.
Launcher: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
