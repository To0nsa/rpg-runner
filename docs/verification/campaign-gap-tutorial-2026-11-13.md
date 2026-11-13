# Campaign gap tutorial verification — 2026-11-13

Local source: Reporting for Duty revision 40, content digest
`c18f758264f876aec8fa0fc1fe700a7d59dc26f26020ae19155d7ca9e114417a`.
Task baseline and final diff were compared independently of the existing dirty
checkout. Authored JSON changed by exactly one lesson and one revision increment.
Generated Core changed only its content digest; UI/Functions also gained the
lesson and revision. Terrain, physics, navigation and replay commands are unchanged.

## Behavior and checks

The real third chunk has dry ledges at X 1421/1490, Y 224. The default warning
pauses grounded at X 1325–1330, after walking through the decoration. Movement
dismissal keeps the player grounded; jumping near X 1395 spends ordinary stamina
and lands on the far bank. Walking into the same opening without jumping fails.
An alternate authored 20-unit warning plus a jump near X 1390 exercises an early
airborne bypass: no midair/late popup and no blocked lesson queue.

All 44 targeted tests passed locally:

| Directory | Command | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_gap_tutorial_test.dart test/campaign_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 26: strict bilingual schema; moved/removed banks; disabled references; wet/filled/uneven/one-way controls; existing tutorial/source regression |
| Root | `flutter test test/ui/tutorial/campaign_tutorial_controller_test.dart --no-pub --reporter expanded` | 4: continuous authored spawn → coin → obstacle → water → decoration → gap; successful jump, swim bypass/return and dry-gap fall control; optional hint scheduling |
| Root | `flutter test test/playtest/runner_chunk_playtest_host_test.dart --plain-name 'ordered tutorials' --no-pub --reporter expanded` | 4: arrows, floating joystick, fixed joystick and hidden-HUD keyboard; real crossing, fresh input, paused clocks, unchanged HUD and restart |
| `tools/editor` | `flutter test test/campaign_water_tutorial_dialog_test.dart --no-pub --reporter expanded` | 8: bilingual text, distance validation, manual spotlight, missing targets, Cancel and shared water/decoration/swim regression |
| `tools/editor` | `flutter test test/campaign_authoring_test.dart --name '[Tt]utorial' --no-pub --reporter expanded` | 2: actual Tutorial sequences tab, compiled gap choices, Apply/Undo, launch settings, Save/reopen and immutable captured Play |

Editor integration initially ran together with the dialog tests using the filter
`gap|water|decoration|swimming|[Tt]utorial` (10 passes). The dialog-only rerun covers
the final shared validation wording; the Save/capture path was unchanged.
The controller tests use seed 42 and catalog Éloïse with normal input and continuous
actor state. Each segment has a finite frame budget; crossing reaches X ≥1510
and lands grounded beyond the real X1490 boundary. This is the first three chunks,
not full-mission, enemy, performance or every-character traversal acceptance.

Focused root and editor analysis pass. `dart run tool/generate_chunk_runtime_data.dart
--dry-run` validates 166 chunks and current outputs. `dart run tool/localization.dart
check` passes for English/French. `corepack pnpm --dir functions build` passes.
Scoped diff whitespace and documentation link checks pass. Existing navigation
evidence is reused because no geometry, navigation input or algorithm changed.

Reviewed `build/test/gap_tutorial.png`: readable card above the character, grey
overlay, ellipse across the opening and both ledges, existing mobile HUD and a
safe grounded approach. This is a widget screenshot, not a physical device check.

Development failures were resolved: initial target validation incorrectly required
an entire exposed top edge; real terrain splits it around the far rock, so validation
now checks the actual two ledges. A too-early jump at X1318 failed physically;
the supported crossing uses normal edge timing, and bypass coverage uses the
explicit alternate warning distance. A missing test import and style lints were
fixed. A source-edit helper encoding failure was restored from the captured task
baseline before further editing; no unrelated work was overwritten.

## Windows artifact and limits

`flutter build windows --release --no-pub` from `tools/editor` succeeded in
170.0 seconds. Ready executable:
`tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
Its `data/app.so` is 17,007,496 bytes with SHA-256
`eceed75b9fff98414c42c6c9459942996b0202ac870263f2e5fe7dfbcab08c6c`.
Build-source hashes remained unchanged; the final payload contains the gap lesson,
trigger and title. No deployment or live backend calls were performed.
No native executable launch, phone test or physical ruler calibration is claimed.
The target selector intentionally supports flat dry gaps between direct rectangular
ground banks in one chunk; more complex terrain requires a future bounded extension.
The task remains uncommitted alongside its pre-existing uncommitted dependencies.
