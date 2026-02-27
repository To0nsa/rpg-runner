# Ability System Design

Design contract for authored abilities and slot loadouts.

## Core Contracts

1. Slots are never empty: every slot always has a valid equipped ability.
2. Ability structure lives in ability defs; payload comes from equipped gear/spellbook.
3. Deterministic modifier order is fixed: ability -> gear payload -> passive/global.
4. Mobility preempts combat: dash/jump input cancels queued/active combat intents.

## Ability Model

An ability defines:

- slot legality (`allowedSlots`)
- category (`melee`, `ranged`, `mobility`, `defense`, `utility`)
- targeting model and input lifecycle
- timing (`windup/active/recovery`)
- costs + cooldown group
- hit delivery (`melee`, `projectile`, or `self`)
- optional charge profile

## Slots

Current ability slots:

- `primary`
- `secondary`
- `projectile`
- `mobility`
- `jump`
- `spell`

### Slot Notes

- `projectile` slot abilities use the projectile payload source selected for that slot (throwing weapon or spell projectile from spellbook grants).
- `spell` slot currently hosts spellbook-granted self-utility abilities.
- `jump` is a fixed action slot but still authored as abilities (`eloise.jump`, `eloise.double_jump`).

## Targeting and Input Lifecycle

- `tap`: commit on press
- `holdRelease`: commit on release
- `holdMaintain`: commit on press, remain active while held

Targeting models used in current content:

- `none`
- `directional`
- `aimed`
- `aimedLine`
- `aimedCharge`
- `homing`

## Timing and Cooldown Policy

- Costs are paid at commit time.
- Default cooldown behavior: starts at commit.
- Exception: `holdToMaintain` abilities defer cooldown start until hold ends (release, timeout, or stamina depletion).

## Interruptions

Default forced interrupt causes are:

- `stun`
- `death`

Some abilities also opt into `damageTaken` (for example charged variants).

## Input Buffering

- One buffered combat input is stored (latest wins).
- Buffer is consumed on the first valid frame after recovery.
- Buffer is cleared when mobility preempts combat or forced interruption clears active/transient state.

## Current Eloise Equivalence Pairs

- Offensive mirror: `eloise.bloodletter_slash` <-> `eloise.concussive_bash`
- Homing mirror: `eloise.seeker_slash` <-> `eloise.seeker_bash`
- Defensive mirror: `eloise.riposte_guard` <-> `eloise.aegis_riposte`

## Acceptance Criteria

- Every slot triggers exactly one equipped ability.
- Illegal slot/gear/ability combinations are blocked by loadout validation.
- Ability commit, cooldown, and interruption behavior is deterministic and slot-consistent.
