# Terrain streaming performance

Historical September measurements and the October regression investigation use
Flutter 3.47.1 / Dart 3.13.1 and Android phone CPH2465. September phone captures
used profile mode; the October installed-app capture used debug mode. Workload
coverage is stated below. These are observed samples, not guaranteed limits.

## Cause and implementation

The original Forest stalls came from constructing both ground-enemy navigation
graphs synchronously when the active chunk selection changed. The captured
gameplay had 16 UI frames over 50 ms (118.757–337.400 ms); all 16 contained a
terrain transition and navigation graph construction. The worst frame's raster
work was only 4.363 ms. UI and raster durations must not be added together.

Interactive runs prepare exact upcoming candidates in a background Dart isolate
on native platforms, or in cooperative event-queue slices in browsers, and reuse
their immutable geometry, lookups, and navigation CSR data.
Publication retains the actual scheduler selection, geometry version, and tick
order. The first window is awaited during loading; refills and isolate handoff
are queued outside the current simulation/frame stack. Live and ghost runs own
separate bounded caches. See the [preparation contract](sloped_navigation_and_enemy_terrain.md#background-terrain-preparation).

## September automated phone comparison

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
need full-game frame profiling. That September implementation still used
synchronous construction on a miss. The live readiness boundary below now
removes that fallback; rendering, OS work and device throttling remain separate
sources of frame delays.

## October regression and preparation changes

The October 11 passive capture on the installed **debug** build used Forest seed
857469563. Across 7,928 active gameplay frames (165.291 wall-clock seconds,
9,254 sampled simulation ticks), all six UI frames above 500 ms coincided with
terrain-cache misses. UI durations were 2,256.127, 2,522.127, 2,618.193, 1,730.550,
1,449.962 and 1,061.220 ms; corresponding raster work was 5.250–10.296 ms.
There were 34 cache hits, six misses and no worker error. Two misses occurred
with no live enemies. These observations identify synchronous terrain fallback
as the source of the captured long stalls; they do not identify every possible
frame delay or the exact commit that first exhausted preparation headroom.

The old worker withheld all candidates until a batch finished. One observed gap
between ready-cache replenishments lasted 30.6 seconds. Preparation now dispatches
one nearest missing selection at a time, publishes each complete result
immediately, and re-reads the latest requested window before dispatching again.
Obsolete output is discarded. Disable/dispose rejects late output and prevents
new jobs. Runtime refills keep one job in flight with at most eight cached
selections. Startup now awaits the same full window using two native workers or
one cooperative browser lane; see the [startup audit](../verification/run_startup_2026-10-11.md).
Offline synchronous stepping
remains available; interactive misses now use the readiness boundary below.

Graph construction now uses per-build profile caches, bounded exact placement
memoization and lazy ordered landing candidates. Full trajectory and grounded
landing validation remain intact. Ten dense Forest selections across seeds 42
and 857469563 retained identical surface and graph signatures against the saved
original implementation, including all ten current enemy/NPC profiles. Desktop
JIT construction samples improved from 214.876–2,346.926 ms to 121.023–1,458.192 ms;
these samples include cold compilation and are not phone frame measurements.

The benchmark now shares GameCore's actor-profile factory, honors level tuning,
and uses the connected production selector. The historical September benchmark
omitted NPC profiles and used the authored source directly; its performance
numbers should not be treated as coverage of the current workload.

Browser preparation uses the same ordered graph work with a two-millisecond
cooperative scheduling budget between operations. MessageChannel events yield
to the browser event queue without nested-timer throttling; the budget is not
a hard bound on an individual geometry or trajectory operation. Native runs
retain background isolates. Browser validation also
exposed pre-existing `1 << 40` and `1 << 32` constants that truncate to zero in
JavaScript. Exact hexadecimal literals preserve the intended coordinate limit
and CORDIC full-turn scale without changing native values. Spatial grids also
use separate integer X/Y map lanes: the old 64-bit packing lost the Y lane in
JavaScript and merged unrelated rows. Hot lookups no longer allocate and hash
coordinate records. Immutable edge IDs cache a portable hash, and solid-fill
placement checks reject points outside cached polygon bounds before testing the
polygon loop. Seed mixing uses exact partial products, and graph profiles
normalize mirrored zero; native canonical surface/graph results remain the
reference for browser parity.

## Live terrain readiness boundary

Every live controller tick calls `GameCore.prepareNextTick()` before removing
queued input, applying commands or notifying the replay recorder. Core projects
the exact next selection from the current camera and stream cursors, including
encounter expiry and boss retention. This projection emits no spawns or events.
Unlike speculative lookahead, it covers skipped boundaries and retained chunks.

An exact cache hit is reserved for that tick. A miss prioritizes the required
selection ahead of speculative work and returns a future for that selection
alone. The currently running job can finish first; obsolete results are discarded.
A completed reservation survives a later speculative failure until consumed.
During live play one worker runs per preparer, with at most eight cached
candidates plus the single candidate reserved by Core. Catalog binding and
preparation dispatch remain outside the frame stack.

Calling the readiness API permanently enables Core's prepared-tick guard.
Live terrain replacement accepts only the reserved exact selection; it cannot
enter the synchronous builder. Initial Core construction and offline callers
that never enable prepared ticks retain synchronous construction. Native ghost
workers run off the UI isolate; cooperative browser ghosts admit each tick
before applying its recorded commands.

The controller exposes ready/preparing/failed host state independently of
gameplay pause. During a wait it retains queued input, holds the latest completed
snapshot, and stops the accumulator. Completion never steps Core or unpauses a
manual/lifecycle pause. The first frame spanning the wait is discarded, so time
spent waiting cannot produce a catch-up burst. Input releases can still update
the pending tick; replay frames are emitted once, only when that tick executes.
Ticks, score, combat clocks, RNG and publication order remain deterministic.

The UI keeps controls mounted and shows “Preparing the path…” during a wait.
A worker/admission failure or a 30-second required-selection timeout offers Retry
and the host's Exit action. Failure cancels held/pending controls through the
normal input router. Retry replaces preparation infrastructure in the same run,
with the same Core, ticket, recorder and next tick; it does not restart gameplay.
Pause and exit remain available. Shutdown, disposal and give-up fence pending
results. A disposed native job may finish but cannot publish into the closed or
replacement preparer.

## September gameplay capture discipline

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

## October browser validation

Post-change verification used desktop Chrome; the installed phone app was not
accessed or remeasured. Local release captures include all ten actor profiles and
the current compiled authored content. Loading is excluded from active frame
statistics. The measurement machine uses Windows, an AMD Ryzen 7 4800H
(8 cores / 16 threads), 16 GB RAM, and headless Chrome 155.0.8059.39 at
1440 × 900. The capture CLI runs on Node 24.16.0.

| Forest stress capture | Transitions / misses | Transition median / p95 / max | Active RAF max | Long tasks |
| --- | ---: | ---: | ---: | ---: |
| Seed 857469563, 90 s | 58 / 0 | 0.3 / 0.7 / 1.2 ms | 14 ms | 0 |
| Seed 857469563, 300 s | 198 / 0 | 0.399 / 0.701 / 1.899 ms | 27.8 ms | 0 |
| Seed 42, 300 s | 198 / 0 | 0.3 / 0.6 / 0.9 ms | 55.4 ms | 0 |
| Seed 857469563, 300 s repeat | 198 / 0 | 0.399 / 0.799 / 1.101 ms | 14 ms | 0 |

The 90-second capture completed in 90.0012 wall seconds with no discarded time,
no preparation or console errors, and no frame gap above 50 ms. Initial window
preparation took 5.699 seconds and the longest candidate took 2.016 seconds.
An intermediate browser build before the final spatial/hash optimizations had
31 misses in the same 58 transitions, a 3,652.5 ms maximum transition, and 32
frame gaps above 500 ms. The final nested integer grids, portable cached edge
hashes and polygon bounds rejection restored enough preparation throughput for
this sample. These are desktop browser observations, not phone timing claims.

The 300-second original-seed capture completed in 300.002 wall seconds with
zero discarded time, misses, frame gaps above 50 ms or reported errors. Its
initial window took 6.740 seconds; the longest candidate took 2.553 seconds.

The seed-42 capture also completed in 300.002 wall seconds with zero discarded
time, misses or errors. One animation-frame gap reached 55.4 ms; there was no
long task or gap above 500 ms. Initial preparation took 8.865 seconds and the
longest candidate took 2.334 seconds.

The original-seed repeat completed in 300.001 wall seconds with no discarded
time, misses or errors and saved all 198 transition rows. Initial preparation
took 6.115 seconds; the longest candidate took 2.545 seconds. The first two
300-second captures retain complete timing summaries but partial row exports
because of Flutter log throttling. The capture CLI now requires every declared
row before completing; the repeat verifies that correction.

Rendered gameplay used the normal assets, Core, controller and input path:

| Level / character / seed | Ticks | Distance (world units) | End | Terrain hits / misses |
| --- | ---: | ---: | --- | ---: |
| Forest / Eloise / 857469563 | 339 | 1,629.19 | Death | 2 / 0 |
| Forest / Eloise / 42 | 1,106 | 5,357.83 | Death | 8 / 0 |
| Field / Eloise / 42 | 2,700 | 12,098.17 | 45 s limit | 20 / 0 |
| new_level / Eloise / 42 | 2,699 | 12,164.96 | 45 s limit | 20 / 0 |
| Forest / Eloise WIP / 857469563 | 625 | 2,965.94 | Death | 4 / 0 |

Across 124.562 active wall seconds, all 54 terrain transitions were hits and no
preparation, console or runtime error was reported. Animation-frame median/p95
were 6.9/7.2 ms; maximum was 111 ms. The two long tasks (106 and 85 ms) began
5.6 and 159.2 ms after the first scene's ACTIVE marker. No later active long task
or frame gap above 500 ms was observed. These initial rendering hitches are
included in the results, not filtered out or attributed to terrain preparation.
The smoke attempts do not establish complete Forest or boss-combat coverage.
The separate scrolling benchmark uses a fixed 200 world units/second; it is not
an upper bound on camera motion under every ability or speed buff.

Focused regression validation passed in Chrome:

- 102 pipeline tests: exact RNG, spatial indexing/projectile queries, numeric
  bounds, cooperative scheduling, profile graphs, terrain publication and Core
  parity. This includes ten saved original native surface/graph signatures
  across seeds 42 and 857469563; all ten actor profiles are compared.
- 107 traversal and harness-control tests: full finite Forest assemblies for
  seeds 7/42/2026, the first 32 Field and new_level chunks, four mobile enemy
  families, hard-seam regressions, and clear/blocked/stall/death/budget controls.
  Arena-only bosses and full player/combat runs are outside this route matrix.
- 72 controller/input/replay tests: every sampled ghost tick/event, cooperative
  playback, preparation, cancellation, underruns and catch-up. The replay fixture
  now holds a charged ability to timeout so event transfer is exercised even
  when the authored opening has no enemies.
- Additional geometry identity/containment/placement and canonical-zero checks
  passed. Focused static analysis reported no issues; both release web
  entrypoints built successfully.

The Flutter test host returned 404 for its CanvasKit JavaScript/WASM assets.
The test session was supplied the matching local release-build assets through
DevTools request interception; SDK and application files were unchanged by that
workaround. Pure-Dart Chrome tests and release performance captures did not
require it. Temporary aggregation/baseline-proof sources, logs and captures are
retained locally under `.tmp/terrain-pipeline-fix`; they are not generated product
assets.

Earlier October checks found two existing enemy-terrain golden expectations
failing against the working-tree Bringer capsule changes.
The saved original graph implementation produced the same current signatures,
so those expectations were not regenerated as part of this performance change.
The focused browser suites above pass; this is not a claim that the entire
repository or all existing authored-content goldens passed.

## Readiness regression validation

The readiness change passed 44 Core Chrome tests covering exact selection
projection (including skipped boundaries and retention), encounter expiry,
required-job priority, timeout/disposal/failure, reservation preservation and
synchronous/cooperative publication parity. Another 81 focused Flutter Chrome
checks passed across controller input/recording, forced misses, pause, retry,
shutdown/disposal/give-up, cold cooperative ghost replay, buffering and the
runtime recovery overlay. Focused static analysis and a release browser build
also pass.

A broader route-startup fixture was attempted but is not passing evidence:
its browser image loading remained at `parallaxMounted`, before player
animations loaded, even after extended cooperative pumping. Supplying local
renderer/game assets did not resolve it. Its developer-profile case also uses
native filesystem storage and cannot run in Chrome. These fixture limitations
are separate from the passing readiness checks and the release captures; no
phone or native runtime tests were used. Logs and temporary browser entrypoints
are retained under `.tmp/terrain-readiness`.

### Release browser smoke captures for readiness

The built readiness artifact retains the eight-state startup warmup; concurrent
startup optimization edits in the shared working tree are excluded from this
feature commit and these captures. Five attempts cover Forest seeds 42 and
857469563, Field, `new_level`, and both characters.

| Capture | Published transitions | Cache misses / waits | Frames during waits | Preparation/runtime errors |
| --- | ---: | ---: | ---: | ---: |
| Normal warmup | 28 | 0 / 0 | 0 | 0 |
| Empty cache + 1,000 ms delay per job | 45 | 33 / 33 | 8,544 | 0 |

The delayed run covered 197.057 active wall seconds, including 85.221 seconds
waiting for preparation. Rendering continued during the waits; one Forest
attempt reached the 45-second harness limit with its final request still pending.
Controller regressions separately verify no tick/input/recorder mutation during
a wait, no catch-up on completion, and exact offline replay parity. Scripted
actions depend on rendered frames, so the two smoke captures do not represent
identical command tapes.

These are functional smoke results, not a clean performance comparison.
Concurrent startup builds/tests were observed in this workspace; an earlier
contended capture was discarded and the task's orphaned test browser was closed.
The delayed capture still recorded 14 long tasks and an 875 ms maximum RAF gap.
Eleven long tasks occurred in the first 2.3 seconds of the first scene; later
tasks included 54 ms and 70 ms samples. The normal capture recorded 22 long tasks
and a 10,812.1 ms maximum RAF gap despite zero preparation misses. This evidence
does not establish their cause or a frame-time guarantee. Keep the complete logs
and JSON under `.tmp/terrain-readiness`; a later isolated capture is needed for
reliable frame timing. No phone was accessed.

## Reproduction and validation

From the repository root:

```powershell
dart compile exe tool/benchmark_terrain_preparation.dart -o build/terrain_benchmark.exe
build/terrain_benchmark.exe --realtime --forest --seed=857469563 --seconds=300
```

Omit `--forest` to cover all compiled levels. Omit `--realtime` to await cache
refills between transitions and isolate publication cost. Phone measurements
use the checked-in Flutter entrypoint:

```powershell
flutter run --profile -d <device> -t tool/benchmark_terrain_preparation_app.dart --dart-define=TERRAIN_BENCHMARK_SEED=857469563 --dart-define=TERRAIN_BENCHMARK_SECONDS=300
```

Build and capture locally in Chrome without a phone or backend connection:

```powershell
flutter build web --release -t tool/benchmark_terrain_preparation_app.dart --output build/terrain-benchmark-web
node tool/capture_browser_benchmark.mjs build/terrain-benchmark-web .tmp/terrain-browser.json TERRAIN "seed=857469563&seconds=300"

flutter build web --release -t tool/benchmark_gameplay_app.dart --output build/gameplay-benchmark-web
node tool/capture_browser_benchmark.mjs build/gameplay-benchmark-web .tmp/gameplay-browser.json GAMEPLAY
node tool/capture_browser_benchmark.mjs build/gameplay-benchmark-web .tmp/gameplay-cold-terrain.json GAMEPLAY "coldTerrain=1&terrainDelayMs=1000"
```

The capture tool serves only on loopback, uses a fresh headless Chrome profile,
and exports JSON plus a screenshot after measurement. It waits for the declared
number of transition/attempt rows so Flutter log throttling cannot silently
truncate a long export. `CHROME_EXECUTABLE` can
select another Chrome installation. It records animation-frame gaps, long tasks,
and console/runtime errors; keep other compilation and test jobs idle during
performance captures. The terrain benchmark limits catch-up to 100 ms, matching
the controller, and reports actual wall duration plus discarded wall time. A
long stall cannot silently become unbounded synchronous catch-up.

The terrain entrypoint emits an ACTIVE marker after loading and exports tagged
summary/transition JSON only after the timed workload finishes. A progress indicator keeps Flutter frames active; this
is not world rendering. Restore the normal entrypoint for ordinary installs.
The gameplay entrypoint uses the normal Core, controller, semantic input router,
Flame scene and asset loading. Five autonomous attempts cover Forest seeds 42
and 857469563, Field, `new_level`, and both characters. Each ends at actual death
or 45 seconds; no immortality, teleporting or geometry changes are used. Report
ticks and distance reached, rather than claiming level completion or boss-combat
coverage. The optional cold-terrain capture skips startup cache warming only in
the benchmark controller and delays each preparation job; live stepping uses the
production controller. Rows report terrain waits, rendered frames while waiting,
wait duration and failures. This exercises responsive preparation misses even
when ordinary lookahead has enough headroom. Desktop results do not replace a later passive installed-app capture.

September validation included exact graph/geometry parity through complex Forest
selections, immutable record identity and substitution rejection, spawn/cull
boundary projections, cold/stale/disposed windows, speculative admission
failure, Core readiness changes, replay results, and controller shutdown.
The final navigation/preparation suite passed 86 tests, and the final Flutter
Core/Game/UI/controller suite passed 727 tests. Static analysis passed.

That September wider portable Core suite had five existing failures, reproduced
in an isolated copy of the unchanged revision: chunk-playtest draft terrain,
registered level-playtest progression, generated catalog expectations,
Forest long-run survival, and marker/pickup publication fixtures. They are
independent of enabling preparation; this change does not alter those fixtures
or regenerate authored content.
