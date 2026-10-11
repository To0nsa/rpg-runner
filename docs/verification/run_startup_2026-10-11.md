# Run startup audit and optimization — 2026-10-11

Status: implemented and verified locally and on the connected Android phone.
No backend/Hosting deployment was performed.
The source worktree includes existing authored Forest changes. Measurements use
that local content, not a claim about the currently deployed catalog.

## Findings and delivered changes

| Stage | Finding | Delivered change |
| --- | --- | --- |
| App bootstrap | Profile and canonical ownership reads were serialized after authentication. | Start both reads after the existing auth/flush barrier; publish only after both succeed. |
| Preparing run | Starting while the exact ticket prefetch was pending could issue a second request. Repeated warmups could replace a usable ticket. | Join the exact in-flight request, consume a matching valid ticket once, and skip redundant warmups. Failed/expired prefetch still permits foreground issuance. |
| Prefetch lifetime | A late result could repopulate a cache after invalidation when the reconstructed key matched again. | Fence publication by request identity as well as user, revision, mode, level, character, loadout and compatibility. Recheck selection/session after waiting. |
| Building level | Registries ran concurrently, but each registry decoded its own sources sequentially. Player/prefab mounting waited on unrelated work. | A run-owned manifest preloader deduplicates sources and bounds catalog reads at eight. Registries build from their existing image cache; player/prefab mounting overlaps the rest of the scene. |
| Terrain startup | Building eight complete future terrain states dominated Forest loading. Native candidates were independent but serialized. | Two native workers prepare the same eight states. Browsers retain one cooperative lane. Runtime refill remains one worker per simulation. |
| Loading feedback | The generic level message concealed the remaining terrain wait. | Separate art, ghost, terrain and recorder labels, plus overlapping per-task wall timings in the renderer and benchmark. |

Authentication, pending ownership synchronization, authoritative restart reads,
ticket expiry, single consumption, recorder initialization and required render
readiness remain enforced. Selected ghost retrieval still belongs to preflight.
Ghost playback preparation remains optional and run-owned. No wire contract,
gameplay rule, terrain geometry, navigation capability or replay ordering changed.

The architecture is described in [run startup](../tdd/run_startup.md). Asset
requirements stay in registries. Core owns exact terrain selection; Flame owns
image lifetime; the run session combines world and recorder readiness. The new
preloader is local to one run and does not create a persistent global cache.

## Native terrain measurements

Windows desktop, Dart 3.13.1 AOT, Eloise, no other build/profile running during
the capture. Each scenario ran serial, parallel, parallel, serial in one process.
Both modes prepared all eight identical selection states at tick zero. Times
below measure terrain preparation only, excluding Core construction, Flutter,
authentication, image loading, ghost playback and recorder I/O.

| Level / seed | Serial samples (ms) | Two-worker samples (ms) | Mean reduction |
| --- | --- | --- | --- |
| Forest / 42 | 2472, 3293 | 1966, 1969 | 32% |
| Forest / 857469563 | 2425, 2570 | 1626, 1712 | 33% |
| Field / 42 | 63, 54 | 41, 35 | 35% |

This is a small local comparison, not a statistical benchmark or an Android
loading-time guarantee. Two simultaneous native builds may use more peak memory;
concurrency is fixed at two per simulation rather than scaled to desktop CPU
count. Live and ghost simulations own separate preparers. Browser preparation
has no native isolates and intentionally retains one cooperative lane.

Reproduce from the repository root with builds and other profilers idle:

~~~powershell
dart compile exe tool/benchmark_run_startup.dart -o .tmp/run-startup.exe
& ./.tmp/run-startup.exe
~~~

The benchmark fails if startup does not finish at tick zero with eight ready
states and no worker error. It emits constructor and terrain timings separately.

## Connected phone diagnosis

The connected CPH2465 (Android 15, SM6375) was initially running an older debug APK in Developer
Practice. The updated normal app was installed over it without clearing app data.
Opt-in startup markers captured the actual hub-to-run and restart paths; a run
was started and played to its natural gap death. Developer Practice makes no
backend ticket request and opens no replay recorder.

