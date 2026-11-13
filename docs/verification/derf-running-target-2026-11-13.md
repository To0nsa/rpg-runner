# Derf running-target correction

Local working-tree verification on November 13, 2026. No deployment or device
playtest was performed.

Transformed Derf stopped at maximum tentacle reach before its windup. Engagement
now reserves the selected target's outward travel during the scaled windup and
shares that shorter commit/stop distance with locomotion. Strike geometry,
timing, damage and cooldown are unchanged.

## Regression

[`derf_running_target_test.dart`](../../packages/runner_core/test/combat/derf_running_target_test.dart)
uses full Core with authored spawn markers and flat polygon ground. Seed 7,
both playable characters, both horizontal directions, and 30/60/120 Hz cover
24 running/stationary cases. Each has a ten-second horizon and observes real
transformation, pursuit, strike animation and player health loss. Input remains
continuous; neither actor is teleported. Extended retention/grace margins keep
runner scrolling from ending the leftward combat fixture.

With the original engagement implementation restored temporarily, the rightward
60 Hz Éloïse running case fails to take damage. All 24 pass with the correction.
The corrected source was restored and hash-checked after this comparison.

## Checks

| Directory | Command | Result |
| --- | --- | --- |
| Root | `flutter pub get` | Passed; checked-in lockfile unchanged |
| Root | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | Passed |
| `packages/runner_core` | `dart analyze lib/ecs/systems/enemy_engagement_system.dart lib/ecs/stores/enemies/engagement_intent_store.dart test/combat/derf_running_target_test.dart` | No issues |
| `packages/runner_core` | `dart test test/combat/derf_running_target_test.dart test/combat/grojib_melee_spacing_test.dart test/enemies/derf_transformation_test.dart test/ecs/derf_terrain_placement_test.dart` | 147 passed |
| `packages/runner_core` | `dart test` | 2,934 passed; two existing failures described below |
| Root | `flutter test --no-pub test/core/enemy_engagement_system_test.dart test/core/enemy_attacks_test.dart test/core/combat_pose_alignment_test.dart test/core/ground_enemy_melee_facing_lock_test.dart test/core/command_scheduling_test.dart test/core/determinism_test.dart test/core/fixed_point_pilot_test.dart` | 157 passed |
| `services/replay_validator` | `dart test test/replay_simulation_test.dart test/validator_worker_test.dart` | 112 passed; one skipped |

The package run includes passing traversal and harness controls: Forest's complete
non-looping assembly with Unoco, Grojib, Hashash and already-transformed Derf;
Field's first 32 selected chunks with Unoco; seeds 7, 42 and 2026, plus retained
exact-route regressions. Actors continuously cross the actual finish boundaries.
These pursuit checks do not establish Field ground-enemy traversal, every seed,
rendering, camera behavior, performance or a complete player run.

Both package failures reproduce with the original engagement code:
`ai_target_system_test.dart` places its Grojib target at 12 units, inside the
existing 34-unit minimum; `ordinary_combat_baseline_test.dart` already has a stale
trace checksum. The correction changes that trace further, as expected for
changed pursuit. Neither existing fixture was edited. Full package analysis
also reports five errors in the pre-existing untracked
`test/playtest/campaign_construction_parity_test.dart` around `dart:mirrors`.

Sandboxed Dart commands stalled; completed checks used the installed Dart/Flutter
toolchain outside the sandbox. Logs remain in the ignored `.tmp/` directory.
Online release needs matching client and replay-worker Core artifacts through
the coordinated gameplay compatibility release workflow.
