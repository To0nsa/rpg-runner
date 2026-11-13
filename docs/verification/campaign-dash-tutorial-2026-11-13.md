# Campaign Dash introduction — local verification

Reporting for Duty revision **44** adds one bilingual Mobility: Dash card at
`mission_chunk_8`, local X **522** (world X **4722**), near the bush beyond the
pool and before the downhill ninth chunk. A fresh Mobility press or Shift resumes
and performs the real dash. The control remains available afterward. There is no
additional objective or confirmation popup.

## Source and review

- Authored delta against the task-start snapshot: exactly one appended tutorial
  and mission revision 43 → 44. Other missions, markers, route and geometry match.
- Campaign digest: `83eb4014bde1ba59079945aab44b2377f492677ef90fe3e050f5cd4458369b34`.
- Generated UI and Functions metadata include the lesson; Core only changes its
  generated catalog digest. Core simulation and generated terrain match the task
  baseline byte for byte. No replay command, ability tuning or objective change.
- The shared controller waits for grounded, dry, affordable, valid, cooled-down,
  unlocked Dash. Alternative non-dash builds retain their actual skill and reveal
  its control without Dash-specific instructions. The shared tap control preserves
  Jump and Mobility layout/feedback; editor and runtime use the same widget.
- Existing uncommitted tutorials and unrelated Town/assets/docs were preserved.
  Task comparison is in ignored `build/dash_tutorial_baseline/` and
  `build/dash_review.diff`. A separate commit would omit required uncommitted
  framework dependencies, so this change remains uncommitted.

## Focused checks

**75 distinct tests pass** across the final focused checks below.

Commands use the installed Flutter SDK. `flutter` below means its
`bin/cache/dart-sdk/bin/dart.exe bin/cache/flutter_tools.snapshot` entry point;
`dart` means the same SDK's Dart executable. Checks are local, not deployed.

| Working directory | Command / test selection | Coverage |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_mobility_tutorial_test.dart test/campaign_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 23 passing: strict bilingual contract, mandatory reveal, ordered lessons, disabled stale chunk rejection, source compilation |
| Root | `flutter test --no-pub test/ui/tutorial/campaign_mobility_tutorial_test.dart test/ui/tutorial/movement_tutorial_overlay_test.dart --concurrency=1 --reporter expanded` | 18 passing: readiness policy fixtures and French compact/enlarged-text cards |
| Root | `flutter test --no-pub test/playtest/runner_chunk_playtest_host_test.dart --plain-name 'ordered tutorials reach dash after swimming: MovementControlMode.arrows' --concurrency=1 --reporter expanded` | 1 passing: actual route and mobile dash press |
| Root | `flutter test --no-pub test/playtest/runner_chunk_playtest_host_test.dart test/ui/tutorial/campaign_tutorial_controller_test.dart --name 'ordered tutorials.*(joystick\|fixedJoystick\|null)\|continuous tutorials\|unmet swimming' --concurrency=1 --reporter expanded` | 7 passing: other three control variants and four existing continuous tutorial regressions |
| Root | `flutter test --no-pub test/ui/controls/runner_controls_overlay_radial_test.dart --concurrency=1 --reporter expanded` | 24 passing: tap/hold/directional modes, cooldown and follow-up, resource blocks, layout and callback edges |
| `tools/editor` | `flutter test --no-pub test/campaign_tutorial_dialog_test.dart --plain-name 'dash authors' --reporter expanded` | 1 passing: trigger validation, bilingual text, real spotlight drag, Apply and Cancel |
| `tools/editor` | `flutter test --no-pub test/campaign_tutorial_dialog_test.dart test/campaign_authoring_test.dart --name 'dash\|tutorial edits' --concurrency=1 --reporter expanded` | Persistence test passes: Undo/Redo, Save/reload and frozen Play capture. The initial dialog fixture failed and passed separately after correcting its scrolled gesture target. |

Initial test harness failures (inferred fake snapshot types, stale renamed getter,
duplicate variable and a literal instead of regex filter) were corrected. No
runtime expectation, terrain or traversal tolerance was weakened.

Scoped root/editor analysis, generated freshness, English/French localization,
Functions TypeScript compilation and task whitespace/document links are checked.
Commands: `dart analyze <changed paths>`; `dart run
tool/generate_chunk_runtime_data.dart --dry-run`; `dart run tool/localization.dart
check`; `corepack pnpm --dir functions build`. Logs remain in `build/dash_*.log`.

## Traversal and visual evidence

The actual host tests use Reporting for Duty, seed **42**, catalog Éloïse at 60 Hz,
continuous state from the authored spawn, ordinary controls and finite walk/jump
budgets. They complete prior guidance, land on the blessing basin, clear its
statue, cross the next pool via its two platforms, pause at X 4722–4727, dash and
continue to X ≥4900 across the actual eighth/ninth chunk seam. There is no
teleportation, skipped chunk or changed collision. No enemies are authored here.

All four presentations exercise the same lesson: arrows, fixed joystick, floating
joystick and HUD-off keyboard. Pre-held Shift/repeat, Jump and movement cannot
dismiss it. The admitted press produces high horizontal velocity and a real
stamina reduction. Restart hides Mobility again. Snapshot policy fixtures cover
water, flight, position, stamina, cooldown, invalid slot, stun/dash lock,
pause/resume and repeat suppression; those fixtures are not traversal evidence.

Reviewed `build/test/dash_tutorial.png`: legible card, grey veil, clear Mobility
button and visible pool/bush/downhill context in the fitted mobile preview.
This is widget-rendered evidence. Native visual acceptance, phone/ruler checks,
full-mission completion, performance and backend deployment are not claimed.

## Windows artifact

`flutter build windows --release --no-pub` from `tools/editor` succeeded in
**218.3 seconds**. All **2417** captured source hashes and the final source
inventory match the build input manifest. The editor was closed for replacement.

Executable: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
Payload `data/app.so`: **17,073,032 bytes**, SHA-256
`c804b7416aba65bc1cc835ca27b9c3c2466e84c756dae5bde10574256b36d51c`.
Source/artifact manifests: `build/dash_windows_sources.json` and
`build/dash_windows_artifact.json`. The executable has not been launched for a
native visual check; the reviewed screenshot came from the widget playtest.
