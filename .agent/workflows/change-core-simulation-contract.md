---
description: Change runner_core command scheduling, tick ordering, or deterministic simulation behavior
---

# Change Core Simulation Contract Workflow

Use this workflow for changes to `GameCore`, commands, deterministic timing,
RNG, system order, run termination, or replay-sensitive gameplay behavior.

Read first:

- `packages/runner_core/AGENTS.md`
- `packages/runner_core/lib/AGENTS.md`
- `docs/tdd/runner_core_simulation_contract.md`
- `services/replay_validator/AGENTS.md` when replayed results can change

## Required decisions before editing

1. State the invariant being changed and whether replay compatibility changes.
2. Identify the exact before/after system dependency in `stepOneTick`.
3. Identify every command producer/consumer when ticks or input semantics move.
4. Decide which deterministic fixture proves the behavior.

## Implementation rules

- Keep command scheduling authority in Core: commands for a step must target
  `core.tick + 1`.
- Never use wall-clock time, frame delta, unordered iteration, or unseeded RNG
  as gameplay authority.
- Keep system changes in owning domains; `GameCore` only coordinates ordering.
- Document non-obvious order dependencies beside the phase and update the TDD.
- Update Game, validator, protocol, and tests in the same change when their
  contract is affected.

## Validation

```powershell
dart analyze packages/runner_core

Push-Location packages/runner_core
dart test
Pop-Location

flutter test test/core/command_scheduling_test.dart test/core/determinism_test.dart test/core/fixed_point_pilot_test.dart
```

Run the complete `test/core` suite for ordering, collision, scoring, terminal,
or broad simulation changes. Also run validator tests when identical replay
inputs may now produce a different outcome.
