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

## Enemy AI pipeline (v2)

Enemy AI is split into intent-driven systems so navigation, engagement, locomotion,
and combat can evolve independently.

Pipeline per tick:

1. **Navigation** (`EnemyNavigationSystem`) computes `NavIntentStore` from the
   surface graph (planner target = player or predicted landing).
2. **Engagement** (`EnemyEngagementSystem`) updates `MeleeEngagementStore` and
   writes `EngagementIntentStore` (slot target, arrival slow radius, speed muls).
3. **Locomotion** (`GroundEnemyLocomotionSystem` + `FlyingEnemyLocomotionSystem`)
   applies velocities using nav + engagement intents (ground) and steering (Unoco).
4. **Combat** (`EnemyCastSystem` + `EnemyMeleeSystem`) writes
   `CastIntentStore`/`MeleeIntentStore` and updates attack windows for animation.

This keeps pathfinding separate from melee slot logic and keeps combat decisions
independent from locomotion mechanics.

Ground enemy tuning is grouped by responsibility in `GroundEnemyTuning`:
`navigation`, `engagement`, `locomotion`, and `combat`.

## Render animation windows

Core owns deterministic animation windows via `AnimTuning` (attack/cast/hit/death/spawn).
Renderer consumes `AnimKey` + `animFrame` only; no simulation logic lives in Flame.

### Player animations

For Éloïse, render strip timing (frame counts x step time) is authored in
`lib/core/players/characters/eloise.dart`, and `eloiseTuning.anim` is kept in
sync so Core windows match render strip timing.

### Enemy animations

Enemy render animations are data-driven via `EnemyArchetype.renderAnim`, with
frame dimensions, step times, and sprite paths defined in `enemy_catalog.dart`.
`RenderAnimSetDefinition` supports both single-row strips and multi-row sheets:
multiple `AnimKey`s can reuse one sheet path and use `rowByKey` (0-based) to
select the row per key (defaults to row 0 for strip compatibility).
When authored art needs an offset pivot, `anchorInFramePx` can be set to define
the anchor point within a frame (defaults to `Anchor.center` when omitted).
Hit windows are authored per enemy (`EnemyArchetype.hitAnimSeconds`).

**Animation pipeline** (AnimSystem → AnimStateStore → SnapshotBuilder):

1. `AnimSystem` runs each tick in Phase 21 (also during death-anim freeze).
2. `AnimResolver` applies `AnimProfile` + state signals to select `AnimKey` + `animFrame`.
3. Results are written to `AnimStateStore` (anim, animFrame).
4. `SnapshotBuilder` reads from the store for both player and enemies; it does not compute anim.

Per-entity rules live in `AnimProfile` data:
- **Unoco**: uses `run` even while airborne; walk disabled; attack → `idle`.
- **Ground enemy**: uses jump/fall when airborne; walk/run thresholds on ground.

Render strip metadata is shared via `RenderAnimSetDefinition` in
`lib/core/contracts/render_anim_set_definition.dart` for both players and enemies.

### Projectile animations

Spell projectiles have render definitions in
`lib/core/projectiles/projectile_render_catalog.dart` (frame sizes, timing,
asset paths). The renderer loads these via a `ProjectileRenderRegistry` and
maps animation keys as follows:

- `AnimKey.spawn` -> `start.png` (one-shot, used on initial ticks).
- `AnimKey.idle` -> `repeatable.png` (looping travel animation).
- `AnimKey.hit` -> `hit.png` (one-shot impact).

Projectile impacts emit `ProjectileHitEvent` from Core so the renderer can
spawn a hit animation even though the projectile entity despawns immediately.
Spawn animation duration is derived from the render definition and tick rate;
render switches to `idle` after the spawn window.

## Player characters (multi-character ready)

Player configuration is split into:

- **World/level tuning**: `lib/core/tuning/core_tuning.dart` (no player-specific fields).
- **Character definition**: `lib/core/players/player_character_definition.dart`
  and `lib/core/players/player_character_registry.dart`.
- **Baseline character**: `lib/core/players/characters/eloise.dart` (all current v0 defaults).

`GameCore` takes a `playerCharacter:` parameter; tests can override per-character
`PlayerCatalog` (collider/physics flags) and `PlayerTuning` (movement/resource/ability/anim/combat)
via `copyWith` on the character definition.
