---
description: Change runner_core snapshots, events, or renderer/UI-facing output semantics
---

# Change Core Output Contract Workflow

Use this workflow when changing `GameStateSnapshot`, entity render snapshots,
static world snapshot data, `GameEvent`, or `RunEndedEvent` semantics.

Read first:

- `packages/runner_core/AGENTS.md`
- `packages/runner_core/lib/AGENTS.md`
- `docs/tdd/runner_core_simulation_contract.md`
- `lib/game/AGENTS.md`
- `lib/ui/AGENTS.md` when UI state or HUD consumes the contract

## Required decisions before editing

1. State whether the new field is authoritative gameplay state or render-only
   presentation data. Render-only data does not belong in Core unless a replay
   or snapshot consumer needs it.
2. Define tick/lifetime semantics for events and immutable value semantics for
   snapshots.
3. List every producer and consumer, including GameController, Flame views,
   UI state, replay recording, and validator paths where applicable.

## Implementation rules

- Build snapshots from Core state; consumers must not mutate or backfill them.
- Emit events for transient feedback, not for a second gameplay rule path.
- Keep terminal run fields compatible with score, replay, and settlement
  consumers.
- Update all affected consumers in the same change; do not leave parallel
  legacy fields or fallback semantics.

## Validation

```powershell
dart analyze packages/runner_core
flutter test test/core
flutter test test/game
flutter test test/ui
```

Run only the relevant Game/UI targets first, then the wider slices when the
contract is shared. Add validator tests when terminal events or replayed
results change.
