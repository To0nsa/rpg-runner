# Ability System Implementation Review (2026-01-24)

## Scope
Review of the current ability system implementation across Core + Game layers, checked against
`docs/building/ability_system_design.md`. This document focuses on correctness, determinism,
and alignment with the design contracts.

## Files Reviewed (Key)
- Core abilities + loadout: `lib/core/abilities/ability_def.dart`, `lib/core/abilities/ability_catalog.dart`,
  `lib/core/ecs/stores/combat/equipped_loadout_store.dart`, `lib/core/loadout/loadout_validator.dart`
- Input/commands: `lib/core/commands/command.dart`, `lib/core/ecs/stores/player/player_input_store.dart`,
  `lib/game/input/runner_input_router.dart`, `lib/core/game_core.dart`
- Ability activation + timing: `lib/core/ecs/systems/ability_activation_system.dart`,
  `lib/core/ecs/stores/ability_input_buffer_store.dart`, `lib/core/ecs/stores/active_ability_state_store.dart`,
  `lib/core/ecs/systems/active_ability_phase_system.dart`
- Execution systems: `lib/core/ecs/systems/melee_strike_system.dart`,
  `lib/core/ecs/systems/projectile_launch_system.dart`, `lib/core/ecs/systems/projectile_hit_system.dart`
- Combat payload + damage: `lib/core/combat/hit_payload_builder.dart`, `lib/core/combat/hit_payload.dart`,
  `lib/core/combat/damage.dart`, `lib/core/ecs/systems/damage_system.dart`
- Animation integration: `lib/core/ecs/systems/anim_system.dart`

## Current Architecture (Pipeline Summary)
1. Game/UI input schedules `Command`s with tick stamps (RunnerInputRouter).
2. Core decodes commands into `PlayerInputStore` each tick (`GameCore.applyCommands`).
3. `AbilityActivationSystem` selects the equipped ability per slot, applies input buffering,
   and writes intent stores (`MeleeIntentStore`, `ProjectileIntentStore`).
4. Execution systems consume intents:
   - `MeleeStrikeSystem` spawns hitboxes and applies costs/cooldowns.
   - `ProjectileLaunchSystem` spawns projectiles and applies costs/cooldowns.
   - `MobilitySystem` applies dash/roll state and costs/cooldowns.
   - `PlayerMovementSystem` executes jump intents (buffer/coyote-aware).
5. Damage and status application goes through `DamageSystem` and `StatusSystem`.
6. `ActiveAbilityStateStore` + `ActiveAbilityPhaseSystem` drive animation action layer
   in `AnimSystem` and clear on completion/interruption.

## Current State (Implemented)
### Core Ability Model
- `AbilityDef` defines category, allowed slots, targeting model (declared), hit delivery,
  windup/active/recovery ticks (60 Hz), costs, cooldown, interrupt priority, tags, and base damage.
- `AbilityCatalog` registers Eloise abilities and shared enemy abilities.
- `AbilitySlot` supports primary, secondary, projectile, mobility, bonus, jump (fixed).

### Loadout + Validation
- Loadout has non-null IDs for all configured slots (no "none" semantics).
- `LoadoutValidator` enforces:
  - Ability slot compatibility (`allowedSlots`).
  - Required weapon types (`requiredWeaponTypes`) vs weapon types.
  - Weapon category validity + two-handed conflicts.
  - Missing IDs are treated as catalog errors.

### Deterministic Input + Buffering
- Inputs are tick-stamped commands; held axes/aims are pre-buffered in the Game layer.
- `AbilityActivationSystem`:
  - Prevents new commits while an ability is active.
  - Buffers one input during Recovery (latest wins).
  - Resolves projectile slot via a single input channel and builds `ProjectileIntentDef`
    using `ProjectileItemCatalog` for payload.

### Intent and Execution
- Intents now include commit tick + windup/active/recovery windows.
- Commit happens at `commitTick`, execution at `commitTick + windup`.
- Stamina/mana cost and cooldown start at commit (as per design).
- Hit payload is assembled via `HitPayloadBuilder` (ability base + weapon modifiers).

### Animation Integration
- `ActiveAbilityStateStore` is the single action channel for animations.
- `ActiveAbilityPhaseSystem` advances phases and handles forced interruption (stun/death).
- `AnimSystem` resolves action animations from active ability IDs and elapsed ticks.

