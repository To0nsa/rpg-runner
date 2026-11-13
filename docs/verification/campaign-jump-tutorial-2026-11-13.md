# Campaign obstacle / Jump tutorial — 2026-11-13

Local Windows implementation on the existing dirty workspace. This adds one
three-step sequence to Reporting for Duty revision 37, attached to `mission_chunk_2`.
The sequence explains the rock, reveals Jump, then reveals health/ability/stamina
bars. Next advances the first two pages while paused; a fresh Jump finishes the
third and dispatches the actual Core command. English/French text and all three
spotlights are editable together. Current contracts: [tutorials](../tdd/campaign_tutorials.md)
and [campaign behavior](../gdd/campaign.md).

## Source and generation

Generated freshness was verified before runtime traversal. The task baseline had
source revision 36 ahead of generated revision 32. Regeneration therefore also
synchronized existing authored spawn x=240 and coin x=504, instead of stale
generated x=272/456. This feature changed no authored marker, chunk geometry,
Core jump/stamina tuning or replay encoding. The shared generated content digest is
`e7b6e4c69892c90c27069e018691fa488792ef0bf67464375d8e41777ff08e05`.
No server deployment or account mutation was performed.

## Validation

Commands use `C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe` and Flutter's
cached `flutter_tools.snapshot`. Test concurrency was limited to two. Logs are local
`build/jump_tutorial_*.log`; captures are under `build/test/`.

| Directory | Command / check | Result |
| --- | --- | --- |
| Root | `dart --packages=.dart_tool/package_config.json tool/generate_chunk_runtime_data.dart`, then `--dry-run` | Generated catalogs and verified no drift. |
| Root | `dart --packages=.dart_tool/package_config.json tool/localization.dart generate`, then `check` | English/French generated output current. |
| `packages/runner_content_pipeline` | `dart test test/campaign_tutorial_test.dart test/campaign_source_test.dart --concurrency=2` | 15 passed. Strict three-step schema, immutability, route attachment and invalid reference checks. |
| Root | `flutter test test/ui/tutorial test/ui/input/desktop/runner_desktop_input_adapter_test.dart test/ui/runner_game_widget_startup_test.dart --no-pub --concurrency=2` | 34 passed, including continuous traversal past the rock. |
| Root | `flutter test test/ui/tutorial/movement_tutorial_overlay_test.dart test/ui/runner_game_widget_startup_test.dart --name 'Campaign coin\|projection\|three-step' --no-pub --concurrency=2` | 3 passed after adding camera projection, French 2× text with reachable Next, and recorded product Jump coverage. |
| Root | `flutter test test/ui/controls/runner_controls_overlay_radial_test.dart test/ui/hud/game/resource_bar_test.dart test/playtest/runner_chunk_playtest_host_test.dart --no-pub --concurrency=2` | 54 passed. Includes four tutorial input variants, normal controls, shield, device sizing, focus, pause, rapid restart and disposal. |
| `tools/editor` | `flutter test test/campaign_tutorial_dialog_test.dart --no-pub --concurrency=2` | 6 passed. All three pages, independent spotlight edits, invalid hidden translation, nonfinite draft preview and Cancel. |
| `tools/editor` | `flutter test test/campaign_authoring_test.dart --no-pub --concurrency=2` | 27 passed. |
| `tools/editor` | Same authoring file, `--plain-name 'tutorial edits survive Undo' --concurrency=1` | 1 passed after explicitly adding the three-step sequence to frozen capture/Undo/Save/reopen coverage. |
| Root | `flutter test test/tool/generate_chunk_runtime_data_test.dart --plain-name 'campaign generates a trusted finite registry' --no-pub --concurrency=1` | 1 passed; generated catalog parity and existing replay-worker fixture at 30/120 Hz. |
| Root | Resource/Play tests, `--name 'resource\|shield can be held\|ordered tutorials.*arrows' --concurrency=2` | 4 passed after preserving controller-keyed resource animation reset beneath the stable spotlight target. |
| Root / `tools/editor` | Targeted `dart analyze` on changed runtime, pipeline, editor and regression files | No issues; final resource wrapper check recorded separately. |
| Root | Play/tutorial tests, `--name 'ordered tutorials.*arrows\|three-step French' --no-pub --concurrency=2` | 2 passed after the final character-neutral resource wording; captures refreshed and reviewed. |
| Root | `corepack pnpm --dir functions build` | Passed local TypeScript build with regenerated catalog. |

