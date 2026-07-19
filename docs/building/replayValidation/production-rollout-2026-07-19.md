# Replay Validator Pre-Release Production Rollout

Date: July 19, 2026  
Project: `rpg-runner-d7add`  
Region: `europe-west1`  
Status: Successful; canary and controlled fault-drill cleanup completed with
zero residual synthetic data

## Decision and scope

There is no staging project and the game has no released users. The repository
owner approved production as the controlled pre-release verification
environment for non-destructive smoke and disposable-account canary work.

The owner later authorized an explicit pre-release fault-drill window.
Lease-expiry and retry-exhaustion work used a temporary private service and
queue; the other drills used bounded disposable data and briefly paused empty
production queues. Detailed evidence is in
[Pre-Release Fault Drills](pre-release-fault-drills-2026-07-19.md).

## Source and artifact

- Source commit:
  `815aaddebb077429ea52774d2bb86e3a76a217c4`
- GitHub `Replay Validator` push workflow run 1: success
- GitHub `Functions` push workflow run 1: success
- Exact source was exported with `git archive` before the release image build.
- Local exact image:
  `replay-validator:commit-815aadde-exact`
- Local/registry manifest digest:
  `sha256:54aa8c6b75da9cad8396acbb3c6abfdb398a7f8a42cfbb06b68157cb0128103d`
- Artifact Registry tag: `commit-815aadde`
- Runtime identity: UID/GID `65532`
- Trivy 0.72 Critical/High result: zero findings

The previous rollback point was revision `replay-validator-00023-hsn`, digest
`sha256:23553aa0523fd2e1d92dea864458f58dd4973cd187ca989384a9f6f621f65e38`.

## Conflict-classifier verification

The committed classifier handles:

- HTTP 409 and 412 conflicts;
- structured HTTP 400 Firestore `FAILED_PRECONDITION`;
- the production Firestore base-version mismatch message when the generated
  client omits the structured body;
- arbitrary HTTP 400 `INVALID_ARGUMENT` as non-conflict.

Production-shaped fixtures cover lease acquisition, accepted/rejected/internal
error atomic handoffs, and retry release. Lease acquisition performs at most
two immediate read/precondition attempts before returning durable task retry.
`dart analyze` passed and all 75 replay-validator tests passed.

The exact successful commit is deployed. The earlier naturally observed status
400 response supplied the production fixture. A later nine-delivery live
contention drill produced one controlled retryable 503, eight idempotent 202
responses, no unclassified 500, and terminal validation on attempt 1.

## Monitoring rollout

The idempotent apply was run twice. The second run updated the same resources
and created no duplicate display names.

Four log metrics are deployed:

- `replay_validator_validation_retries`
- `replay_validator_projection_retries`
- `replay_validator_internal_errors`
- `replay_validator_resource_rejections`

Ten enabled policies use the existing production email channel:

- replay validation retry activity;
- projection retry activity;
- terminal validation internal error;
- replay resource-limit rejection burst;
- replay-validator HTTP 5xx;
- unhealthy startup/liveness probe;
- sustained validator memory pressure;
- validation queue backlog over 15 minutes;
- projection queue backlog over 30 minutes;
- replay repair or reconciliation job failure.

Google Monitoring accepted every native metric and log-metric filter. A later
isolated exact-match delivery policy opened an incident and delivered the
expected email to the verified recipient; the temporary policy was deleted
without changing production alert routing.

## Production deployment

Revision `replay-validator-00024-rzt` serves 100% of traffic by immutable
digest. Its checked configuration is:

- 1 CPU and 512 MiB memory;
- 240-second timeout;
- concurrency 1;
- maximum 10 instances;
- validator service account;
- startup `/ready`;
- liveness `/live`;
- private invocation only.

Both Cloud Tasks queues were reconciled to their checked-in OIDC target,
retry/backoff, rate, and concurrency policy.

## Smoke and canary evidence

- Cloud Run recorded startup `/ready` 200.
- Cloud Run repeatedly recorded liveness `/live` 200.
- Unauthenticated `/live`, `/ready`, validation, and projection requests
  returned 403.
- Both queues were empty after the canary.
- The new revision emitted no 5xx or error-severity entry during the rollout
  verification window.
- Native Cloud Monitoring reported a healthy startup-probe series for the new
  revision.

The disposable production canary verified:

- authority-time and identity negative checks;
- idempotent run creation;
- a valid replay reached terminal `validated`;
- the valid reward reached `final`;
- leaderboard projection completed;
- an active ghost manifest and downloadable ghost bytes were produced;
- an invalid seed replay reached terminal `rejected`;
- the invalid reward was revoked;
- the invalid replay did not affect the leaderboard.

The canary requested its own account deletion. The scheduled bounded deletion
workflow advanced without a recorded cleanup error; this record intentionally
contains no user, run-session, board, or task identifiers.

### Deletion closure evidence

A read-only follow-up at `2026-07-19T16:10:29Z` checked the complete canary and
the earlier synthetic account created by an interrupted canary setup:

- both deletion requests were `complete` at `delete_auth` after their final
  reconciliation pass and retained the configured completion expiry;
- exact queries found zero matching profiles, display-name claims, ownership
  state or idempotency records, quota state, run sessions, validated runs,
  reward grants, flat ghost records, player-best projections, ghost manifests,
  or materialized leaderboard-view entries;
- exact Storage checks found zero pending replay objects, validated replay
  objects, or published ghost objects;
- the completed `delete_auth` checkpoint means Firebase Auth deletion
  succeeded or the account was already absent. The earlier exact Auth lookup
  for these same synthetic account hashes also returned zero users, as recorded
  in the
  [Functions production-verification record](../functions-audit-remediation/production-verification-2026-07-19.md).

The two retained completion tombstones are bounded workflow evidence, not
residual player data, and remain subject to the configured 30-day expiry.

## Controlled fault-drill evidence

The separately recorded fault window verified:

- bounded concurrent validation lease contention;
- generation-pinned rejection after a finalized path overwrite;
- top-10 and ghost recovery after partial state removal and duplicate
  projection delivery;
- cleanup of 105 expired manifests across the Firestore page boundary;
- two-attempt task exhaustion on a private temporary queue;
- expired-lease reclaim by deployed scheduled validation repair;
- successful recovery on the production worker;
- verified alert email delivery and temporary-policy cleanup;
- complete deletion of four disposable accounts with zero residual Firestore
  or Storage data.

The production revision, image digest, resource policy, queue retry/OIDC
configuration, and traffic remained unchanged. Both temporary resources were
deleted, and both production queues were `RUNNING` and empty afterward.

## Result

The conflict-classifier fix, validator/projection monitoring, exact-commit
artifact, corrected probes, queue policy, and pre-release production canary are
deployed and healthy. The controlled recovery drills converged and left no
synthetic residue. The rollback revision remains available if a later
observation crosses an alert threshold.
