# Ghost performance changes — 2026-10-03

## Delivered behavior

- One immutable publication carries adjacent Core frames and events. Each event
  batch is consumed once; attachment reads the current frame and late animation
  loads cannot restore a cleared/replaced ghost.
- Ghost sprite outlines use a shared 16 MiB LRU texture cache. Warm frames use
  two draws (cached outline plus tinted sprite) instead of nine offset/sprite
  draws. Source frames remain owned by the normal image cache.
- Ghost player/enemy/NPC/projectile views are culled against the live camera using
  conservative visual bounds. Projectile age survives view retirement/re-entry.
  Offscreen impacts are not spawned, and existing effects age offscreen without
  drawing. Clearing a ghost also removes its effects.
- Core projects only actors/projectiles for ghost playback. Every replay tick
  and event still executes; each advancement builds at most two compact frames.
  Completion freezes the interpolation pair at the actual terminal pose.

## Verification

Targeted Flutter tests passed for replay playback (8), ghost layer (7), sprite
outline cache (2), sprite tint (3), NPC rendering (1), HUD input snapshots (6),
and camera snapshots (2). Core package tests passed for projection parity (2)
and deterministic snapshots/results (2): 33 distinct tests in total.

Coverage includes event delivery through the real notifier, adjacent catch-up
snapshots, terminal freezing, empty/early/disposed replays, outline pixel parity
under scaling/mirroring, bounded texture retention, viewport edges and projectile
re-entry, and field/forest full-versus-compact entity parity. Targeted Dart
analysis completed without findings. Replay results and wire formats are unchanged.

## Snapshot microbenchmark

Command from the repository root:

~~~powershell
dart run packages/runner_core/tool/benchmark_ghost_snapshots.dart
~~~

The recorded run used the local Windows Dart 3.13.1 VM, seed 1337, Eloise, and
state at tick 180. Each level had 4 full-snapshot entities and 2 actor-frame
entities. Both paths were warmed 3,000 times; results are medians of seven rounds
of 10,000 calls, with alternating measurement order.

| Level | Full snapshot (µs/call) | Actor frame (µs/call) | Projection speedup |
| --- | ---: | ---: | ---: |
| Field | 3.1668 | 0.3781 | 8.38× |
| Forest | 3.5819 | 0.5179 | 6.92× |

[Raw measurements](ghost-snapshot-benchmark-2026-10-03.json).

These measurements isolate snapshot creation at quiet states. They exclude
simulation, GPU rendering, startup, sustained dense combat and mobile hardware.
The second deterministic Core remains necessary for the current full-world
input-replay design. End-to-end profile builds on target devices are still
needed to quantify total frame-time improvement.

## Loading and buffered playback follow-up

Delivered locally in the subsequent optimization pass:

- Both cached and downloaded replay bytes are decompressed, parsed, and fully
  verified in a native compute isolate before use or cache writes.
- World readiness includes ghost preparation, animations, and bounded outline
  warmup. The warmup never evicts useful opening textures to fill the budget.
- Live and ghost players share animation definitions, with independent tickers.
  Each game owns its image cache. An early-exit/next-run widget regression found
  and verified the fix for pending loads shared through Flame's global cache.
- A persistent native worker owns the ghost Core and returns compact per-tick
  frames/events. The main-isolate queue plus reserved batch slots is limited to
  120 samples, with one request outstanding and refill at half capacity.
- Only samples at or before the live tick are presented. Underruns hold the last
  available pose; catch-up preserves all events and restores adjacent
  interpolation. Completion freezes the terminal pose.
- Cancellation closes worker ports, stops production, clears frames, and fences
  late replies. Failures clear the optional ghost without pausing the live run.
- Web has a cooperative producer using the same engine; it yields between
  roughly 2 ms slices, without claiming parallel execution or bounding the cost
  of one indivisible Core tick.

### Follow-up validation

50 distinct focused tests passed:

| Area | Tests |
| --- | ---: |
| Replay cache, gzip, digest/binding rejection, corrupt-cache recovery | 9 |
| Synchronous replay engine | 8 |
| Real native worker and cooperative producer | 8 |
| Bounded buffer, underrun/catch-up, pause, failure, disposal | 7 |
| Ghost layer, shared animations, warmup cancellation | 9 |
| Outline pixel parity, reuse, memory bound, late-texture disposal | 4 |
| Renderer terrain ordering and readiness gate | 2 |
| Real run-widget early exit, fresh loading, synchronized Start | 2 |
| Loading overlay state | 1 |

The final combined runtime/render/UI regression command passed 41 tests; the
unchanged decoder's nine tests were verified in its own milestone. Targeted
Dart analysis was clean for both milestones. No full repository suite was run.

Native and cooperative producers were compared with synchronous replay at every
tick, including all actor fields and emitted event payloads, for seed 1337,
Eloise, and 900 ticks (15 simulation seconds) on Field and Forest. Separate
tests cover empty playback, early termination, cancellation, startup errors,
and malformed batches. This is not full-run or worst-case-density coverage.

### UI consumption microbenchmark

Run from the repository root:

~~~powershell
flutter test --no-pub --dart-define=GHOST_BENCHMARK_OUTPUT=docs/verification/ghost-playback-buffer-benchmark-2026-10-03.json tools/benchmark_ghost_playback.dart
~~~

The headless Windows Flutter test VM used one warmup round and three measured
rounds per level, 900 ticks per round, and initial terrain preparation for both
paths. Each reported value below is the median of that metric across the three
rounds.

| Level | Synchronous UI step, mean (µs) | Ready-frame UI consumption, mean (µs) | Synchronous UI step, p95 (µs) | Ready-frame UI consumption, p95 (µs) |
| --- | ---: | ---: | ---: | ---: |
| Field | 298.26 | 16.21 | 1030 | 44 |
| Forest | 382.79 | 2.26 | 195 | 5 |

Median worker startup plus initial terrain preparation/prefill was 84.8 ms for
Field and 1936.5 ms for Forest in this debug environment. This preparation is
inside the loading gate and can overlap render asset loading. The measurement
does not include all loading UI, image, outline, or GPU work.

[Raw buffered playback measurements](ghost-playback-buffer-benchmark-2026-10-03.json).

The benchmark measures moving ghost computation off the native UI isolate. It
does not establish lower total CPU usage, battery savings, real-time underrun
rates, or device FPS. It runs the consumer as fast as possible, waits for missing
batches outside the timed consumption calls, and includes request dispatch in
those calls. Debug/JIT scheduling and terrain preparation affect the results.
No browser or phone profile was run for this follow-up.
