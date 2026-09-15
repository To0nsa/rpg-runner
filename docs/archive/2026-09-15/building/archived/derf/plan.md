# Derf Enemy + Target-Point Spell Plan

Date: March 22, 2026  
Status: Implemented (core + render/ui integration complete)

## 1) Goal

Add a new enemy (`Derf`) that is stationary on obstacle tops, always faces the player, and casts a non-projectile explosion at the predicted player center.

This is the first damage spell that does not travel as a projectile. The implementation must establish a reusable, ability-driven path so player abilities can reuse the same spell type later without another architecture rewrite.

Scope note:
- This plan delivers the reusable Core pipeline now for enemy usage.
- Player world-target commit/input integration is intentionally deferred to the later player implementation pass.

## 2) Confirmed Gameplay Contract

- Enemy sprite: `assets/images/entities/enemies/derf/derf.png`
- Derf animation rows (author notes, 1-based):
  - row 1: idle
  - row 3: cast (active frame = 5)
  - row 6: hit
  - row 7: death
- Spell VFX sheet: `assets/images/entities/spells/fire/explosion/oneshot.png`
- Spell active frames: first row, frames 3 and 4 (1-based).
- Spell impact point: predicted player center (not ground-targeted).
- Derf movement: none.
- Derf facing: always oriented toward player.
- Ability model: yes, Derf spell remains an authored ability.
- Naming migration: rename `unoco.enemy_cast` to a Unoco-specific id; create a Derf-specific cast ability id.

## 3) Current Gaps (Why Refactor Is Required)

- Enemy ranged casting is hardcoded to `unoco.enemy_cast` and projectile intent flow.
- `EnemyCastSystem` is projectile-only (`ProjectileIntentStore` write path).
- `EnemyArchetype` exposes `primaryProjectileId` but no general cast ability contract.
- `AbilityActivationSystem` routes only melee/projectile/self/mobility delivery types.
- Renderer only has projectile impact events (`ProjectileHitEvent`) for one-shot spell VFX.
- Spawn markers only carry `(enemyId, x, chance, salt)` and cannot declare perch policy.

Result: adding Derf directly would create one-off branching and duplicate logic, not reusable design.

## 4) Locked Architecture Decisions

1. Keep abilities as the source of truth for timing, cost, damage, and animation.
2. Remove hardcoded enemy cast ability ids from systems.
3. Introduce a generic target-point impact delivery path (non-projectile) in Core.
4. Reuse that same delivery path for enemy AI now; keep it player-reusable, but defer player commit/input integration.
5. Add a non-projectile impact event contract for renderer VFX (do not overload projectile hit events).
6. Add spawn placement policy in chunk markers so obstacle-top spawning is declarative.
7. Add explicit enemy facing policy for stationary casters.
8. Reuse hitbox entities for target-point impacts (do not create a separate damage-volume entity type in this pass).
9. Add explicit death-source behavior for target-point spell impacts and matching Game Over text mapping.
10. Ability-id rename is a hard migration: no backward-compatibility shim for `unoco.enemy_cast`.
11. Target-point impact hitboxes are world-anchored (no owner-follow).
12. `DeathSourceKind.spellImpact` interaction rules are explicit across combat middleware and feedback gates.

## 5) Target Design

### 5.1 Ability Contract

Introduce a new `HitDeliveryDef` subtype for target-point impacts.

Proposed shape (conceptual):
- `TargetPointHitDelivery`
- fields: impact half-size/radius, `HitPolicy`, optional impact effect id, optional target-space semantics.

Keep existing `ProjectileHitDelivery`, `MeleeHitDelivery`, and `SelfHitDelivery` unchanged.

### 5.2 Enemy Cast Contract

Evolve enemy archetype data from projectile-centric to ability-centric.

Add enemy cast fields (conceptual):
- `primaryCastAbilityId`
- `castTargetPolicy` (for Derf: predicted player center)
- optional cast prediction tuning overrides

Migration:
- Unoco cast id renamed from `unoco.enemy_cast` to `unoco.fire_bolt_cast` (or equivalent final naming).
- Derf cast id added (for explosion impact).

