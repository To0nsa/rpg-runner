# Deprecated: moved to docs/building/hybridWrite/plan.md

Date: March 16, 2026  
Status: Deprecated mirror (do not maintain)

Canonical source:
[docs/building/hybridWrite/plan.md](docs/building/hybridWrite/plan.md)

This file is kept only for temporary backward compatibility with old links.
All updates must be made in the canonical file above.

## Implementation Strategy

Target delivery model: single cohesive PR (one pass) with no long-lived
parallel path.

Guardrails for one pass:

- keep backend callable contracts unchanged
- keep authority boundary unchanged (`AppState -> LoadoutOwnershipApi`)
- migrate all Tier B/Tier C call sites in the same PR
- add tests for coalescing, conflict recovery, and route/run sync barriers
- block merge unless `dart analyze` and touched tests are green

## Implementation Checklist (Execution Order)

1. Define sync primitives
  - add `ownership_sync_policy.dart`
  - add `ownership_pending_command.dart`
  - add `ownership_sync_status.dart`
2. Add durable outbox store
  - add `ownership_outbox_store.dart` using `SharedPreferences`
  - implement schema versioning (`ui.ownership_outbox.v2`)
3. Refactor `AppState` core pipeline
  - add optimistic overlay model
  - add enqueue/coalesce logic per policy tier
  - add flush scheduler (Tier B debounced, Tier C urgent)
  - add retry/backoff/jitter handling
  - add stale-revision recovery with canonical reload and draft reapply
4. Migrate command handlers
  - Tier B: `setAbilitySlot`, `setProjectileSpell`, `equipGear`
  - Tier C: `setRunMode`, `setLevel`, `setCharacter`
  - keep Tier A immediate-authoritative
5. Wire flush barriers
  - app lifecycle pause/inactive/detached
  - leave level setup route
  - leave loadout route

  - before run start
