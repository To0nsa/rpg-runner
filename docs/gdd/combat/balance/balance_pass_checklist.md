# Balance Pass Checklist

## Pre-pass

- [ ] Confirm contract docs are up to date.
- [ ] Confirm lane docs match current authored catalog.
- [ ] Select target invariant(s) for this pass.
- [ ] Select scenario IDs from `scenario_matrix.md`.

## During pass

- [ ] Change one coherent variable set (not unrelated values).
- [ ] Run deterministic scenarios with fixed seed/commands.
- [ ] Record raw outcomes for each scenario.
- [ ] Compare against primary invariant and guardrails.

## Post-pass

- [ ] Update `tuning_log.md` with rationale and results.
- [ ] Mark pass/fail per invariant.
- [ ] Note open risks (dominance, dead picks, pacing issues).
- [ ] Define next pass scope (or close if stable).

## Release gate

- [ ] No strict dominant ability in standard scenarios.
- [ ] Mirrored pairs satisfy their parity target.
- [ ] Reliability gains pay explicit tax.
- [ ] Resource economy still supports intended rotation diversity.

