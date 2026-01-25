# Phase 8: Cleanup + Tests + Determinism

## Goal
Remove legacy paths, stabilize the ability system, and ensure tests cover the
final behavior.

---

## Cleanup Checklist

1. **Remove legacy player systems**
   - `PlayerMeleeSystem` (removed; cast/ranged systems already removed)

2. **Remove stale data paths**
   - Any remaining action tick stampers (`lastMeleeTick`, `lastCastTick`, etc.)
   - Old input slot mask logic if no longer referenced

3. **Consolidate abilities**
   - AbilityActivationSystem is the single input-to-intent pipeline.
   - ActiveAbilityStateStore is the single animation/action authority.

---

## Test Coverage (Required)

1. **Ability buffering**
   - Press during recovery → executes once recovery ends.
   - Latest press overwrites buffer.

2. **Mobility preemption**
   - Dash during windup cancels pending hit/projectile.

3. **Windup/active/recovery phases**
   - Active ability phase transitions are deterministic.
   - AnimSystem uses active ability state for action layer.

4. **Determinism**
   - Same seed + same commands → identical snapshots.

---

## Acceptance Criteria

- All legacy player input systems removed.
- Ability system uses one path for input → intent → execution.
- Input buffering + preemption work as specified.
- `flutter test` passes.