### 5.3 New Intent + Execution Path

Add a dedicated intent store and execution system for target-point impacts.

Intent must carry:
- source entity
- target world point (`x`, `y`)
- ability id + slot
- damage/crit/type/procs
- windup/active/recovery/cooldown timing
- execute tick

Execution system responsibilities:
- consume intent at execute tick
- spawn/drive ephemeral impact hitbox entity at target point (reusing existing hitbox pipeline)
- enforce authored `HitPolicy`
- queue damage with deterministic ordering
- emit impact VFX event

World-anchor rule for reused hitbox entities:
- target-point impact hitboxes must be static world-anchored and must not be repositioned by `HitboxFollowOwnerSystem`.
- implementation options: skip owner-follow for a new hitbox mode flag, or spawn a sentinel owner mode that owner-follow ignores.
- acceptance is behavioral (no drift toward caster across active ticks), regardless of implementation detail.

Death-source behavior for reused hitbox path:
- add and use `DeathSourceKind.spellImpact` for target-point spell impacts (not generic melee wording).
- Game Over subtitle mapping must include that source classification and Derf-specific text.

`spellImpact` interaction contract:
- `ParryMiddleware`: does not block/consume `spellImpact`.
- `HashashTeleportEvadeMiddleware`: does not auto-evade `spellImpact` in this pass.
- `WardMiddleware`: keeps current behavior scope (DoT-only); no new blanket cancel for `spellImpact`.
- `PlayerImpactFeedbackGate`: treat `spellImpact` as direct combat impact (same feedback family as projectile/melee, not status-only suppression).

### 5.4 Deterministic Prediction Rule

Consolidate target prediction logic so both projectile and target-point casts share one deterministic helper.

- Projectile casts: lead by windup + travel time.
- Target-point casts: lead by windup time only (impact appears instantly at execute tick).

This keeps behavior stable and replay-safe.

### 5.5 Render Contract

Introduce a new event for non-projectile impacts (conceptual `SpellImpactEvent`).

Event carries:
- tick
- impact/effect id
- world position
- optional source metadata (enemy id / ability id)

Renderer changes:
- add spell-impact render catalog/registry (parallel to projectile registry)
- spawn one-shot animation at event position
- include ghost-event parity path
- include run-start asset warmup for impact assets

### 5.6 Spawn + Facing Policies

Spawn:
- extend `SpawnMarker` with placement mode (conceptual): `ground`, `highestSurfaceAtX`, `obstacleTop`.
- Derf markers use obstacle-top mode.
- deterministic fallback rule for `obstacleTop`: if no obstacle top is valid at marker X, fallback to `highestSurfaceAtX`.
- deterministic tie-break for `obstacleTop` when multiple tops are valid at marker X: pick smallest `yTop` (highest on screen), then smallest stable geometry id/index on ties.

Facing:
- add archetype-level facing policy (conceptual): `movementDriven`, `facePlayerAlways`.
- Derf uses `facePlayerAlways`.

## 6) Derf Authored Data Plan

Core content additions:
- `EnemyId.derf`
- Derf archetype in enemy catalog
- Derf render animation definition from `derf.png`
- Derf ability definition in new catalog file (for example `derf_ability_defs.dart`)

Animation plumbing requirements:
- Derf `AnimProfile` must explicitly enable cast support (`supportsCast: true`) and map cast to `AnimKey.cast`.
- Derf cast animation must be treated as a one-shot action in render loading/registry, matching the authored cast row timing.

Timing authoring target:
- Derf cast ability windup/active/recovery derived from cast row frame windows.
- Explosion active window mapped to authored frames 3-4.

Naming cleanup:
- Replace all `unoco.enemy_cast` references with new Unoco-specific id in systems/tests/tooltips.

## 7) Implementation Phases

## Phase 1 - Contracts + Migration Base

Changes:
- add new hit delivery type
- add enemy cast/facing policy fields in archetype
- rename Unoco cast ability id

