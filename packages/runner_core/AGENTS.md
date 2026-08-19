# AGENTS.md - runner_core Package

Instructions for work anywhere in `packages/runner_core/`.

## Package boundary

`runner_core` is the authoritative pure-Dart gameplay package. It owns the
fixed-tick simulation, ECS world, gameplay rules, track streaming, snapshots,
events, and run-facing content definitions.

It must not import Flutter or Flame, use wall-clock time as gameplay
authority, or duplicate replay/board wire contracts owned by
`packages/run_protocol/`.

Read `lib/AGENTS.md` before changing production Core source. It adds
implementation-specific deterministic, ECS, and system-ordering rules.

## Package map

- `lib/`: production simulation and contracts
- `test/`: portable package tests run without Flutter
- root `test/core/`: wider gameplay/integration coverage for this package
- `packages/runner_content_pipeline/`: repository-independent authored source
  compilation and typed Core runtime-data materialization
- root `tool/generate_chunk_runtime_data.dart`: generator for authored level
  runtime data; its Core outputs are generated files

## Cross-layer changes

Read `docs/tdd/runner_core_simulation_contract.md` before changing command
scheduling, `GameCore.stepOneTick` ordering, determinism, snapshots, events,
or generated gameplay content.

Also update and validate the owning consumer when a change crosses a boundary:

- `lib/game/**` for input scheduling, snapshot consumption, or rendering
- `lib/ui/**` for HUD/run-state or presentation contracts
- `packages/run_protocol/**` for replay/run/board payload changes
- `services/replay_validator/**` for replayed outcomes or validation rules
- `tools/editor/**` and root authoring assets for content-source changes

## Generated-content discipline

Author level/chunk/prefab/parallax data in `assets/authoring/level/**`. Run
`dart run tool/generate_chunk_runtime_data.dart`; never hand-edit generated
Core runtime data. Use `--dry-run` to validate source data and generator drift.
The root generator delegates current-schema decoding, terrain compilation,
seam validation, and typed chunk materialization to
`packages/runner_content_pipeline`; Core must not depend back on that package.
The generator also owns `lib/track/staged_authored_terrain.dart`. Despite its
historical filename, this is the production polygon artifact admitted by
normal Core and replay-validation construction and projected to Flutter through
Core snapshots. Do not hand-edit it or introduce another terrain source.

## Validation

Minimum Core checks:

```powershell
dart analyze packages/runner_core

Push-Location packages/runner_core
dart test
Pop-Location
```

Use `flutter test test/core` for gameplay, content, snapshot, or determinism
changes. Add the relevant Game, UI, protocol, validator, or editor checks for
cross-layer work.

## Documentation and workflows

- Package orientation: `packages/runner_core/README.md`
- Simulation invariants: `docs/tdd/runner_core_simulation_contract.md`
- Animation timing: `docs/tdd/animation_data_flow_and_timing.md`
- Active implementation work belongs in `docs/building/**`, never as a TODO
  document beside production source.
- Use the matching `.agent/workflows/**` guide for systems, components, levels,
  simulation contracts, output contracts, or authored-content changes.
