# Building Plan

This document tracks active architecture decisions and subsystems.

## Combat pipeline (v1)

Combat now uses explicit primitives for damage + status effects:

- Damage is modeled with `DamageType` and per-entity resistance modifiers.
- Status effects are applied via `StatusProfileId` (data-first profiles).
- DoT effects tick in Core and queue `DamageRequest`s (deterministic).
- Ranged/thrown weapons are separate from spells (stamina + ammo), but still
  feed into the same damage/status pipeline.

Details: `docs/building/combat.md`.