Acceptance:
- no hardcoded `unoco.enemy_cast` remains
- Unoco behavior unchanged
- analyzer/tests compile with renamed ids

## Phase 2 - Target-Point Impact Pipeline

Changes:
- add target-point intent store
- add target-point execution system
- wire into `GameCore` order after intent commit and before damage application
- add deterministic prediction helper shared by cast paths
- reuse `HitboxStore`/`HitboxDamageSystem` for impact application at target point
- add explicit death-source classification path for spell-impact hits (`DeathSourceKind.spellImpact`)
- enforce world-anchor behavior for target-point impact hitboxes (owner-follow bypass)
- update middleware/feedback handling for `DeathSourceKind.spellImpact` per locked interaction contract

Acceptance:
- target-point spells can deal damage deterministically without projectile entities
- replay determinism tests stay stable
- spell-impact deaths are not reported as generic melee text
- target-point impact hitboxes remain at target world point for their whole active window

## Phase 3 - Derf Enemy Behavior

Changes:
- add `EnemyId.derf` and archetype data
- stationary spawn/entity assembly
- always-face-player policy
- Derf cast policy: predicted player center
- chunk marker placement policy for obstacle-top spawning

Acceptance:
- Derf spawns perched on obstacles
- Derf never navigates/moves
- Derf tracks facing to player continuously
- Derf commits explosion cast on cooldown/resource rules

## Phase 4 - Impact VFX + UI Surface

Changes:
- add spell-impact event + render catalog/registry
- wire in `RunnerFlameGame` (live + ghost)
- run-start prewarm includes spell impact assets
- update Game Over enemy name mapping for Derf
- update Game Over death subtitle mappings for spell-impact source behavior
- lock Game Over data source for this milestone: subtitle derives from `DeathInfo.kind + DeathInfo.enemyId`; do not extend `DeathInfo` with ability/effect fields yet

Acceptance:
- explosion oneshot plays at predicted target center
- visual timing aligns to active frames contract
- no projectile visual is spawned for this spell
- Game Over spell-impact subtitle works without adding new `DeathInfo` fields

## Phase 5 - Tests + Validation

Core tests:
- enemy cast writes target-point intent at correct execute tick
- target-point damage applies once per policy window
- prediction uses windup-based lead for non-projectiles
- Derf stationary/facing behavior
- obstacle-top spawn placement behavior
- obstacle-top deterministic fallback to highest-surface behavior
- obstacle-top deterministic tie-break behavior with stacked/overlapping candidate tops
- death-source classification and Game Over text mapping for Derf spell-impact kills
- middleware/feedback behavior for `DeathSourceKind.spellImpact`
- world-anchor validation for target-point impact hitboxes

Render/UI tests:
- impact events produce one-shot VFX
- ghost parity for impact VFX events
- Game Over string mapping includes Derf

Validation commands:
- `dart analyze`
- targeted `flutter test` and `test/core/**` slices for touched systems

## 8) File Touchpoints (Expected)

Core:
- `packages/runner_core/lib/abilities/ability_def.dart`
- `packages/runner_core/lib/abilities/ability_catalog.dart`
- `packages/runner_core/lib/abilities/catalog/unoco_ability_defs.dart`
- `packages/runner_core/lib/abilities/catalog/derf_ability_defs.dart` (new)
- `packages/runner_core/lib/enemies/enemy_id.dart`
- `packages/runner_core/lib/enemies/enemy_catalog.dart`
- `packages/runner_core/lib/ecs/world.dart`
- `packages/runner_core/lib/ecs/systems/enemy_cast_system.dart`
- `packages/runner_core/lib/ecs/systems/ability_activation_system.dart`
- `packages/runner_core/lib/ecs/systems/*` for new target-point execution system
- `packages/runner_core/lib/events/game_event.dart` + new/updated event part
- `packages/runner_core/lib/events/run_events.dart`
- `packages/runner_core/lib/spawn_service.dart`
- `packages/runner_core/lib/track/chunk_pattern.dart`
- `packages/runner_core/lib/track/track_streamer.dart`
- `packages/runner_core/lib/game_core.dart`

