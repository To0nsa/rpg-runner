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

## Render animation windows

Core owns deterministic animation windows via `AnimTuning` (attack/cast/hit/death/spawn).
Renderer consumes `AnimKey` + `animFrame` only; no simulation logic lives in Flame.
Default `AnimTuning` values derive from `lib/core/tuning/player/player_tuning.dart`
(frame counts x step times) so Core windows match render strip timing.

## Player characters (multi-character ready)

Player configuration is split into:

- **World/level tuning**: `lib/core/tuning/core_tuning.dart` (no player-specific fields).
- **Character definition**: `lib/core/players/player_character_definition.dart`
  and `lib/core/players/player_character_registry.dart`.
- **Baseline character**: `lib/core/players/characters/eloise.dart` (all current v0 defaults).

`GameCore` takes a `playerCharacter:` parameter; tests can override per-character
`PlayerCatalog` (collider/physics flags) and `PlayerTuning` (movement/resource/ability/anim/combat)
via `copyWith` on the character definition.
