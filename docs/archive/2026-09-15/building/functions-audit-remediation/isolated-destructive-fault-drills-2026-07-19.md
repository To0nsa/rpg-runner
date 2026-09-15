# Isolated Destructive Fault-Drill Evidence — July 19, 2026

## Scope and safety boundary

The repository owner waived a separate staging project because none exists and
the game has no live users. Production remains the deployment canary, but this
waiver does not justify deliberately corrupting or interrupting production.

Faults were therefore injected only into isolated Firestore-emulator tests and
in-memory replay-validator dependencies. The tests invoke backend workers
directly, so they model a closed or absent client: all recovery is owned by
durable server state, retries, triggers, or scheduled repair.

## Account-deletion crash seam

`processAccountDeletion` now accepts an optional internal `afterStage` test
hook. It runs after a stage's side effects and before the durable checkpoint
commits. Production call sites do not supply the hook, and it is not exposed by
the callable contract.

The drill iterates the ordered 23-stage deletion inventory. For every stage it:

1. seeds a stage-specific Firestore, Storage, Auth, leaderboard, or ghost
   artifact where applicable;
2. lets the stage perform its destructive side effects;
3. injects a crash before checkpoint commit;
4. verifies that the tombstone is `retryable` at the unchanged stage;
5. verifies that the targeted artifact is already absent;
6. retries with no client activity; and
7. verifies idempotent replay, checkpoint progress, and cleared error fields.

This includes Auth disable and final Auth deletion, top-level UID queries,
nested ownership and board collections, pending and validated replay objects,
projection views, and all supported legacy ghost ownership fields.

The existing deletion matrix separately proves tombstone-first mutation
blocking, multi-page erasure, concurrent worker serialization, late
reinsertion detection, retryable Storage failure, missing Auth/data tolerance,
and final Auth deletion only after reconciliation.

## Cross-lane drill matrix

| Lane | Injected condition | Recovery assertion |
| --- | --- | --- |
| Replay upload | Upload-grant/finalize expiry | Terminal expiry commits before the callable error; provisional reward is revoked atomically. |
| Replay upload | Validation-task enqueue failure | The uploaded session remains durable and immediately eligible for server repair. |
| Validation repair | Enqueue failure and expired lease | Repair preserves retry eligibility and token-fences stale workers. |
| Settlement | Immediate dispatch failure | The accepted settlement handoff remains durable for Eventarc/scheduled fallback. |
| Settlement | Immediate, Eventarc, and repair race | Exactly one canonical reward is credited. |
| Settlement repair | Poisoned first page | The contradiction is quarantined without payment and cannot starve the valid next page. |
| Settlement repair | Transient infrastructure failure | The cursor wraps and the pending settlement later converges. |
| Projection | Enqueue/write failure after partial progress | The cursor/checkpoint does not advance incorrectly; retry converges without changing validation or settlement. |
| Leaderboard | Concurrent better/worse candidates and compare-and-swap conflict | The better best survives and the top-10 view is recomputed before completion. |
| Validator | Lease conflict, transient replay load, retry exhaustion, and grace-window handling | Failures remain structured retries or follow the documented terminal incident path; accepted runs cannot bypass settlement. |

## Results

- Focused account-deletion emulator suite: 8/8 passed, including all 23
  post-side-effect crash positions.
- Focused Functions dispatch, expiry, repair, quarantine, and projection files:
  all passed in isolated Firestore-emulator runs.
- Complete Functions suite: 171/171 passed on Node 24.
- Focused replay-validator fault matrix: 48/48 passed.
- No production fault, data corruption, queue outage, or alert-threshold change
  was manufactured.

The expected emulator logs include one retryable deletion event per injected
stage and transaction-contention warnings during the concurrent-worker case.
Those are assertions of the drill, not suite failures.

## Deployment provenance

The crash seam is inert in production. Completion also uses a non-merge
document replacement so an unexpected legacy/future diagnostic cannot survive
the four-field compaction. The two deletion functions were redeployed so
deployed source matches the validated source:

- Functions source/configuration hash:
  `5bab5424c9d8aee530f9bddf4ef536dfdadaf26c`;
- `accountDelete`: `accountdelete-00010-ted`;
- `accountDeletionRepair`: `accountdeletionrepair-00004-wiy`.

Both functions reported `ACTIVE` with all traffic on the latest revision. The
one-minute repair scheduler remained `ENABLED`. The final production inventory
at `2026-07-19T17:13:27Z` reported nine compact completions, zero active,
zero retryable, zero non-minimal, zero missing-expiry, and zero expired
completion records.

## Outcome

The destructive-fault acceptance scope is satisfied under the no-staging
waiver. Recovery no longer depends on an authenticated client remaining open,
and every account-deletion stage has explicit crash-after-side-effect evidence.

This evidence does not claim that a deliberate production outage occurred.
Production verification remains limited to safe canaries, live configuration,
normal scheduler execution, and post-deployment health/inventory checks.
