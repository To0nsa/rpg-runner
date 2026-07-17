---
description: Add a new Core system to the deterministic game loop
---

# Add Core System Workflow

Use this workflow when adding or reordering logic under
`packages/runner_core/lib/ecs/systems/**`. Read
`packages/runner_core/lib/AGENTS.md` first.

## Current Source Of Truth

- systems: `packages/runner_core/lib/ecs/systems/**`
- stores/components: `packages/runner_core/lib/ecs/stores/**`
- world registry: `packages/runner_core/lib/ecs/world.dart`
- tick ordering: `packages/runner_core/lib/game_core.dart`
- inputs: `packages/runner_core/lib/commands/**`
- outputs: `packages/runner_core/lib/events/**` and
  `packages/runner_core/lib/snapshots/**`

Do not use the obsolete `lib/core/**` paths.

## Steps

1. Identify dependencies before writing code.

   Record which stores the system reads/writes, which systems must run
   before/after it, whether it emits events, and what deterministic tie-breaks
   are required.

2. Implement the system in the owning domain folder.

   Keep it focused. If behavior already belongs to an existing system, extend
   that system instead of creating a parallel path.

3. Preserve deterministic iteration.

   Iterate stable store order or explicitly sort/tie-break by stable ids when
   order affects outcomes. Avoid allocations in hot loops.

4. Handle structural changes through existing lifecycle patterns.

   Do not destroy entities or add/remove components while iterating a store
   unless the touched system already owns a safe deferred pattern.

5. Wire into `GameCore.stepOneTick()`.

   Add the system at the phase that matches its dependencies. If ordering is
   non-obvious, add a concise comment explaining the invariant.

6. Update consumers.

   If the system emits new events or snapshot data, update `lib/game/**`,
   `lib/ui/**`, and tests in the same change.

## Suggested Validation

```bash
dart analyze packages/runner_core
flutter test test/core
```

For cross-layer output changes, add the relevant slices:

```bash
flutter test test/game
flutter test test/ui
```

## Guardrails

- no wall-clock time as gameplay authority
- no unseeded randomness
- no render/UI concepts in Core systems
- no silent changes to replay-sensitive ordering
- no broad `game_core.dart` growth when a focused system/domain owns the rule
