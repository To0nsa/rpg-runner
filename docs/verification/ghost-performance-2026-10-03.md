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
