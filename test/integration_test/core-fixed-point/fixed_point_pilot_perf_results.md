# Fixed-Point Pilot Perf Results

Date: 2026-02-16  
Status: Desktop harness complete, on-device profile benchmark validated on one target phone

## Environment

- OS: Windows 11 (Build 26200)
- Dart: 3.10.4 stable (`windows_x64`)
- Harness: `test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart`
- Runner: `test/integration_test/core-fixed-point/run-fixed-point-benchmark.ps1`

## Latest Desktop Run

Command:

```powershell
powershell -ExecutionPolicy Bypass -File test/integration_test/core-fixed-point/run-fixed-point-benchmark.ps1 -Runs 3 -WarmupTicks 250 -Ticks 3000 -SubpixelScale 1024 -MaxOverheadPct 10
```

Artifacts:

- `test/integration_test/core-fixed-point/perf/fixed_point_core_20260216-234815_no_track.json`
- `test/integration_test/core-fixed-point/perf/fixed_point_core_20260216-234815_no_track.txt`
- `test/integration_test/core-fixed-point/perf/fixed_point_core_20260216-234815_track_autoscroll.json`
- `test/integration_test/core-fixed-point/perf/fixed_point_core_20260216-234815_track_autoscroll.txt`

### Scenario A - No Track, No Autoscroll (strict gate)

- Baseline: mean `14.47us`, p95 `37us`, p99 `119us`
- Fixed-point: mean `6.93us`, p95 `15us`, p99 `38us`
- Overhead: `-52.08%` (passes `<= 10%` threshold)

### Scenario B - Track + Autoscroll (stress/representative)

- Baseline: mean `33.93us`, p95 `94us`, p99 `509us`
- Fixed-point: mean `12.54us`, p95 `22us`, p99 `231us`
- Overhead: `-63.03%` (informational run)
- Resets: `34` per mode (expected due run-end resets in long benchmark)

## Notes

- Desktop harness indicates no perf regression in current implementation.
- On-device profile benchmark target now runs via `flutter drive` and emits structured `BENCHMARK_SUMMARY::...` / `BENCHMARK_JSON::...` lines.
- Additional target phones are still recommended before removing the pilot flag.

## On-Device Profile Run (CPH2465 / `8ce90820`)

Command:

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=test/integration_test/core-fixed-point/core_fixed_point_benchmark_test.dart -d 8ce90820 --profile
```

Summary:

- Scenario A (no track, strict): baseline mean `9.07us`, fixed-point mean `8.72us`, overhead `-3.81%`
- Scenario B (track + autoscroll): baseline mean `15.70us`, fixed-point mean `16.41us`, overhead `4.54%`
