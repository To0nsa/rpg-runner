# runner_core

`runner_core` is RPG Runner's authoritative, deterministic gameplay package.
It is pure Dart: Flutter and Flame consume its outputs but never define
gameplay truth.

## Start here

- [Package contributor rules](AGENTS.md)
- [Simulation contract](../../docs/tdd/runner_core_simulation_contract.md)
- [Terrain capsule controller](../../docs/tdd/terrain_capsule_controller.md)
- [Animation data flow](../../docs/tdd/animation_data_flow_and_timing.md)
- [Replay-validator contract](../../docs/tdd/replay_validator_worker.md)

## Ownership

| Concern | Owner |
| --- | --- |
| Fixed-tick gameplay, ECS state, collision, combat, track streaming, run state | `runner_core` |
| Input aggregation, fixed-tick driving, interpolation, Flame rendering | `lib/game/` |
| Menus, HUD, local app state, backend adapters | `lib/ui/` |
| Replay/run/board wire contracts | `packages/run_protocol/` |
| Server-side replay execution and settlement handoff | `services/replay_validator/` |

The main Core entry point is `lib/game_core.dart`. Commands enter through
`lib/commands/`, transient feedback leaves through `lib/events/`, and immutable
renderer/UI data leaves through `lib/snapshots/`.

## Content and generated runtime data

Playable-level source data is repository-owned:

- `assets/authoring/level/level_defs.json`
- `assets/authoring/level/chunks/**`
- `assets/authoring/level/prefab_defs.json`
- `assets/authoring/level/parallax_defs.json`

Run the root generator after changing that data. Do not hand-edit its outputs,
including `lib/levels/level_id.dart`, `lib/levels/level_registry.dart`, and
`lib/track/authored_chunk_patterns.dart`.

```powershell
dart run tool/generate_chunk_runtime_data.dart --dry-run
dart run tool/generate_chunk_runtime_data.dart
```

## Validation

Run the narrowest relevant checks, then broaden for replay-sensitive work.

```powershell
dart analyze packages/runner_core

Push-Location packages/runner_core
dart test
Pop-Location

flutter test test/core
```

The package-local tests protect portable Core behavior. The root `test/core/**`
suite covers broader Core integrations; it is the right target when gameplay,
snapshots, content, or determinism changes.

## Staged terrain APIs

`lib/collision/terrain/**` contains the deterministic polygon compiler, edge
index, capsule/segment kernel, actor-neutral traversal profile, capsule
controller, and future ground-target query.

`GameCore.terrainMotionHarness(...)` exercises those APIs through the real
player systems for tests and benchmarks. It is deliberately not exported as a
level/replay option and is not the motion authority used by normal
repository-backed runs. The normal `GameCore(...)` constructor continues to
use legacy rectangle collision until the slopes plan reaches its direct
cutover.

Run the focused slope benchmarks from this package:

```powershell
dart run tool/benchmark_slopes.dart --fixture=representative --strict
dart run tool/benchmark_slopes_phase2.dart --strict
```

VM allocation evidence for the complete Phase 2 controller requires the
service profiler:

```powershell
dart --observe=0 --no-pause-isolates-on-exit --profiler run `
  tool/benchmark_slopes_phase2.dart --allocation-profile
```

## Change guides

- [Add a Core system](../../.agent/workflows/add-core-system.md)
- [Create an ECS component](../../.agent/workflows/create-ecs-component.md)
- [Add a playable level](../../.agent/workflows/add-new-level.md)
- [Change a simulation contract](../../.agent/workflows/change-core-simulation-contract.md)
- [Change a snapshot or event contract](../../.agent/workflows/change-core-output-contract.md)
- [Change authored Core content](../../.agent/workflows/change-core-authored-content.md)
