# Replay Validator Pre-Release Fault Drills

Date: July 19, 2026  
Project: `rpg-runner-d7add`  
Region: `europe-west1`  
Status: Successful; temporary resources removed and synthetic data erased

## Scope and authorization

The game has no released users and no staging project. After the successful
exact-image rollout, the repository owner authorized the remaining
replay-validator recovery drills in the controlled pre-release production
environment.

The drills ran from approximately `2026-07-19T16:24Z` through
`2026-07-19T17:09Z`. Exact account, run-session, board, task, object, and
temporary-resource identifiers are intentionally omitted. Only aggregate and
one-way-hash-free evidence is retained here.

## Safety boundaries

- Both production task queues were empty before fault injection.
- Every player-shaped fixture used a disposable anonymous account.
- The validation and projection queues were paused only while preloading a
  bounded synthetic race, then restored to `RUNNING`.
- The lease-expiry drill used a separate private Cloud Run service and a
  separate two-attempt queue.
- The temporary service used the exact production image and validator service
  identity. Its only material behavioral override was a 1 ms validation lease.
- No production alert threshold, queue retry policy, service traffic split,
  IAM binding, or validator revision was changed.
- Account deletion used the deployed tombstone-first workflow and its normal
  final reconciliation and signed-upload quiet-period rules.

## Baseline

Before the drills:

- revision `replay-validator-00024-rzt` served 100% of traffic;
- the deployed image digest was
  `sha256:54aa8c6b75da9cad8396acbb3c6abfdb398a7f8a42cfbb06b68157cb0128103d`;
- validation and projection queues were `RUNNING` and empty;
- validation used 8 attempts and projection used 100 attempts;
- both queues used the checked OIDC dispatch identity and validator audience;
- Cloud Run used 1 CPU, 512 MiB, 240-second timeout, concurrency 1, and
  maximum scale 10.

## Concurrent validation lease drill

The empty validation queue was paused while one finalized disposable run and
eight duplicate deliveries were preloaded. Resuming the queue released nine
deliveries against the same run:

- one request returned controlled retryable HTTP 503;
- eight requests returned idempotent HTTP 202;
- no request produced an unclassified HTTP 500;
- structured telemetry recorded one retryable lease result;
- the authoritative run reached `validated` on validation attempt 1.

The canary harness's short terminal wait elapsed while the queue was
intentionally held, so it requested account deletion before the delayed
delivery completed. The later validation write was still erased by the
deletion workflow's repeated and final reconciliation passes.

The production API does not expose the raw Firestore response that lost the
race. Closure therefore combines this live contention outcome with the
production-shaped HTTP 400/`FAILED_PRECONDITION` classifier fixtures: live
contention produced the bounded retry path and no unhandled 500.

## Finalized-generation overwrite drill

The validation queue was paused after a replay finalized and bound its exact
positive Storage generation. The same object path was then overwritten:

- Storage returned a different latest generation;
- the run session remained bound to the original finalized generation;
- the altered latest generation was not rebound into the session;
- validation produced terminal rejected evidence with
  `replay_generation_unavailable`;
- no accepted terminal result, settlement handoff, leaderboard projection, or
  ghost projection occurred;
- the task route emitted no 5xx response.

This verifies fail-closed behavior when finalized bytes become unavailable.
An overwritten latest object cannot replace the generation-bound validation
authority.

## Partial and concurrent projection recovery

A verified accepted canary run was held before account deletion. The drill:

1. removed its active ghost manifest while preserving source and destination
   objects;
2. removed the board's materialized top-10 view;
3. inserted 105 valid, already-expired demoted ghost manifests under a
   disposable prefix;
4. released two duplicate run-projection tasks and two duplicate board-level
   reconciliation tasks concurrently.

All four tasks completed without a retry or error-severity entry. Independent
queries then confirmed:

- the top-10 view was rebuilt;
- the canary entry was present;
- the active manifest was recreated and exposed;
- the ghost object remained available;
- all 105 expired manifests were removed.

The manifest repository page size is 100, so 105 fixtures exercised the second
Firestore page. The board tasks were manual reconciliation deliveries, not a
new player submission, proving cleanup does not depend on another run.

## Lease expiry, retry exhaustion, and scheduled recovery

A temporary private validator service used the exact production image with a
1 ms validation lease. Its isolated queue allowed two attempts with one-second
backoff. One otherwise valid finalized replay was moved from the paused
production queue to this queue.

Observed behavior:

- both attempts returned HTTP 503 with structured `lease_conflict` telemetry;
- the temporary task exhausted its two-attempt budget and disappeared;
- the session retained attempt 2 and an expired/released validation lease;
- deployed `runValidationRepair` reclaimed the session and advanced
  `validationTaskGeneration` to 1;
- one repair task appeared on the paused production queue;
- after the production queue resumed, the exact production worker completed
  the run as `validated` on attempt 3;
- the production validation queue returned to empty.

The temporary queue and service were deleted. Post-cleanup inventory found zero
temporary replay-drill queues and zero temporary replay-validator services.

## Monitoring alert delivery

The production notification channel is enabled and `VERIFIED`. A separate
exact-match temporary log alert in the same verification window opened the
expected incident, delivered the expected email, and was confirmed by the
recipient. The temporary delivery policy was then deleted.

Post-test Monitoring inventory confirmed:

- 14 enabled production policies still reference the channel;
- the replay-validator metrics and policies remain enabled;
- no temporary notification-delivery policy remains;
- no production condition, threshold, or routing rule was changed.

## Synthetic cleanup

Four disposable accounts covered contention, projection/pagination, overwrite,
and lease-expiry recovery. The deletion worker was accelerated only by invoking
its existing Scheduler job; its transactional leases, bounded page size,
repeated passes, signed-upload quiet period, final pass, Auth deletion, and
completion retention were not bypassed.

All four requests were observed in pass 3 with `finalPass: true` before their
minimal completion records were written. Final evidence at
`2026-07-19T17:09Z` found:

- four terminal `complete` records;
- completion timestamp and future expiry on every record;
- no recorded cleanup error;
- zero matching profiles, display-name claims, ownership/idempotency records,
  quota state, run sessions, validated runs, reward grants, flat ghost records,
  player-best projections, ghost manifests, or materialized-view entries;
- zero pending replay objects;
- zero generation-bound replay objects associated with the drill windows;
- zero associated ghost objects.

The retained minimal completion records are bounded workflow evidence, not
player data.

## Restored production state

After all drills:

- revision `replay-validator-00024-rzt` still served 100%;
- the production image digest and Cloud Run resource policy were unchanged;
- validation and projection queues were `RUNNING` and empty;
- production queue retry and OIDC policies were unchanged;
- zero temporary services and queues remained;
- both immutable replay-validator audit blob hashes were unchanged.

## Finding impact

This evidence closes the deployed verification gates for:

- `RV-C01`: expiring lease and automatic repair;
- `RV-H01`: task exhaustion and scheduled recovery;
- `RV-H02`: generation-pinned overwrite rejection;
- `RV-H03`: duplicate/partial projection convergence;
- `RV-H09`: over-100 paginated ghost cleanup without a new submission;
- `RV-M03`: alert-channel delivery and cleanup;
- `RV2-M02`: bounded production lease contention with no unclassified 500.

It does not claim closure for deployed decompression/resource-limit stress,
internal-error grace terminalization, broad board-wide projection load,
compatibility retirement, or every atomic terminal-handoff fault point.
