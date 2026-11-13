# Ordinary Campaign enemy activation — November 13, 2026

Implemented in the existing uncommitted worktree. Earlier and concurrent campaign,
Journal, tutorial, UI, content and migration work was preserved. The Windows editor
was rebuilt at the user's request; services, signing identities and rescue-encounter
participants were unchanged. See the
[implementation checklist](../building/campaign/implementation.md#ordinary-enemy-activation-november-13),
[gameplay](../gdd/campaign.md) and
[runtime contract](../tdd/campaign_runtime.md#ordinary-enemy-activation-and-pursuit).

## Delivered behavior

- Ordinary marker actors exist from loading and wait at resolved homes. Approach
  within 280 world units from either direction, or positive surviving HP loss,
  engages them without a spawn or a position reset.
- **Return when player retreats** defaults on. Beyond 600 units from home, the
  enemy disengages and returns through normal navigation/physics. Positive damage
  refreshes two seconds of retaliation. Disabling the per-marker switch retains
  mission-wide pursuit after engagement, with no local territory restriction.
- Waiting/returning actors remain visible and vulnerable. Existing health,
  regeneration, cooldowns, statuses, released attacks and defeat persist. Derf
  transforms on Campaign engagement; dormant Hashash cannot evade into an ambush.
- The switch survives strict decoding, canonical encoding, marker moves/copies,
  Undo/Redo, Save/reopen, compilation, captured Play and generated Core catalogs.
  Stable mission chunk IDs and salts bind policy to the correct actor.

## Local checks

Commands used Dart 3.13.1 from
`C:/Users/Toonsa/flutter/bin/cache/dart-sdk/bin/dart.exe` (`dart` below).
Flutter tests used that executable with
`C:/Users/Toonsa/flutter/bin/cache/flutter_tools.snapshot --suppress-analytics`
(`flutter` below), with SDK-cache access. Dependency files were already resolved;
no dependency or lockfile changes were needed. Logs and an isolated pre-task Core
copy are retained under ignored `.tmp/campaign_enemy_task/`.

| Working directory | Command / scope | Result |
| --- | --- | --- |
| `packages/runner_core` | `dart --suppress-analytics analyze lib test/campaign test/test_support/level_enemy_traversal.dart test/fixtures/level_traversal_finish_fixture.dart` | No issues |
| `packages/runner_content_pipeline` | `dart --suppress-analytics analyze lib test/campaign_placement_source_test.dart` | No issues |
| `tools/editor` | `dart --suppress-analytics analyze lib/src/campaign/campaign_marker_edit.dart lib/src/app/pages/campaign/campaign_marker_inspector.dart test/campaign_marker_edit_test.dart test/campaign_authoring_test.dart` | No issues |
| Repository root | `dart --suppress-analytics run tool/generate_chunk_runtime_data.dart`, then `--dry-run` | Generated policy projection; 166 chunks validated, no blocking drift |
| Repository root | `dart --suppress-analytics run packages/runner_core/tool/update_navigation_revision.dart --check` | Existing navigation algorithm revision remains current |
| `packages/runner_core` | `dart --suppress-analytics test test/campaign test/enemies/derf_transformation_test.dart test/combat/derf_running_target_test.dart test/ecs/terrain_enemy_navigation_system_test.dart test/ecs/enemy_swimming_test.dart test/ecs/flying_enemy_terrain_locomotion_test.dart test/ecs/flying_enemy_melee_test.dart test/encounters test/bosses/boss_arena_test.dart --reporter expanded` | 425 passed; two inherited failures below |
| `packages/runner_core` | `dart --suppress-analytics test test/navigation/level_enemy_traversal_test.dart test/navigation/level_enemy_traversal_harness_test.dart --reporter expanded` | 86 passed |
| Repository root | `flutter test --no-pub test/core` | All 525 passed |
| `packages/runner_core` | `dart --suppress-analytics test test/campaign test/ecs/terrain_enemy_navigation_system_test.dart test/ecs/enemy_swimming_test.dart --reporter expanded` | All 63 passed after final preservation of the original non-Campaign swimming target selection |
| `packages/runner_content_pipeline` | `dart --suppress-analytics test test/campaign_placement_source_test.dart test/campaign_source_test.dart --reporter expanded` | All 26 passed |
| `tools/editor` | `flutter test --no-pub test/campaign_marker_edit_test.dart` | All three passed |
| `tools/editor` | `flutter test --no-pub test/campaign_authoring_test.dart --plain-name 'enemy return switch'` | Passed Undo/Redo, Save and reopen |
| `services/replay_validator` | `dart --suppress-analytics test test/replay_simulation_test.dart test/npc_section_guard_replay_test.dart test/bounty_hunter_replay_test.dart --reporter expanded` | All 48 passed |
| Repository root | `flutter test --no-pub test/tool/generate_chunk_runtime_data_test.dart --plain-name 'campaign generates a trusted finite registry and replays the real worker at 30 and 120 Hz'` | Passed non-default pursuit projection, generated compilation, freshness and real worker parity |
| Repository root | `git diff --check` | Passed |

The new tests cover all four ordinary enemy identities, damage wake through a
real player projectile, deterministic replay of a command stream, continuous
ground/flying returns, both return/follow policies, 30/60/90 Hz timing, destruction
and ID reuse. Physical return controls cross a real 600-unit seam after a 32-unit
jumpable obstacle and return the same actor without teleporting. The shared
traversal harness now exposes its existing movement phase for these controls.

The production traversal matrix retains Forest/Field seeds 7, 42 and 2026, the
complete first Forest assembly and the first 32 Field chunks, real catalog
capabilities, fixed route boundaries and existing blocked/clear controls. Already
transformed Derf is used for movement; separate tests cover its transformation.

## Windows editor rebuild

At the user's request, built the existing uncommitted working tree based on
`69a250be8abf`, including ordinary enemy activation and its return/follow switch.
From `tools/editor`, ran `flutter build windows --release --no-pub` using the
direct Flutter tool snapshot described above. The build passed in 193.0 seconds
on November 13, 2026. Log: `.tmp/campaign_enemy_task/editor-release-build.log`.

Output: `tools/editor/build/windows/x64/runner/Release/runner_editor.exe` with
its adjacent runtime files. The incremental build reused the native runner;
`data/app.so` was updated at 22:51:18 Europe/Helsinki (17,138,568 bytes), SHA-256
`b401426c1490318edcbf22d7deb3ec758de628f1e5022dc4ed3b673aecb9e749`.
The application was not launched for a visual smoke check.

## Inherited failures and limits

Two combat checks fail identically in an isolated pre-task Core copy and the
changed tree. No baselines or assertions were relaxed:

- `test/encounters/ai_target_system_test.dart`, **ground engagement and committed
  melee share the selected actor**: expected a non-null committed ability.
- `test/encounters/ordinary_combat_baseline_test.dart`: expected trace digest
  `5994421a39566e2bd3f63fe6f4533bce398a8e9b5dd6955e579c2c28deabcf81`, actual
  `0b1ac845386776ebab20caeaa122af6eb4745b8fc83f401a39c204ac4e802671` in both
  copies, ending at tick 939 with the same four enemy identities.

The isolated copy uses captured pre-edit versions of changed files and HEAD
versions of previously unmodified files, with its own package configuration;
the active checkout was never rolled back. The initial whole-package analyzer
also reports existing `dart:mirrors` errors in the unrelated VM parity test;
changed source and tests pass the scoped analysis above.

An extra isolated `forest_rocky_grove_easy_001` route at seed 42 exposes blocked
Grojib/Hashash outward paths and a blocked Derf return path. These are preserved
as explicit blocked controls beside the successful obstacle/seam return checks.
They are not the production selector's multi-chunk itinerary. Unoco completes
the isolated rocky round trip. Unreachable paths never grant teleportation or
count as arriving home. This change does not repair arbitrary authored terrain.

The first editor widget run passed its assertions but encountered the existing
preview-image handle race during temporary-fixture cleanup. Releasing preview
I/O after unmount, using the neighboring test's pattern, produced a clean pass.
No live device, installed-editor visual smoke or performance measurement is
claimed. A matching client/worker Core must be used on the next authorized release.
