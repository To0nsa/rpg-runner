# Campaign water tutorial — local verification

Source: Reporting for Duty revision 38, catalog digest
`6ba0b97179a265db092a61581df2a1900422762d339d88a300e02f7f5453b9f6`.
The authored diff adds only water/swimming lessons and one mission revision.
Pool geometry, actor tuning, replay commands and reward rules are unchanged.
This is uncommitted work on top of the existing dirty checkout; no unrelated
changes were reset, staged or committed.

## Behavior and scope

- Water introduction references `mission_chunk_2` / `water_1`. At world X 868,
  committed player progress pauses before the bank at X 888, including airborne
  approaches. The world spotlight follows the actual water region.
- Fresh movement resumes. First actual swimming triggers a separate optional
  hint when a stroke is affordable/unlocked. Fresh Jump performs a real stroke
  and spends stamina through normal input. Repeated/held input cannot dismiss it.
- A real running jump from the far side of the rock bypasses the pool; returning
  into water triggers the unused swimming hint. Reimmersion does not repeat it.
  An unmet optional hint does not block a later route lesson.
- Captured editor and product use the same controller, real Jump control and
  world projection. Source references validate during compilation/binding;
  editor drafts, Cancel, Undo/Redo, Save/reopen and frozen Play capture remain
  on the existing transaction path.

## Checks

Commands use the installed Dart/Flutter SDK. `flutter test` commands use
`--no-pub --reporter expanded` except the initial runtime run. Logs are ignored
under `build/water_tutorial_*.log`.

| Working directory | Command / target | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 17 pass: strict bilingual source, invalid fields, missing/disabled water targets, captured geometry |
| Root | `flutter test test/ui/tutorial test/ui/runner_game_widget_startup_test.dart` | 22 pass: shared progression, French enlarged text, recorder readiness, pause/lifecycle |
| Root | `flutter test test/ui/tutorial/campaign_tutorial_controller_test.dart` | Final 3 pass: optional scheduling, continuous immersion and bypass/return paths |
| Root | `flutter test test/playtest/runner_chunk_playtest_host_test.dart --plain-name 'ordered tutorials reach chunk two'` | 4 pass: arrows, floating/fixed joystick, hidden HUD/keyboard through both water lessons, fresh input, pause/resume and restart |
| `tools/editor` | `flutter test test/campaign_water_tutorial_dialog_test.dart test/campaign_tutorial_dialog_test.dart test/campaign_authoring_test.dart` | Initial 34 pass, 2 failures investigated below |
| `tools/editor` | `flutter test test/campaign_water_tutorial_dialog_test.dart` | Final 3 pass: manual world spotlight drag, approach/text edits, stale target rejection, Cancel and shared Jump preview |
| `tools/editor` | `flutter test test/campaign_authoring_test.dart --plain-name 'mission deletion guards identity, selection, Save and history'` | Isolated 1 pass in 11 seconds, original timeout retained |
| Root | `dart run tool/generate_chunk_runtime_data.dart` then `--dry-run` | Generated and fresh; 166 chunk sources validated |
| Root | `dart run tool/localization.dart check` | English/French pass |
| Root | `corepack pnpm --dir functions build` | Pass; local TypeScript only |
| Root | `dart analyze` on the changed runtime, pipeline and test paths | Clean after one test-only brace lint correction |
| `tools/editor` | `dart analyze lib/src/app/pages/campaign test/campaign_authoring_test.dart test/campaign_water_tutorial_dialog_test.dart` | Clean |

Continuous runs use seed 42, catalog Éloïse, the actual authored mission and
committed fixed ticks. Route segments have finite 120–500-frame horizons; no
teleports, skipped chunks, changed geometry or inflated capabilities are used.
The bypass test walks to the rock's far side before jumping. Earlier pilot inputs
jumped too early or tried braking too late and entered the water; those were test
input errors, not a change to pool recoverability.

The new manual-drag test initially targeted the part of the preview clipped by
the fixed dialog footer. It now scrolls the pool into view and uses transformed
screen coordinates; no interaction assertion was removed. The existing mission
deletion test timed out under parallel load; its isolated rerun passes unchanged.
The first TypeScript build lacked sandbox access to existing generated output;
the authorized cache/output-access rerun passed. Temporary diagnostics were removed.

Inspected captures: `build/test/water_tutorial.png` and
`build/test/swimming_tutorial.png`. The veil highlights the water and actual Jump
button respectively, with readable cards inside the device frame.

Task diff and Markdown links were reviewed.

## Windows artifact

From `tools/editor`, `flutter build windows --release --no-pub` succeeded in
309.5 seconds after the user saved and closed the editor. The task's code/source
hashes stayed unchanged during the build.

- Executable: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
- Updated Dart payload: `data/app.so`, 16,958,344 bytes.
- Payload SHA-256: `00e952ed9bf21d580f207ee51d386f8eca7eff6e22a347ea38cdda4b363109e9`.
- Payload inspection confirms both lesson names and new trigger identities.

No phone hardware, physical monitor calibration, full mission completion,
performance benchmark or live backend deployment is claimed.
