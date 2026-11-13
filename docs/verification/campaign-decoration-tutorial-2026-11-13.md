# Campaign decoration tutorial — local verification

Source: Reporting for Duty revision 39, catalog digest
`993493a822fc960b634e0435c2361b26fbc6e240d0963e09db3ec3ac760332b1`.
The authored delta is exactly one decoration lesson and one revision increment.
Generated Core changes retain prefab source keys as visual metadata, plus the
mission revision/digest; geometry, simulation and replay commands are unchanged.
Existing uncommitted work was preserved; this dependent change remains uncommitted.

## Delivered behavior

- After grounding beyond `mission_chunk_2` / `water_1` (right bank world X 984),
  the card explains pale, passable decorations versus solid obstacles.
- The spotlight follows `pixel_fantasy_caves_tree_02` through position, scale and
  rotation changes. Missing, solid, repeated or multi-sprite targets fail closed.
  The existing white tint is unchanged.
- Swimming and jumping across both reach the lesson. No airborne/swimming pause
  is introduced by this trigger. The optional swimming hint never blocks it.
- Fresh movement resumes with the same gesture; Jump cannot dismiss the card.
  No extra HUD is revealed. Pause/resume retains it; backtracking does not repeat
  it; restart resets progression.
- Campaign's existing panel, localization, water picker and manual spotlight
  canvas are reused. The new prefab picker uses captured compiled sprites.
  Edit/Undo/Redo, Save/reopen and frozen Play capture retain one owner.

## Checks

Commands used the installed Dart/Flutter SDK; Flutter tests used
`--no-pub --reporter expanded`. Logs are ignored under `build/decoration_*.log`.

| Working directory | Command / target | Result |
| --- | --- | --- |
| `packages/runner_content_pipeline` | `dart test test/campaign_decoration_tutorial_test.dart test/campaign_tutorial_test.dart test/campaign_source_test.dart --reporter expanded` | 21 pass |
| `packages/runner_content_pipeline` | `dart test test/chunk_runtime_materialization_test.dart --reporter expanded` | 14 pass; identity preserved through rotation, physics signatures unchanged |
| Root | `flutter test test/ui/tutorial/campaign_tutorial_controller_test.dart` | 3 pass; continuous swim and bypass/return |
| Root | `flutter test test/playtest/runner_chunk_playtest_host_test.dart --plain-name 'ordered tutorials'` | 4 pass; arrows, floating/fixed joystick, hidden-HUD keyboard |
| `tools/editor` | `flutter test test/campaign_water_tutorial_dialog_test.dart` | 6 pass; text/manual shape edits, missing/ambiguous references, Cancel, water/swim regressions |
| `tools/editor` | `flutter test test/campaign_authoring_test.dart --name '[Tt]utorial'` | 2 pass; actual Campaign tab, captured target, Apply/Undo, prelaunch dialog, Save/reopen/frozen capture |
| Root | `flutter test test/tool/generate_chunk_runtime_data_test.dart --plain-name 'generator writes authored runtime dart output'` | 1 pass |
| Root | `dart run tool/generate_chunk_runtime_data.dart` then `--dry-run` | Generated and fresh; 166 chunk sources |
| Root | `dart run tool/localization.dart check` | English/French pass |
| Root | `dart run packages/runner_core/tool/update_navigation_revision.dart --check` | Current; prepared navigation identity unchanged |
| Root | `corepack pnpm --dir functions build` | Local TypeScript pass |
| Root / `tools/editor` | Targeted `dart analyze` on changed production and test paths | Clean; final editor integration test analyzed again |

Continuous checks use the real mission, seed 42 and catalog Éloïse, with finite
120–500-frame segments. They walk from spawn, collect the coin, cross the rock,
swim or jump across the water, then walk through the tree to world X 1150.
No teleports, skipped chunks, geometry edits or inflated capabilities are used.
The bypass/return case proves the swim hint remains available after completing
decoration guidance. The host cases verify fresh movement and restart.

An initial host filter matched no tests and was corrected; it was not counted as
coverage. One test-only brace lint was fixed. The new Campaign-tab check initially
matched both the page and dialog's Apply buttons; its finder was scoped to the
dialog and the complete two-test slice passed. No product workaround or weakened
assertion was needed.

Inspected `build/test/decoration_tutorial.png`: the pale tree remains clear inside
the spotlight, the card is readable in the mobile frame, and only introduced HUD
features are present. Diff review confirms the source/generated delta above.

## Windows artifact

The user saved and closed the editor. `flutter build windows --release --no-pub`
from `tools/editor` passed in 221 seconds. Two shared UI dependencies changed
concurrently outside this task, so a final refresh was started to incorporate
them; tutorial production sources remained unchanged.

Final refresh passed in 147.8 seconds. The refreshed build's Dart/native source
inputs stayed unchanged, checked against its actual kernel dependency list.
Two further hub-only edits were outside the editor's dependencies. Payload
inspection confirms the decoration lesson, text and `waterCleared` trigger.

- Executable: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
- Dart payload: `data/app.so`, 16,974,728 bytes.
- SHA-256: `09dc74877d2bdf151de8e740be4fa67b4767138cd5a36cebf3e5a807bb32952f`.

Scoped diff/whitespace and documentation-link checks pass. The completed
[implementation checklist](../archive/2026-11-13/building/campaign_decoration_tutorial.md)
records the bounded scope.

No phone hardware, physical calibration, full mission completion, performance
benchmark or backend deployment is claimed.