The final wording identifies the middle ability bar by position, since Willow uses
gold supplies and Éloïse uses blue mana. Final regeneration, no-drift verification
and the Functions build passed after that copy change.

The schema/source tests initially exposed synthetic fixtures that replace the
entire route but retained a production chunk-bound lesson. Those fixtures now
explicitly omit production tutorial sequences; strict reference validation was
retained. A test-selection command using a literal name for a regex ran no tests;
it was corrected to `--name` and the three intended tests passed.

## Traversal and input evidence

Reporting for Duty, seed 42, catalog Éloïse, real authored terrain. The controller
regression retains continuous actor state from spawn, practices backward into the
existing obstacle and reverses, collects the real coin, then advances to x≥600.
Budgets: 120 ticks per practice direction, up to 300 ticks to the coin, a further
240 single-frame iterations to chunk two and 500 to cross the rock at x≥870.
No teleporting, skipped chunks, altered terrain, threshold widening or synthetic
stamina subtraction. Before Jump, paused tick and stamina remain unchanged.
After a fresh Jump, stamina decreases and vertical velocity is upward; ordinary
movement/jumps cross the actual rock before the subsequent gap.

The Play host exercises arrows, floating joystick, fixed joystick and hidden-HUD
keyboard input. Next is clicked as a UI action. Early Jump, movement on the final
page, existing holds and key repeats cannot dismiss the sequence. Pause/calibration
suspension retains its step; restart restores initial movement-only guidance.
The product host records exactly one pressed-command frame for the final Jump and
preserves step 2 through mobile background/resume. Existing injected asset-failure
logs are expected assertions in successful lifecycle regression tests.

`jump_obstacle_tutorial.png`, `jump_button_tutorial.png` and
`jump_resources_tutorial.png` were visually reviewed: the existing rock, actual Jump
button and real resource panel align with their openings. The tutorial card and
controls stay inside the selected phone frame. This is automated/widget evidence;
no full-route, physical-phone, monitor calibration or web acceptance is claimed.

## Windows artifact

From `tools/editor`, `flutter build windows --release --no-pub` passed on the
frozen final source in 313.2 seconds (`build/jump_tutorial_windows_verified.log`).
Earlier successful builds (302.2 and 676.5 seconds) were superseded after the
resource reset/copy refinements. No further source changes occurred during this
final build; the source hashes below still match.

Entry point: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
Final `data/app.so`: 16,941,960 bytes; SHA-256
`2996b55f700ed357680b7287faca08c69c36945702eb7b5cabc8f9745a732870`. Its compiled strings include the final character-neutral preset wording,
with the replaced wording absent. Editor Campaign Play reads the repository's
captured authored source. Reopen an already running editor to load this payload.

## Tested source identity

SHA-256 of task source and regression inputs (including preserved unrelated edits
within those files):

