# Integration Test Backlog (Other Targets)

Date: 2026-02-17  
Owner: Core + Game

## Purpose

List high-value integration tests to add beyond the fixed-point benchmark, with
clear pass criteria and suggested target files under `test/integration_test/other/`.

## How To Run

Use the same driver pattern as current integration tests:

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=test/integration_test/other/<target_file>.dart -d <deviceId> --profile
```

For correctness-only runs (no perf data), `--profile` can be omitted.

## Priority 1 (Add First)

### 1) Long-Run Determinism Replay (On Device)

- Suggested file: `test/integration_test/other/core_determinism_replay_test.dart`
- Goal: validate same-seed/same-command-stream snapshots are identical over long runs.
- Scenario:
  - instantiate two `GameCore` instances with same seed/tuning
  - feed identical command stream for 10k-20k ticks
  - compare key snapshot fields each N ticks and final snapshot
- Pass criteria:
  - no mismatch in deterministic fields
  - no unexpected run-end divergence

### 2) Pause/Resume Stability (No Catch-Up Explosion)

- Suggested file: `test/integration_test/other/core_pause_resume_stability_test.dart`
- Goal: ensure lifecycle pause/resume does not cause huge tick catch-up or state jumps.
- Scenario:
  - run for a short window
  - simulate pause gap
  - resume and continue
  - track tick progression and camera/player continuity
- Pass criteria:
  - bounded post-resume tick advancement
  - no teleport-like camera/player discontinuity

### 3) Track Streaming + Cull Integrity Soak

- Suggested file: `test/integration_test/other/track_streaming_soak_test.dart`
- Goal: validate spawn/cull behavior and geometry consistency under long autoscroll.
- Scenario:
  - run with `trackEnabled=true`, autoscroll enabled
  - run 8k-15k ticks
  - periodically inspect geometry/snapshot counts
- Pass criteria:
  - no unbounded growth in streamed geometry/entity counts
  - no invalid geometry ranges
  - no crashes/assertions

## Priority 2

### 4) Combat Throughput Stress (Projectiles + Hitboxes)

- Suggested file: `test/integration_test/other/combat_throughput_stress_test.dart`
- Goal: validate stability under dense combat interactions.
- Scenario:
  - scripted periodic jump/dash + attack commands
  - enable enemy spawns and projectile-heavy paths
  - run in profile and capture summary timings
- Pass criteria:
  - no missed-hit anomalies (obvious regressions)
  - no runaway entity counts
  - stable tick cost envelope

### 5) Level Switch Reset Contract

- Suggested file: `test/integration_test/other/level_switch_reset_contract_test.dart`
- Goal: verify level changes reset deterministic runtime state correctly.
- Scenario:
  - run on level A, then recreate/run level B, then A again
  - compare baseline fields (camera defaults, ground defaults, distance reset, runId behavior)
- Pass criteria:
  - no leaked state across level transitions
  - level-authored defaults are respected each time

### 6) Camera Contract E2E (LockY vs Follow)

- Suggested file: `test/integration_test/other/camera_contract_e2e_test.dart`
- Goal: validate camera behavior modes in integration context (not unit only).
- Scenario:
  - mode A: `lockY`, force player Y changes
  - mode B: `followPlayer`, force player Y changes
- Pass criteria:
  - `lockY` keeps camera Y fixed at authored default
  - `followPlayer` converges as tuned

## Priority 3

### 7) Input Routing End-to-End (UI -> Commands -> Core)

- Suggested file: `test/integration_test/other/input_routing_e2e_test.dart`
- Goal: verify touch/control input reaches Core with expected command timing.
- Scenario:
  - launch game route
  - simulate button/touch gestures for move/jump/dash/attack
  - assert resulting snapshot state transitions
- Pass criteria:
  - expected command effects appear within expected tick windows
  - no stuck-input/latch regressions

### 8) Theme/Asset Wiring Smoke (Per Level)

- Suggested file: `test/integration_test/other/theme_asset_smoke_test.dart`
- Goal: catch missing render wiring/assets per level/theme.
- Scenario:
  - boot each supported level/theme combination
  - advance a short run window
  - assert no missing-registry fallback failures
- Pass criteria:
  - no missing animation/asset errors in logs
  - run starts and advances without render exceptions

## Reporting Pattern (Recommended)

For profile/stress tests, emit one-line and JSON markers similar to benchmark:

- `IT_SUMMARY::<scenario> ...`
- `IT_JSON::<payload>`

This keeps collection automation consistent with:

- `test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart`

## Suggested Rollout

1. Add Priority 1 tests first and stabilize.
2. Add Priority 2 tests after first pass is green.
3. Add Priority 3 when UI flow and theme matrix are stable enough.
