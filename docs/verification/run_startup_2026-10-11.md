# Run startup audit and optimization — 2026-10-11

Status: implemented and locally verified; no deployment or phone measurement.
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
- Targeted Dart analysis passed with no issues.
- The final release-web benchmark compiled successfully, including cooperative
  browser startup scheduling.

## Remaining costs and limits

Forest graph construction still dominates browser startup. Initial Core
construction also remains synchronous. Asset loading is overlapped, but this
capture does not isolate its speedup from renderer/browser variation. No live
Firebase latency, cold Function instance, selected-ghost download, low-end device,
peak-memory or full-run comparison was measured. The fixed browser tape ends at
its actual death at tick 784; it is not a traversal or complete-level assertion.

Authentication already coalesces shared work and can reuse its token. Existing
backend timing logs and deployment configuration support separate server-latency
investigation. No production configuration, min-instance count or deployment was
changed without device/server evidence. Further browser terrain speedups need to
reduce construction cost while preserving exact candidate output; simply moving
preparation past Start failed the controlled comparison above.