Render/UI:
- `lib/game/runner_flame_game.dart`
- `lib/game/components/enemies/enemy_render_registry.dart`
- spell-impact render registry/catalog files (new)
- `lib/ui/assets/ui_asset_lifecycle.dart`
- `lib/ui/hud/gameover/game_over_overlay.dart`
- `lib/ui/text/ability_tooltip_builder.dart`

Tests:
- `test/core/enemy_attacks_test.dart`
- new target-point impact tests
- track spawn tests
- renderer event handling tests where applicable

## 9) Risks And Mitigations

1. Risk: overfitting Derf with one-off branches.  
Mitigation: ability-driven delivery + spawn/facing policy enums.

2. Risk: determinism regressions from prediction changes.  
Mitigation: shared deterministic helper + explicit replay-focused tests.

3. Risk: render/event drift between live and ghost.  
Mitigation: add impact event handling in both live and ghost queues in same change.

4. Risk: migration breakage from ability id rename.  
Mitigation: one-pass rename across systems/tests/UI text before adding Derf behavior.

## 10) Definition Of Done

- Derf exists as a full enemy type with authored animations and ability.
- Derf spawns on obstacle tops, remains stationary, and always faces player.
- Derf casts explosion at predicted player center, not ground.
- Explosion damage is delivered via non-projectile target-point pipeline.
- Target-point impacts reuse hitbox entities in this pass.
- Target-point impact hitboxes are world-anchored and do not drift with owner-follow.
- Obstacle-top spawn has deterministic fallback to highest surface when needed.
- Obstacle-top multi-candidate tie-break is deterministic.
- Death-source behavior and Game Over text mapping are explicit for Derf spell impacts.
- `DeathSourceKind.spellImpact` behavior is explicit in middleware and feedback gate handling.
- Pipeline is reusable by player abilities without engine redesign.
- Unoco cast id is enemy-specific (renamed) and behavior remains intact.
- No compatibility shim remains for legacy `unoco.enemy_cast`.
- Relevant analyzer/tests pass for touched slices.

## 11) Implementation Checklist

Phase gates:
- [x] Phase 1 complete: contracts updated + `unoco.enemy_cast` renamed everywhere.
- [x] Phase 2 complete: target-point intent/execution path wired in `GameCore`.
- [x] Phase 3 complete: Derf spawns/behaves correctly (stationary, face-player, predicted-center cast).
- [x] Phase 4 complete: spell-impact VFX/event pipeline works in live + ghost.
- [x] Phase 5 complete: tests/validation pass for touched slices.

Locked-decision guardrail:
- [x] Player world-target integration is deferred (pipeline remains reusable, but no player-input world-target commit in this milestone).
- [x] Target-point impacts reuse hitbox entities (no new damage-volume entity type).
- [x] Target-point hitboxes are world-anchored and bypass owner-follow repositioning.
- [x] `DeathSourceKind.spellImpact` added and used for target-point spell kills.
- [x] Middleware rules for `spellImpact` match this plan (Parry no block, Hashash no auto-evade, Ward unchanged DoT-only, impact feedback treated as direct combat impact).
- [x] `obstacleTop` spawn policy includes deterministic fallback to `highestSurfaceAtX`.
- [x] `obstacleTop` multi-candidate tie-break is deterministic (`smallest yTop`, then stable geometry id/index).
- [x] Derf cast animation plumbing is explicit (`supportsCast: true`, `AnimKey.cast`, one-shot cast handling in render path).
- [x] Game Over subtitle source for this milestone stays `DeathInfo.kind + DeathInfo.enemyId` (no new `DeathInfo` fields).
- [x] No backward-compatibility shim remains for legacy `unoco.enemy_cast`.

Validation commands:
- [x] `dart analyze`
- [x] `flutter test test/core/enemy_attacks_test.dart`
- [x] `flutter test test/core/track_streamer_hashash_deferred_spawn_test.dart`
- [x] `flutter test test/core/target_point_impact_system_test.dart`
- [x] `flutter test test/game/runner_flame_game_ghost_layer_test.dart`
