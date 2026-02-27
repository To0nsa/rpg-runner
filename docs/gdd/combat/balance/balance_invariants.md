# Balance Invariants

## Purpose

Defines parity targets and guardrails for current ability families.

## Core Invariants

### Projectile Family

Set:

- `eloise.snap_shot`
- `eloise.quick_shot`
- `eloise.skewer_shot`
- `eloise.overcharge_shot`

Primary invariant: `DPRS` (damage per resource per second).

Guardrails:

- burst windows should not dominate sustained windows by default
- homing/reliability options must pay explicit tax
- no strict dominant pick across standard scenarios

### Primary vs Secondary Offensive Mirrors

Pairs:

- `eloise.bloodletter_slash` vs `eloise.concussive_bash`
- `eloise.seeker_slash` vs `eloise.seeker_bash`
- `eloise.bloodletter_cleave` vs `eloise.concussive_breaker`

Primary invariant: sustained throughput parity in equivalent encounter setups.

Guardrails:

- differentiation comes from explicit status/proc payloads
- no hidden uptime/commit advantage outside authored taxes

### Defensive Mirrors

Pairs:

- `eloise.riposte_guard` vs `eloise.aegis_riposte`

Primary invariant: equivalent defensive value per cooldown window.

Guardrails:

- riposte reward parity
- no one-sided uptime without explicit tax

### Mobility Family

Set:

- `eloise.dash`
- `eloise.roll`
- `eloise.jump`
- `eloise.double_jump`

Primary invariant: mobility payoff scales with risk/cost and does not break runner pacing.

Guardrails:

- stronger reliability/control effects require explicit cooldown/resource tax
- mobility should not invalidate core obstacle/jump cadence

## Metric Definitions

- `TTK`: time to kill against fixed target profile
- `Burst Window`: damage during first `N` ticks after commit
- `Sustained Throughput`: average damage over a fixed long window
- `Resource Efficiency`: total damage / total resource spent

Use fixed seeds and deterministic command streams for every pass.

## Pass Criteria

1. Each mirrored set has a measured primary invariant delta.
2. Intentional asymmetries are explicitly documented as tax axes.
3. No unresolved dominance in the scenario matrix.