| Debug app path | Preflight | Core/controller construction | Scene | Terrain | Local ready |
| --- | --- | --- | --- | --- | --- |
| First run, seed 677668716 | 16 ms | 3394 ms | 951 ms | 6489 ms | 10063 ms |
| Restart, seed 474047557 | 0.47 ms | 514 ms | 477 ms | 5230 ms | 5793 ms |

Scene and terrain overlap. Local ready starts at session construction; preflight
is separate. These seeds differ, and debug mode includes JIT/cold-code overhead:
the drop on restart is not a controlled estimate of the optimization's benefit.
The first run's construction delay also occurs before the first world milestone.

For the controlled comparison, the same phone ran the real Core, controller,
Flame renderer and asset catalogs in a native profile APK, with fixed tick-stamped
input, Eloise, and Forest seeds 857469563 and 42. The planned order per seed was
serial, parallel, parallel, serial; each attempt owned a fresh Core and image
cache. Seed 857469563 completed all four passes and seed 42 completed its first
serial/parallel pair before the device locked. Debug hitbox
overlays were disabled in this standalone benchmark. It excludes authentication,
recorder I/O, route transitions and app-shell startup.

| Forest seed | Serial world-ready samples | Two-worker world-ready samples | Mean reduction |
| --- | --- | --- | --- |
| 857469563 | 4356, 3748 ms | 2576, 2625 ms | 36% |
| 42 | 4589 ms | 2937 ms | 36% (one pair) |

Terrain preparation itself averaged 3784 → 2352 ms for seed 857469563 and
4439 → 2788 ms for seed 42, a 37–38% reduction. Profile construction ranged from
138–286 ms. Scene loading ranged from 366–787 ms and overlapped terrain. The
first serial run also had a colder process/asset path; the reverse-order serial
repeat remains visible in the table rather than being discarded.

All six completed passes started with eight prepared states, ended naturally,
and had zero terrain waits, zero misses and no preparation errors. Seed 857469563
ended at tick 1086 / distance 3779.4736328125, with seven geometry versions and
six terrain hits in every pass. Seed 42 ended at tick 784 / distance
2565.849609375, with five geometry versions and four hits in both passes.
Those are finite gameplay samples ending in death, not complete-level coverage.
The device reported thermal status 0 before and after capture; it was USB powered.
No CPU/timeline payload was downloaded during play. Profile measurements came
from the device while unrelated validation/build commands ran on the host PC.

The capture timed out after the phone auto-locked during its seventh attempt.
Only the six completed pre-lock passes above are evidence; the two outstanding
repeats are not claimed as completed. Unlock was requested, but was unavailable
before the handoff. The normal instrumented debug app was reinstalled, preserving
app data, and the original keep-awake setting (0) was restored. No post-suspension
measurement contributes to the table.

Reproduce the actual app markers with:

~~~powershell
flutter build apk --debug --target-platform android-arm64 --no-pub --dart-define=RUN_STARTUP_TRACE=true
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -W -n com.example.rpg_runner/.MainActivity
adb logcat -v raw -s flutter
~~~

Launch through the hub and retain only RUN_STARTUP_TRACE lines. Do not infer
remote timings from Developer Practice. The diagnostics also cover ownership,
auth, joined prefetch, foreground ticket creation, restart canonical reads and
recorder opening when an online run actually exercises those paths.

For the controlled native comparison, put the following in a temporary JSON
Dart define file (a file avoids shell interpretation of ampersands on Windows):

~~~json
{"BENCHMARK_OPTIONS":"level=forest&character=eloise&scriptedInput=1&compareWarmup=1"}
~~~

~~~powershell
flutter build apk --profile --target-platform android-arm64 --no-pub -t tool/benchmark_gameplay_app.dart --dart-define-from-file=.tmp/phone-benchmark.json
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb shell am force-stop com.example.rpg_runner
adb shell am start -W -n com.example.rpg_runner/.MainActivity
adb logcat -v raw -s flutter
~~~

Retain the eight GAMEPLAY_BENCHMARK_ROW records. Keep the phone awake and unlocked;
record and restore any temporary keep-awake setting. Installing the benchmark
replaces this local package's executable, so reinstall the normal app APK after
measurement. App data does not need to be cleared.

## Browser experiment and retained startup headroom

