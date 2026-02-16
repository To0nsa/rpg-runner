# Ability System Implementation Review (2026-01-24)

## Update (2026-02-10)
- Spell slot is now intentionally **self-spell only** for the current vertical slice.
- Projectile/melee abilities are no longer authored for `AbilitySlot.spell`.
- Added spell-slot self spells: `eloise.restore_health`, `eloise.restore_mana`, `eloise.restore_stamina`.
- `SelfAbilitySystem` now applies deterministic self-resource restoration authored on `AbilityDef` (`selfRestore*Bp`).
- Spell ability picker no longer shows projectile-source selection panel.
- Spell input path is tap-only end-to-end; legacy spell hold/aim/charge HUD and control contracts were removed.
- Legacy spell projectile-source schema/persistence (`spellSlotSpellId`) was removed; slot spell selection is projectile-slot only.
- Homing auto-target is now resolved at commit-time for abilities authored with `TargetingModel.homing` (projectile and melee).
- Added melee homing variants `eloise.sword_strike_auto_aim` / `eloise.shield_bash_auto_aim` with explicit reliability tax:
  - base damage `15.0 -> 14.0`
  - stamina cost `5.0 -> 5.5`
  - cooldown `18 -> 24` ticks

## Update (2026-02-11)
- Runtime interruption contracts were simplified:
  - Removed `interruptPriority` / `canBeInterruptedBy` from `AbilityDef`.
  - Forced interrupts (`forcedInterruptCauses`) are now the single authored interruption model.
  - Forced interruption cleanup (active ability, buffered input, pending intents) is shared by systems.
- Aim input contracts were simplified:
  - Replaced split projectile/melee aim channels with one global aim channel.
  - Ability commits consume the same authoritative aim vector.
  - Slot holds are now exclusive (starting a hold on one slot clears other held slots).
  - Same-tick hold replacements now emit explicit release + hold edges so latest hold wins deterministically after frame aggregation.
- Ability composition contracts were expanded for primary/secondary/mobility:
  - Added authored `AbilityInputLifecycle` to `AbilityDef` (`tap`, `holdRelease`, `holdMaintain`) and made it required for authored abilities.
  - HUD input mode resolution now reads authored lifecycle (including mobility mode), and distinguishes:
    - `holdAimRelease` for aimed/directional hold-release abilities
    - `holdRelease` for non-aim hold-release abilities (for example `homing`)
  - Mobility commit no longer fails while aim is held.
  - Mobility direction resolution is now shared with melee/projectile targeting fallback policy.
  - Mobility runtime now supports 2D dash vectors.
  - Added matrix-proof authored abilities:
    - `eloise.charged_sword_strike_auto_aim` (`homing + tiered`)

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
   and writes intent stores (`MeleeIntentStore`, `ProjectileIntentStore`, `SelfIntentStore`), sourcing payload
   from an explicit provider (weapon, throwing item, or spell book).
4. Execution systems consume intents:
   - `MeleeStrikeSystem` spawns hitboxes and applies costs/cooldowns.
   - `ProjectileLaunchSystem` spawns projectiles and applies costs/cooldowns.
   - `SelfAbilitySystem` executes `SelfHitDelivery` abilities and queues status profiles.
   - `MobilitySystem` applies dash/roll state and costs/cooldowns.
   - `PlayerMovementSystem` executes jump intents (buffer/coyote-aware).
5. Damage and status application goes through `DamageSystem` and `StatusSystem`.
6. `ActiveAbilityStateStore` + `ActiveAbilityPhaseSystem` drive animation action layer
   in `AnimSystem` and clear on completion/interruption.

## Current State (Implemented)
### Core Ability Model
- `AbilityDef` defines category, allowed slots, targeting model (declared), hit delivery,
  windup/active/recovery ticks (60 Hz), costs, cooldown, forced interrupt causes, tags, and base damage.
- `AbilityCatalog` registers Eloise abilities and shared enemy abilities.
- `AbilitySlot` supports primary, secondary, projectile, mobility, spell, jump (fixed).

### Loadout + Validation
- Loadout has non-null IDs for all configured slots (no "none" semantics).
- `LoadoutValidator` enforces:
  - Ability slot compatibility (`allowedSlots`).
  - Required weapon types (`requiredWeaponTypes`) vs payload provider types.
  - Weapon category validity + two-handed conflicts.
  - Missing IDs are treated as catalog errors.

### Deterministic Input + Buffering
- Inputs are tick-stamped commands; held axes/aims are pre-buffered in the Game layer.
- `AbilityActivationSystem`:
  - Prevents new commits while an ability is active.
  - Buffers one input during Recovery (latest wins).
  - Resolves projectile slot via a single input channel and builds `ProjectileIntentDef`
    using an explicit payload provider (throwing item or spell book).

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
| Self-centered and defensive abilities | PARTIAL | `SelfHitDelivery` executes and can apply status profiles; defensive mechanics still incomplete. |
| Projectile payload ownership | OK | Ability defines hit shape; payload provider (throwing item or spell book) provides stats/procs via `HitPayloadBuilder`. |
| Input buffering in recovery only | OK | Implemented via `AbilityInputBufferStore`. |
| Spell slot support | OK | Spell slot is validated and routed in activation; HUD disables invalid slots (reason display still pending). |
| Auto-target (future) | PARTIAL | Implemented for `TargetingModel.homing` at commit-time (deterministic nearest hostile, facing fallback); in-flight retargeting is still not implemented. |

## Gaps and Deviations
1. Targeting model coverage is still partial.
   - `TargetingModel.homing` is enforced in `AbilityActivationSystem` for commit-time lock-on.
   - Hold-to-aim vs commit-on-release is currently still orchestrated by input scheduling,
     not a dedicated Core targeting state machine.

2. Defensive/self effects are still limited.
   - `SelfHitDelivery` executes and can queue status profiles, but block/parry mechanics
     still need explicit effects or status definitions.

3. Spell slot wiring now exists; UI may still need clearer invalid/locked feedback.

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

2. Expand `SelfHitDelivery` effects.
   - Add explicit block/parry behavior or status-driven defenses.
   - Ensure defensive effects are reflected in snapshots/events.

3. Surface spell slot validity in UI.
   - Show invalid slot reasons and provider requirements.

4. Apply `HitPolicy` in hit systems.
   - Encode once-per-target vs every-tick and align with `HitOnceStore` usage.
