# Ability Composition Implementation Plan Checklist

Date: 2026-02-11  
Depends on: `docs/building/ability_composition_contract.md`

## Goal

- [x] Implement composable ability behavior for `primary`, `secondary`, and `mobility` across:
  - [x] input lifecycle (`tap`, `holdRelease`, `holdMaintain`)
  - [x] targeting (`self`, `directional`, `aimed`, `homing`)
  - [x] charge (`none`, `tiered`)
- [x] Preserve determinism and backward compatibility during migration.

## Non-Goals

- [x] Do not add in-flight homing retargeting in this migration.
- [x] Do not rework projectile/bonus/jump UX beyond compatibility needs.
- [x] Do not include monetization/progression changes.

## Migration Strategy

- [x] Use incremental contract-first migration (recommended).
- [x] Avoid big-bang rewrite of all slot behavior in one pass.
- [x] Keep compatibility defaults until cleanup phase.

## Phase 0 - Freeze Contracts and Compatibility Rules

- [x] Keep `TargetingModel` semantics unchanged.
- [x] Add authored input lifecycle contract with compatibility defaults.
- [x] Keep charge authority in Core (`AbilityChargeStateStore`) only.
- [x] Confirm team agreement on phased migration.
- [x] Exit criteria: migration plan accepted without requiring slot-specific forks.

## Phase 1 - Data Model: Author Input Lifecycle Explicitly

- [x] Add `AbilityInputLifecycle` enum in `lib/core/abilities/ability_def.dart`.
- [x] Add `inputLifecycle` field to `AbilityDef` in `lib/core/abilities/ability_def.dart`.
- [x] Implement compatibility default mapping:
  - [x] `holdMode == holdToMaintain` -> `holdMaintain`
  - [x] else if legacy inferred hold-release -> `holdRelease`
  - [x] else -> `tap`
- [x] Start incremental authored updates in `lib/core/abilities/ability_catalog.dart`.
- [x] Update snapshot mode resolution in `lib/core/snapshot_builder.dart` to use authored lifecycle first.
- [x] Keep fallback inference only for migration window.
- [x] Add/extend lifecycle mapping tests.
- [x] Exit criteria: current abilities keep existing UX behavior.

## Phase 2 - Shared Commit Resolution Across Slots

- [x] Extract shared commit direction resolver in `lib/core/ecs/systems/ability_activation_system.dart`.
- [x] Ensure resolver supports `self`, `directional`, `aimed`, `homing`.
- [x] Apply deterministic fallback chain from contract.
- [x] Use shared resolver for melee path.
- [x] Use shared resolver for projectile path.
- [x] Use shared resolver for mobility path.
- [x] Remove mobility aim-blocking rule in `lib/core/abilities/ability_gate.dart`.
- [x] Preserve non-aim mobility gating (stun/body/cooldown/stamina/dash-active).
- [x] Extend `test/core/ability_gate_test.dart` for updated mobility policy.
- [x] Add commit-direction determinism tests by targeting model.
- [x] Exit criteria: direction resolution is slot-agnostic and deterministic.

## Phase 3 - Mobility Runtime Upgrade (Vector-Capable)

- [x] Extend `lib/core/ecs/stores/mobility_intent_store.dart` to include vector direction (`dirY`).
- [x] Extend `lib/core/ecs/stores/player/movement_store.dart` for vector dash state (if required).
- [x] Update `lib/core/ecs/systems/mobility_system.dart` to execute vector-based mobility.
- [x] Preserve legacy horizontal fallback behavior for directional-only outcomes.
- [x] Extend `test/core/player_movement_test.dart`.
- [x] Extend `test/core/gravity_system_test.dart`.
- [x] Add aimed mobility execution tests.
- [x] Add homing mobility execution tests.
- [x] Exit criteria: aimed/homing mobility works without regressing existing dash.

## Phase 4 - Charge Generalization Beyond Aimed-Only Assumptions

- [x] Make charge tier selection targeting-agnostic in `lib/core/ecs/systems/ability_activation_system.dart`.
- [x] Update charge preview derivation in `lib/core/snapshot_builder.dart` to remove aimed-only assumptions.
- [x] Add mobility charge preview support in snapshot data.
- [x] Add tests for `holdRelease + homing + tiered`.
- [x] Add tests for `holdMaintain + homing + tiered`.
- [x] Add tests for charged mobility variants.
- [x] Exit criteria: tiered charge works for all allowed matrix combinations.

## Phase 5 - UI/Game Input Alignment

- [x] Keep router edge authority in `lib/game/input/runner_input_router.dart`.
- [x] Add mobility hold/release helpers in `lib/game/input/runner_input_router.dart` if required.
- [x] Add mobility input mode to HUD snapshot contract in `lib/core/snapshots/player_hud_snapshot.dart`.
- [x] Update HUD mode computation in `lib/core/snapshot_builder.dart`.
- [x] Wire mobility mode in `lib/ui/hud/game/game_overlay.dart`.
- [x] Wire mobility mode in `lib/ui/controls/runner_controls_overlay_radial.dart`.
- [x] Reuse existing control primitives (no slot-specific custom control type).
- [x] Add/extend widget tests for mobility mode rendering and callbacks.
- [x] Keep `test/runner_input_router_release_test.dart` passing.
- [x] Exit criteria: UI mode is authored-driven per slot and not hardcoded by slot name.

## Phase 6 - Content Authoring + Matrix Proof

- [x] Author at least one `homing + tiered` ability variant.
- [x] Author at least one mobility charged-aimed variant.
- [x] Keep loadout validation aligned in `lib/core/loadout/loadout_validator.dart`.
- [x] Extend `test/core/loadout/loadout_validator_test.dart`.
- [x] Verify matrix-proof abilities can equip and execute end-to-end.
- [x] Exit criteria: previously unavailable matrix combinations are proven by authored content.

## Phase 7 - Cleanup and Legacy Path Removal

- [x] Remove temporary lifecycle fallback inference.
- [x] Remove obsolete mobility-specific snapshot/HUD assumptions.
- [x] Update `docs/building/ability_system_review.md`.
- [x] Update `docs/building/hold_ability_contract.md` if semantics changed.
- [x] Exit criteria: no parallel legacy behavior path remains for composition handling.

## Cross-Phase Quality Gates

- [x] Determinism gate: same seed + same commands => same snapshots/events.
- [x] Determinism gate: same hold timing => same commit tier and direction.
- [x] Regression gate: existing dash/jump/melee/projectile unchanged unless intentionally migrated.
- [x] Regression gate: cooldown/cost timing still starts at commit tick.
- [x] Coverage gate: unit tests cover commit/charge/gates.
- [x] Coverage gate: integration tests cover `primary`, `secondary`, `mobility`.
- [x] Coverage gate: widget tests cover slot input mode wiring.

## Risks and Mitigations

- [x] Risk tracked: mobility regressions from vector migration.
- [x] Mitigation applied: keep directional fallback plus phase-gated tests.
- [x] Risk tracked: authored mode and UI mode mismatch.
- [x] Mitigation applied: UI reads authoritative slot mode from snapshot only.
- [x] Risk tracked: charge preview desync.
- [x] Mitigation applied: use Core charge state only (no UI stopwatch authority).

## Done Definition

- [x] Contract matrix (excluding explicit exclusions) is representable and tested.
- [x] `primary`, `secondary`, and `mobility` use shared composition semantics.
- [x] No slot-specific hardcoded targeting/input/charge restrictions remain beyond authored rules.
- [x] Documentation and tests are updated to match final behavior.