### Fixed-Point Damage and Resources
- Damage and costs use fixed-point integers (100 = 1.0).
- `DamageRequest` and `DamageSystem` operate on `amount100`.
- Status application supports both explicit status profiles and proc rolls.

## Design Contract Coverage (Ability System Design)
| Design Contract | Status | Notes |
| --- | --- | --- |
| Slots are never empty | OK | Loadout uses non-null IDs with defaults; no "none" semantics. |
| Modifier order (Ability -> Weapon -> Passive) | PARTIAL | Ability + weapon order enforced in `HitPayloadBuilder`; passive layer not yet modeled. |
| Deterministic timing (windup/active/recovery) | OK | Ability defs are 60 Hz and scaled at commit; intents execute at `commit + windup`. |
| Cooldown starts on commit | OK | All execution systems start cooldown on commit. |
| Costs paid on commit | OK | Mana/stamina costs applied at commit. |
| One combat ability at a time | PARTIAL | Enforced via `ActiveAbilityStateStore`; ability activation ignores new inputs while active. |
| Mobility preemption | OK | Dash and Jump commit through AbilityActivationSystem; jump press clears buffered combat immediately. |
| Targeting determines commit (tap/hold/release) | PARTIAL | Core only supports "commit on press"; hold/release must be orchestrated by input layer. |
| Self-centered and defensive abilities | NO | `SelfHitDelivery` is not executed; defense category uses melee path only. |
| Projectile payload ownership | OK | Ability defines structure; projectile items provide payload via `HitPayloadBuilder`. |
| Input buffering in recovery only | OK | Implemented via `AbilityInputBufferStore`. |
| Bonus slot support | NO | Bonus slot exists in enum/input but not in loadout/activation. |
| Auto-target (future) | NO | Not implemented. |

## Gaps and Deviations
1. Targeting models are declared but not enforced in Core.
   - `TargetingModel` exists but AbilityActivationSystem does not branch on it.
   - Hold-to-aim vs commit-on-release is currently only possible via input scheduling,
     not a Core state machine.

2. Defensive/self abilities are not executable.
   - Abilities like shield block/parry use `SelfHitDelivery` but activation only supports
     `MeleeHitDelivery` and `ProjectileHitDelivery`.
   - Result: defensive abilities are not actually runnable despite being in the catalog.

3. Bonus slot not wired.
   - Input exists (`BonusPressedCommand`), but loadout has no bonus ability ID,
     validator does not check it, and activation returns `null`.

4. Hit policy is unused.
   - `HitPolicy` exists in ability definitions, but hitbox/projectile systems do not enforce
     per-policy behavior (e.g., every-tick vs once-per-target).


## Quality Notes (DRY, Performance, Clean Architecture)
- Determinism is strong: fixed tick rate, tick-stamped inputs, and fixed-point math
  are used consistently in the damage path.
- Tick scaling helpers are duplicated across multiple systems. This is minor, but a
  shared utility would reduce DRY violations.
- Action animation is now centralized via `ActiveAbilityStateStore`, which is aligned
  with the phase-based design and reduces special-case animation logic.
- Input buffering is minimal and allocation-light (single buffered slot per entity).

## Test Coverage (Ability-Related)
These tests currently validate core ability behavior:
- `test/core/melee_test.dart`
- `test/core/cast_test.dart`
- `test/core/ranged_weapon_test.dart`
- `test/core/intent_and_hitbox_contracts_test.dart`
- `test/core/phase6_verification_test.dart`
- `test/runner_input_router_aim_quantize_test.dart`
- `test/runner_input_router_release_test.dart`

## Recommended Next Steps (To Align With Design Contracts)
1. Implement targeting model handling in Core.
   - Add an aim/hold state machine (press vs release, committed hold, aim lock).
   - Persist aim/facing in `ActiveAbilityStateStore` if needed for animations.

2. Implement `SelfHitDelivery` execution.
   - Enable block/parry/buff abilities with no hitbox/projectile.
   - Add ability category routing for defense/utility.

3. Wire bonus slot end-to-end.
   - Add bonus ability ID to loadout, validate it, and route it in activation.

4. Apply `HitPolicy` in hit systems.
   - Encode once-per-target vs every-tick and align with `HitOnceStore` usage.
