# Scenario Matrix

## Purpose

Reusable scenario set for tuning and regression checks. Run these scenarios
whenever ability values change.

## Scenario Table

| ID | Scenario | Setup | Metrics |
|---|---|---|---|
| `S1` | Single-target neutral | 1 enemy, neutral resistance, flat lane | TTK, burst, sustained throughput |
| `S2` | Single-target high pressure | target can punish long windups | commit success rate, burst realized |
| `S3` | Multi-target clump | 3+ enemies clustered | total window damage, overkill waste |
| `S4` | Multi-target line | 3+ enemies aligned | piercing/line efficiency |
| `S5` | Mobility stress | frequent reposition demand | uptime, survival, mobility resource drain |
| `S6` | Resource starvation | constrained mana/stamina budget | DPRS, ability rotation viability |
| `S7` | Status-heavy opponent | incoming slows/stuns/DoT | execution reliability under disruption |
| `S8` | Resistance skew target | target has typed resistance/vulnerability | consistency of intended counters |

## Standard Test Conditions

1. Fixed tick rate and deterministic seed.
2. Same command stream per compared build.
3. Same enemy archetype/loadout unless scenario requires change.
4. Same duration window per scenario class.

## Reporting Format

For each scenario run:

- build/version identifier,
- ability/loadout tested,
- primary invariant result,
- guardrail observations,
- pass/fail and next action.

