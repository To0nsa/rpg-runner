# Balance Invariants

## Purpose

Define what must stay equivalent (or intentionally different) across ability
families so tuning stays coherent.

## Core Invariants

### Projectile Family

- Primary invariant: `DPRS` (Damage Per Resource Per Second)
- Guardrails:
  - burst window parity (short windows should not dominate sustained windows),
  - reliability tax visibility (homing/tap variants pay clear cost),
  - no strict dominant pick across standard scenarios.

### Primary vs Secondary Offensive Mirrors

- Pairs:
  - `eloise.sword_strike` vs `eloise.shield_bash`
  - `eloise.sword_strike_auto_aim` vs `eloise.shield_bash_auto_aim`
- Primary invariant: sustained throughput parity in equivalent encounter setups.
- Guardrails:
  - same role should not differ by hidden utility,
  - differentiation should come from explicit payload/proc differences.

### Defensive Mirrors

- Pairs:
  - `eloise.sword_riposte_guard` vs `eloise.shield_riposte_guard`
- Primary invariant: equivalent defensive value per cooldown window.
- Guardrails:
  - reward parity (counter window -> payoff),
  - no one-sided uptime advantage without explicit tax.

### Mobility Family

- Set:
  - `dash`, `roll`, `charged_aim_dash`, `charged_auto_dash`, `hold_auto_dash`
- Primary invariant: movement payoff must scale with risk/cost model.
- Guardrails:
  - stronger reliability or speed tiers require explicit stamina/cooldown tax,
  - mobility must not invalidate core runner pacing.

## Metric Definitions

- `TTK`: time to kill against fixed target profile.
- `Burst Window`: damage dealt during first `N` ticks after commit.
- `Sustained Throughput`: average damage over long fixed window.
- `Resource Efficiency`: total damage / total resource spent.

Use fixed seed and deterministic command streams for all metric collection.

## Pass Criteria

1. Every mirrored set has one primary invariant and measured delta.
2. Any intentional asymmetry is explicitly documented as a tax axis.
3. No unresolved dominance in the scenario matrix.