```text
f884dcdbe920873421f2f9cdf6fe771633c38671db46802fb19795eb94c2aee7  tools/editor/lib/src/app/pages/campaign/campaign_page.dart
0fff6449a1e3b5cc5ffa000ef3a606794e9c70dbdf881e97c8b9bea2a2f5fcd2  tools/editor/lib/src/app/pages/campaign/campaign_tutorial_dialog.dart
6766a0c163c0d670af4f727d458245facaca129521eaf963b5506065dc5d3f29  tools/editor/lib/src/app/pages/campaign/campaign_tutorial_sequences.dart
b87de310f8249b76acfcf017696d5388138667ba10c199e4cea882109fce0fae  tools/editor/lib/src/app/pages/campaign/campaign_tutorial_spotlight_canvas.dart
c7a100a5e1194512f6d585c3f2567ebfbdef873f3b7399a868ac1931180e2ecd  packages/runner_content_pipeline/lib/campaign_tutorial.dart
6e014a4ccdcba0a7e95759d6bde13d0a71a2f58727b18e25100004310c542ae0  packages/runner_content_pipeline/lib/src/campaign_source.dart
1075cb8f940cc6144f9301b8e305b78237abed952029515b95c5b2319c9bc0a3  lib/playtest/runner_playtest_host.dart
763ea1c7c16fbc3d9bdac1b6dc584e579c02f8efbc6473851b0f53f825ddba31  lib/playtest/runner_playtest_session.dart
8adb6c5f1044e94cab6bbd1985ff997951187b99e84d5061836e0f5cef6594de  lib/ui/runner_game_widget.dart
7764ae0f1789729c8285b58ff812e2a5fbbd1b366e64d28956dbdbffd9d7b23d  lib/ui/controls/runner_controls_overlay_radial.dart
7fc05418e9f648b5da491da7aee288b6871d2df6d32e977bd581c9f9a4b700c8  lib/ui/input/runner_gameplay_bindings.dart
0da47b4b23c8ff1bfaba4b1bf44bc36028654e7c242944d6530468df22dc091a  lib/ui/tutorial/campaign_tutorial_controller.dart
a275edc44f2e24b28770d1e547dab22381bd327a6a5cfeecaaf3a6667e504bbb  lib/ui/tutorial/campaign_tutorial_overlay.dart
7e749a84a82bcf9552399f84e0a5325af293147cb11e7334aef98837bf951579  lib/ui/input/desktop/runner_desktop_input_adapter.dart
0ca5df3714102417b7a280073a5ffe5a106c138afa827a5db9a334819c372217  lib/ui/hud/game/game_overlay.dart
f50487fa2b74218f1848c883be83f6b73614d520c7acd5c3e0677af88dd779c6  lib/ui/hud/game/top_left_hud_overlay.dart
a43015435026ff511cf2934d0b14a525cb316bd2be67ca47d6f4cef8e76e409c  packages/runner_content_pipeline/lib/src/campaign_jump_tutorial.dart
8c866c9e51905c1f22a28fb927df499628602a3807ad30eaa0f4b634255405f7  lib/ui/tutorial/campaign_tutorial_geometry.dart
42ac557b959bdb658d463c3e84508b852b772cc59ca747102bd57ea292fa3cc2  lib/ui/controls/run_controls_tuning.dart
2bae4a7e1b871fac086bb0e5a6e896538ae2b50ece796f1b393d96c549242513  lib/ui/controls/widgets/jump_control.dart
50c58301e599205e73177bb098f8b744da3a5ead1fc507094c6ed2c4f4bf996f  lib/ui/hud/game/resource_bars_panel.dart
cdefd23864762803f1109faa359e90243de3e15c42b9eb7f8bab21a742942fe7  tools/editor/lib/src/app/pages/campaign/campaign_jump_tutorial_dialog.dart
b9b3d8b8a4b871b644adea213b5ddf6917dd418b438cdf2e73e223d2ce61264d  assets/authoring/campaign/chapter_defs.json
8bba747c87f3d8c80aa770cb93e06bfe45c49de40676bd09a6d6c4a6a07e111b  lib/ui/campaign/generated_campaign_catalog.dart
8c74316ad9e0d0023a7f0833eab6c2d83bc6b822acf45cb4dfd76838b31c3847  packages/runner_core/lib/campaign/campaign_registry.dart
beecab94348d18973071008461ac0d9c6d6817040c8e7bfba0fe32e41d3cb8e3  functions/src/campaign/generated_catalog.ts
794267e0f170040c0dfc27ab1d080c046f681c30e3f5d1721a1a45329fe04655  packages/runner_content_pipeline/test/campaign_tutorial_test.dart
34def7045974a8d7bedbc7ad0eb5e568d76459f7c90e9e87e015f12b758ac973  packages/runner_content_pipeline/test/campaign_source_test.dart
4c369b0fa32443ec229768365fce45edd6afe91a773623ada5284d579e9b9c83  test/ui/tutorial/campaign_tutorial_controller_test.dart
73bcce145c1e092babe34de3bd434608b661044569bc56d9477cf62098bd73c1  test/ui/tutorial/movement_tutorial_overlay_test.dart
53339587745f8277476af2392b1626f9dc5ad15da720f44893c3dcebfabe1354  test/ui/runner_game_widget_startup_test.dart
a080942ad1911c0618ff6e3a8d00f41141cb2b63d58e4452ff01f2fdc1ae8b63  test/playtest/runner_chunk_playtest_host_test.dart
9725beb0709982a679235ce1d115121593fe4be802824ad846931073a0cef2b5  tools/editor/test/campaign_tutorial_dialog_test.dart
5eaf5f40247b5ea2e480897c23bd370f158b226cd167c3f35845b2dce5167475  tools/editor/test/campaign_authoring_test.dart
f14a2d8bfd48f251b44dde36681e92bf39f9116b98bdb7b9a2ba797607033aee  test/tool/generate_chunk_runtime_data_test.dart
```
