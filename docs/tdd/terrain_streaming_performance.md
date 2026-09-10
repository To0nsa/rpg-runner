# Terrain streaming performance

Measured on 2026-09-10 with Flutter 3.47.1 / Dart 3.13.1, Android phone
CPH2465, profile mode. These are observed samples, not guaranteed frame limits.

## Cause and implementation

The original Forest stalls came from constructing both ground-enemy navigation
graphs synchronously when the active chunk selection changed. The captured
gameplay had 16 UI frames over 50 ms (118.757–337.400 ms); all 16 contained a
terrain transition and navigation graph construction. The worst frame's raster
work was only 4.363 ms. UI and raster durations must not be added together.

Interactive runs now prepare exact upcoming candidates in a background Dart
isolate and reuse their immutable geometry, lookups, and navigation CSR data.
Publication retains the actual scheduler selection, geometry version, and tick
order. The first window is awaited during loading; refills and isolate handoff
are queued outside the current simulation/frame stack. Live and ghost runs own
separate bounded caches. See the [preparation contract](sloped_navigation_and_enemy_terrain.md#background-terrain-preparation).

## Automated phone comparison

Both traces use compiled Forest, seed 42, 60 simulated seconds, camera speed
200 world units/second, viewport width 600, and 38 post-initial transitions.
The final trace runs at real-time 60 Hz rather than waiting for each refill.

| Forest transition work on the main isolate | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Original synchronous construction | 195.991 ms | 348.253 ms | 455.349 ms |
| Final prepared publication + refill queuing | 1.706 ms | 5.614 ms | 6.614 ms |

All 38 final transitions were cache hits; no preparation error occurred.
The original worst selection at tick 2520 contains 172 navigation surfaces
and 2,482 edges across the two enemy graphs. Graph coverage is unchanged.
The final first-window preparation took 5.768 seconds in this phone sample;
this work occurs during loading and its duration depends on device conditions.

The benchmark does not simulate actors or render the world. Its final timed
section excludes deferred binding/handoff and background CPU; those still
need full-game frame profiling. A cache miss or unsupported/failed isolate
falls back to exact synchronous construction and can still stall. The fix
does not promise zero stalls from arbitrary camera jumps, rendering, OS work,
or device throttling.

## Gameplay capture discipline

Do not download CPU samples or large timeline payloads while the player is
running. In the first post-fix recording, `getCpuSamples` coincided with two
0.872/1.001-second waits between vsync and UI build start. The next CPU windows
sampled native formatting work in those intervals. These delays were outside
the UI build-duration field and were visible to the player despite a 15.320 ms
maximum UI build across the first 2,414 recorded frames.

Collect frame timings passively during play and transfer them after the run
ends. If CPU evidence is needed, retrieve it while paused. Inspect
`buildStart - vsyncStart` and consecutive vsync gaps as well as UI/raster work;
small build durations alone do not establish smooth gameplay.

The follow-up passive recording captured one complete 34.541-second Forest run
(seed 42, 2,072 simulation ticks, 2,067 recorded frames, 11 terrain transitions).
The player reported that this run felt smooth. UI build median/p95/maximum were
5.575/10.495/17.053 ms; terrain-transition UI builds peaked at 17.053 ms.
Maximum vsync-to-build delay was 7.532 ms and maximum consecutive vsync gap
was 33.385 ms. No UI build or same-run vsync gap exceeded 50 ms. Raster work
peaked at 21.333 ms. One UI build and seven raster frames exceeded 16.667 ms,
so this evidence supports removal of the large periodic stalls, not a promise
that every future frame will meet its refresh deadline.

## Reproduction and validation

From the repository root:

```powershell
dart compile exe tool/benchmark_terrain_preparation.dart -o build/terrain_benchmark.exe
build/terrain_benchmark.exe --realtime --forest
```

Omit `--forest` to cover all compiled levels. Omit `--realtime` to await cache
refills between transitions and isolate publication cost. Phone measurements
require compiling the benchmark into a Flutter profile entrypoint; desktop
numbers are not a substitute for phone frame timings.

Validation includes exact graph/geometry parity through complex Forest
selections, immutable record identity and substitution rejection, spawn/cull
boundary projections, cold/stale/disposed windows, speculative admission
failure, Core readiness changes, replay results, and controller shutdown.
The final navigation/preparation suite passed 86 tests, and the final Flutter
Core/Game/UI/controller suite passed 727 tests. Static analysis passed.

The wider portable Core suite has five existing failures, reproduced in an
isolated copy of the unchanged revision: chunk-playtest draft terrain,
registered level-playtest progression, generated catalog expectations,
Forest long-run survival, and marker/pickup publication fixtures. They are
independent of enabling preparation; this change does not alter those fixtures
or regenerate authored content.
