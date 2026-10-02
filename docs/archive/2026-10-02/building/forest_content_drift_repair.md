# Forest content drift and traversal repair

Created: October 2, 2026. Branch: feature/npc-section-guards.
Status: complete. Implemented at `474aae70`; all required local checks passed.
See [verification](../../../verification/forest-content-drift-repair.md).

The user requested closure of the inherited Forest generator drift and four
seeded traversal failures. Keep unrelated master checkout changes untouched.

## Diagnosis and approaches

Regeneration reproduced Grojib/Hashash failures at seeds 7 and 2026 on
forest_rocky_grove_easy_008. Both stopped before a graph-planned takeoff while
their complete capsules collided with a steep face. Grounded placement lifted
above eligible facets sharing a broad chain ID even when ineligible intervening
facets separated them. This admitted clear airborne poses as grounded support.

Options considered: move/simplify the local rock; change enemy capabilities;
correct shared support placement and executable takeoff planning. Prefer the
shared correctness fix because the authored obstacle is physically jumpable
and actor capability changes would affect unrelated balance.

## Acceptance

- [x] Placement cannot lift a grounded pose across an ineligible chain segment;
  connected walkable facets continue to support complete capsules.
- [x] The four original seed/enemy failures and an exact rock sequence pass
  with continuous catalog motion and unchanged finish/arrival controls.
- [x] Generated outputs match current authored source through generator dry-run.
- [x] Full 27-case traversal matrix and controls pass on fresh generated content.
- [x] Core/Flutter/worker and generator checks pass; compiled worker benchmark
  recorded with its actual horizon and environment limitations.
- [x] Technical/gameplay docs and archived finding describe delivered behavior;
  pending compatibility 2026.10.1 remains coordinated across client/backend/worker.

## Work sequence

1. Reproduce from freshly generated content and isolate support/graph/execution.
2. Correct the owning navigation rules and retain focused regression coverage.
3. Validate all current-source routes, regenerate outputs and publish evidence.

No deployment is requested. No marker removal, actor teleport, capability widening
or traversal-budget change may mask the failures.

## Implementation validation

- Core analysis and app analysis: no issues.
- Core package: 741 tests passed.
- Traversal matrix and controls: 48 checks passed, including all 27 scheduled
  cases and four exact four-chunk rock routes.
- Flutter Core and generator targets: 402 tests passed.
- Replay worker analysis: no issues; 174 tests passed.
- Generator dry-run: no blocking issues or stale generated outputs.
- Worker executable compiled; the strict 36,000-tick benchmark passed all nine
  gates at clean implementation `474aae70`. The raw host report and tested
  horizons are linked from verification. This is local no-enemy evidence;
  release-image container performance and signed-in smoke remain release work.

No authored geometry, collider/profile limits, actor state continuity, finish
controls, arrival tolerances or tick budgets changed.
