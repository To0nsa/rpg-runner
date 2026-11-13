# Campaign objective card and practice timing — 2026-11-13

Local Windows follow-up to the [objective tutorial implementation](../archive/2026-11-13/building/campaign_objective_tutorial.md), on the existing dirty working tree at `c1059c7d`. Unrelated work was preserved. No Core, authored mission geometry, campaign digest, protocol or backend changes belong to this follow-up.

## Behavior

- Objectives are introduced after three metres of cumulative horizontal walking, in either direction. Idle time, pauses and holding against an obstacle do not advance practice.
- The shared game/editor `HudPanel` shows only `Collect a coin 0/1`, then `Collect a coin 1/1` with a green success check for the coin-only mission.
- Completion holds for three seconds of committed gameplay and fades over 250 ms. Pauses retain the acknowledgement; restart resets it. Removing the card does not clear Core objective progress. Other mission goals remain visible.
- The same stateless panel renders the authoring spotlight preview without expiring during editing. English and French use a typed localized progress value.

Implemented contracts: [tutorials](../tdd/campaign_tutorials.md), [campaign runtime](../tdd/campaign_runtime.md), [campaign behavior](../gdd/campaign.md).

## Local validation

Commands below use the installed Flutter SDK (`C:/Users/Toonsa/flutter`); Flutter commands were invoked through its cached `flutter_tools.snapshot`, and Dart commands through `bin/cache/dart-sdk/bin/dart.exe`.

| Working directory | Command / check | Result |
| --- | --- | --- |
| Repository root | `flutter test test/ui/campaign/campaign_hud_test.dart test/ui/tutorial/campaign_tutorial_controller_test.dart test/playtest/runner_chunk_playtest_host_test.dart test/ui/runner_game_widget_startup_test.dart --no-pub --concurrency=2 --reporter expanded` | 40 passed; one reverse-walk test initially assumed an unobstructed path behind spawn. See diagnosis below. |
| Repository root | `flutter test test/ui/tutorial/campaign_tutorial_controller_test.dart test/ui/campaign/campaign_hud_test.dart --no-pub --concurrency=2 --reporter expanded` | All 4 passed after correcting that test and adding a disposal check. Runtime implementation unchanged from the preceding batch. |
| `tools/editor` | `flutter test test/campaign_tutorial_dialog_test.dart --no-pub --concurrency=2 --reporter expanded` | All 5 passed. |
| Repository root | `dart analyze lib/ui/campaign/campaign_hud.dart lib/ui/tutorial/campaign_tutorial_controller.dart test/ui/campaign/campaign_hud_test.dart test/ui/tutorial/campaign_tutorial_controller_test.dart test/ui/runner_game_widget_startup_test.dart test/playtest/runner_chunk_playtest_host_test.dart` | No issues. |
| `tools/editor` | `dart analyze lib/src/app/pages/campaign/campaign_tutorial_dialog.dart lib/src/app/pages/campaign/campaign_tutorial_sequences.dart` | No issues. |
| Repository root | `dart --packages=.dart_tool/package_config.json tool/localization.dart generate`, then `check` | Generated output current; English/French check passed. Existing unrelated translations preserved. |
| `tools/editor` | `flutter build windows --release --no-pub` | Passed, 434.7 seconds. Refreshed the release bundle with its rebuilt Dart payload; unchanged native shell reused. |

The reverse-walk trace showed the real obstacle behind the authored spawn stops movement before three metres. The retained regression now measures accepted terrain travel, holds against that obstacle without triggering, reverses direction, and reaches the objective lesson after sufficient cumulative travel. It then continues to the real first coin. Reporting for Duty, seed 42, catalog Éloïse; finite 120-tick left/right budgets and a further 300-tick coin horizon. No teleport, geometry edits or threshold reduction were used.

The combined passing coverage includes the product startup/lifecycle path, arrows, fixed/floating joystick, hidden-HUD keyboard Play, fresh-input gating, restart/disposal, completion during a pause, fading/removal, French at enlarged text size, and mixed-goal preservation. Generated widget captures `build/test/objectives_tutorial.png` and `build/test/first_coin_tutorial.png` were visually reviewed for the shared card, spotlight alignment and completed checkmark.

Local logs are under `build/objective_card_*`. These are automated/widget checks, not physical-phone acceptance. Full Core/replay suites and full-route traversal were not rerun for this presentation-only follow-up. Existing physical calibration behavior was not changed or revalidated.

Release entry point: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`. The updated `data/app.so` has SHA-256 `bd67a643b69865aede3844f3b029d9e3450a4a2f8cfc8c3f219fce5be69594cd` (16,876,424 bytes). An already running editor needs reopening to load this payload.

## Tested source identity

SHA-256 values of the final behavior and regression inputs:

```text
a187dacbee168535e1ad05d9db959429bb7ec2633b6837f2ca7b64f51264bac5  lib/ui/tutorial/campaign_tutorial_controller.dart
10604144e94e15a98b33107daff05d91e5947b7372743c2d01b0c54c4831d698  lib/ui/campaign/campaign_hud.dart
5d9fda7d2b3bbe1042ed9a58a7f273f98f4a4cf96bcea75b3e4e6f1a4829cf8e  test/ui/tutorial/campaign_tutorial_controller_test.dart
a75027c80172beaf3e648d041e64c055a94b5a1a940871ee41d77cc56c9451f3  test/ui/campaign/campaign_hud_test.dart
d6f21cbda464c29c2fa1d5cb7be63a22f7bf699afe1d0a7db2b5671e58aa27ca  test/ui/runner_game_widget_startup_test.dart
0db63623c917a0e07291bf51c7e8fa90a1a4da8f75280970c8c4d84d38a6d5f8  test/playtest/runner_chunk_playtest_host_test.dart
d634a9556176d9bc81d4eb8673e7689b663cd7b9465dac2468460674b142abcc  tools/editor/test/campaign_tutorial_dialog_test.dart
```

## Horizontal centering follow-up

The shared `GameOverlay` now centres the campaign card across the game display,
independently of the side HUD panels. Its full content remains part of the measured
HUD bounds used by offscreen indicators. The editor authoring canvas already used
display-wide centering and needs no separate implementation.

From the root, `dart analyze lib/ui/hud/game/game_overlay.dart` passed. Existing
`flutter test test/playtest/runner_chunk_playtest_host_test.dart --plain-name
'objectives then coin reveal HUD with fresh movement' --no-pub --concurrency=2
--reporter expanded` passed all four control variants. The refreshed objective and
first-coin captures were visually reviewed: both cards are centred at the same
display midpoint, including after the checkmark and counters appear. Logs:
`build/objective_center_analysis.log` and `build/objective_center_tests.log`.
Tested `lib/ui/hud/game/game_overlay.dart` SHA-256:
`d702f8dfa3a83b508c750dac842cf72fbb69e0c8c48f07ccd26867b35995d570`.

The editor's `flutter build windows --release --no-pub` passed in 149.8 seconds
(`tools/editor`; log `build/objective_center_windows.log`). Its updated release
`data/app.so` SHA-256 is
`dd617d928c208ea3b870b9816c49a9c6e9b610857e4319493fac3fd33c6a8d41`,
superseding the earlier payload above. Reopen the editor to load this build.
