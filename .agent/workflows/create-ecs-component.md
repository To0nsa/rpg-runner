---
description: Create a new ECS store/component in the Core package
---

# Create ECS Component Workflow

Use this workflow when adding persistent ECS state to
`packages/runner_core/lib/`. Read `packages/runner_core/lib/AGENTS.md` first.

## Current Shape

Core uses typed sparse-set stores registered on `EcsWorld`:

- world: `packages/runner_core/lib/ecs/world.dart`
- sparse-set base: `packages/runner_core/lib/ecs/sparse_set.dart`
- stores: `packages/runner_core/lib/ecs/stores/**`
- systems: `packages/runner_core/lib/ecs/systems/**`
- simulation ordering: `packages/runner_core/lib/game_core.dart`

Do not use the obsolete `lib/core/**` paths.

## Steps

1. Find the closest existing store.

   Match the local style for SoA fields, dense-index access, `add/remove`, and
   `removeEntity` behavior. Prefer extending an existing domain store when the
   data is naturally part of the same component.

2. Add the typed store under `packages/runner_core/lib/ecs/stores/**`.

   Keep persistent component data plain and allocation-light. Avoid putting
   per-tick behavior in the store unless existing stores use that pattern for
   lifecycle bookkeeping.

3. Register the store on `EcsWorld`.

   Add the import and a `late final` field initialized through `_register(...)`
   so entity destruction removes the component consistently.

4. Add or update systems under `ecs/systems/**`.

   Systems own behavior. Keep iteration deterministic, avoid structural changes
   mid-iteration, and use explicit queues or existing lifecycle phases when
   entities/components must be added or removed.

5. Wire system ordering in `GameCore` only when needed.

   Treat `GameCore.stepOneTick()` order as a behavior contract. Document any
   non-obvious ordering dependency near the ordering code.

6. Expose snapshots/events only when consumers need them.

   Add snapshot/event fields intentionally and update all `lib/game/**` and
   `lib/ui/**` consumers in the same change.

## Suggested Validation

```bash
dart analyze packages/runner_core
flutter test test/core
```

Add focused tests for:

- store add/remove/destroy lifecycle
- deterministic system output for stable inputs
- ordering-sensitive interactions
- snapshot/event exposure when added

## Guardrails

- no Flutter or Flame imports in Core
- no `DateTime.now()` or unseeded randomness for gameplay
- no stringly typed component maps when a typed store fits
- no component/entity removal during active store iteration unless the existing
  system phase explicitly supports it
- no snapshot shape changes without updating render/UI tests
