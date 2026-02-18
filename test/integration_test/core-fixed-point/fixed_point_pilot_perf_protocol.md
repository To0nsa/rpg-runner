# Fixed-Point Pilot Perf Protocol

Date: 2026-02-16  
Owner: Core/Simulation

## Purpose

Define a repeatable process for deciding whether fixed-point pilot can move from optional to default.

## Benchmark Harness

- Script: `test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart`
- Convenience runner: `test/integration_test/core-fixed-point/run-fixed-point-benchmark.ps1`
- On-device integration target: `test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart`
- Driver entrypoint: `test_driver/integration_test.dart`
- Run (default):  
  `dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart`
- Run (longer sample):  
  `dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart --runs=8 --ticks=8000`
- Strict gate mode (non-zero exit when overhead exceeds threshold):  
  `dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart --strict --max-overhead-pct=10`
- Emit JSON artifact:  
  `dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart --json-out=test/integration_test/core-fixed-point/perf/latest.json`
- One-command benchmark pack (JSON + text outputs):  
  `powershell -ExecutionPolicy Bypass -File test/integration_test/core-fixed-point/run-fixed-point-benchmark.ps1`
- On-device profile run (example device id):  
  `flutter drive --driver=test_driver/integration_test.dart --target=test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart -d 8ce90820 --profile`

## What It Measures

- Per-tick Core `stepOneTick()` cost (microseconds) for:
  - baseline floating-point path
  - fixed-point pilot path (`PhysicsTuning.fixedPointPilot.enabled = true`)
- Reported stats:
  - mean
  - p95
  - p99
  - pilot overhead %
  - JSON artifact for checkpoint history

## Parity Gates

- Determinism parity (pilot mode):
  - same seed + same commands => same snapshots/events
  - validated in `test/core/fixed_point_pilot_test.dart`
- Behavioral parity (pilot vs baseline):
  - trajectory drift remains within authored tolerances
  - run-end behavior is unchanged for parity scenarios

## Perf Gates

- Default threshold:
  - pilot mean tick overhead <= 10%
- Release readiness:
  - no sustained frame-budget misses on target devices in profile mode.

## Device Validation

After desktop harness passes:

1. Run the integration benchmark in profile mode on target devices:
   `flutter drive --driver=test_driver/integration_test.dart --target=test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart -d <deviceId> --profile`
2. Play representative scenarios for 5-10 minutes.
3. Confirm no new hitching/jank relative to baseline.
4. Capture `BENCHMARK_SUMMARY::...` and `BENCHMARK_JSON::...` lines from drive logs.
5. Attach benchmark output and profile notes to the phase checkpoint.

Use artifact directory: `test/integration_test/core-fixed-point/perf/`
and summarize in: `test/integration_test/core-fixed-point/fixed_point_pilot_perf_results.md`

## Rollback

If parity or perf fails:

- Keep pilot optional (`enabled = false` in shipping tuning).
- Continue iteration behind the same tuning flag.