An early probe of the existing eight-state path took approximately 8.2–10.5 s to
prepare Forest runs in desktop headless Chrome. Terrain preparation was the
critical path. That initial multi-scenario smoke used frame-driven inputs; it is
not suitable for comparing later gameplay stalls across scheduling changes.

A subsequent controlled experiment used a fixed, tick-stamped command tape for
Forest seed 42 / Eloise. Both modes used the same build and content. The smaller
window was an experiment and is absent from the final implementation.

| Experiment | Time to world-ready | Later terrain wait | Outcome |
| --- | --- | --- | --- |
| Full eight-state control | 8277 ms | none | death at tick 784, distance 2565.849609375 |
| Rejected four-state gate | 4217 ms | 3459 ms at tick 752 | identical tick, distance and death |

Both runs decoded 98 images and observed five terrain geometry versions. The
full control spent 7737 ms on terrain and 718 ms on scene preparation; these
phases overlap. Reducing startup work moved a substantial wait into gameplay,
so the final implementation preserves the full eight-state gate. A two-state
prototype was also removed. No partial-window optimization is shipped.

The final release-web build took 8729 ms to world-ready (8038 ms terrain,
838 ms scene, 633 ms constructor), with eight prepared states and 98 images.
The same fixed tape again ended at tick 784 / distance 2565.849609375, with five
geometry versions, four cache hits, zero misses, zero terrain waits and no
preparation failures. Captured active frames had a 14 ms p95 and 160 ms maximum,
with no frame above 500 ms. This confirms the retained gate and browser wiring;
it does not establish a browser loading speedup over the earlier control.

Reproduce the final browser scenario against a local release build:

~~~powershell
flutter build web --release --no-pub --no-wasm-dry-run --target tool/benchmark_gameplay_app.dart --output build/run-startup-benchmark
node tool/capture_browser_benchmark.mjs build/run-startup-benchmark .tmp/run-startup-browser.json GAMEPLAY 'level=forest&seed=42&character=eloise&scriptedInput=1'
~~~

The benchmark supports level/seed/character filters, fixed input, constructor and
world-ready timing, task timings, decoded-image count and terrain waits. The
optional fullWarmup=1 control uses serial full-window preparation; coldTerrain=1
remains the existing no-warmup diagnostic. Those controls are tooling only.

## Validation

- 29 Core tests passed: startup readiness and bounded concurrency, failure while a
  sibling is pending, disposal, seeded gameplay parity through terrain transitions,
  exact prepared Forest publications for seeds 42 and 857469563, stale selections,
  live required reservations, and worker failure controls.
- 62 focused Flutter tests passed on the final implementation: run-session and
  widget readiness/retry/exit, controller input, ghost playback/source lifecycle,
  terrain/prefab rendering order, and asset-preloader overlap/failure/cancellation.
- 58 remote/bootstrap/account/asset tests passed before the final native-only
  scheduler refinement, including in-flight ticket reuse, invalidation, expiry,
  selection changes, independent consumers, atomic bootstrap failure and outbox
  synchronization. These overlap the final Flutter group; counts are not additive.
- Generated-content freshness passed with 83 chunk files, three level definitions,
  three parallax themes and three terrain materials. No content was regenerated
  as part of this change.
- Targeted Dart analysis passed with no issues. A further 42 focused startup,
  readiness/recovery and ticket tests passed with device tracing enabled.
- The release-web benchmark compiled successfully, including cooperative
  browser startup scheduling. Native profile and normal instrumented debug APKs
  also compiled, installed and launched on the connected phone.

## Remaining costs and limits

Forest graph construction still dominates browser startup. Initial Core
construction also remains synchronous. Asset loading is overlapped, but this
capture does not isolate its speedup from renderer/browser variation. The phone
comparison confirms faster local readiness on one device; it does not measure
live Firebase latency, cold Function instances, selected-ghost download, recorder
I/O, peak memory or a full level. Debug app observations must not be reported as
release performance. The fixed browser tape ends at
its actual death at tick 784; it is not a traversal or complete-level assertion.

Authentication already coalesces shared work and can reuse its token. Existing
backend timing logs and deployment configuration support separate server-latency
investigation. No production configuration, min-instance count or deployment was
changed without device/server evidence. Further browser terrain speedups need to
reduce construction cost while preserving exact candidate output; simply moving
preparation past Start failed the controlled comparison above.
