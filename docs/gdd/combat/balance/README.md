# Combat Balance Framework

## Purpose

This folder defines the balancing workflow used after system contracts are
stable. It separates:

- design rules (stable contracts),
- authored ability values (catalog),
- tuning iteration artifacts (metrics, scenarios, logs).

## Files

- `balance_invariants.md`: numeric invariants and guardrails by ability set.
- `scenario_matrix.md`: test scenarios used for balancing validation.
- `ability_tuning_template.md`: template for defining/finalizing one ability.
- `balance_pass_checklist.md`: repeatable checklist for one tuning pass.
- `tuning_log.md`: chronological record of tuning decisions/results.

## Recommended Workflow

1. Freeze/update design contracts in `docs/gdd/combat/abilities/`.
2. Update authored values in Core (`ability_catalog.dart`) and lane docs.
3. Run the scenario matrix and compare results against invariants.
4. Record any tuning decision in `tuning_log.md`.
5. Repeat until all invariants and guardrails are satisfied.

## Ground Rules

1. Never tune by feel only; always attach a scenario result.
2. Keep one source of truth per layer:
   - contracts in system docs,
   - values in catalog + lane docs,
   - rationale in tuning log.
3. If a value change breaks a contract, update contract first or reject change.

