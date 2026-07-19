# Replay Validator Pre-Release Production Rollout

Date: July 19, 2026  
Project: `rpg-runner-d7add`  
Region: `europe-west1`  
Status: Successful; canary account deletion is progressing through the durable
cleanup workflow

## Decision and scope

There is no staging project and the game has no released users. The repository
owner approved production as the controlled pre-release verification
environment for non-destructive smoke and disposable-account canary work.

This record does not claim destructive crash, task-exhaustion, or large
concurrency fault injection. Those drills still require an isolated
environment or a later explicit production test window.

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
400 response supplied the production fixture, but this rollout did not force a
new concurrent precondition collision.

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

Google Monitoring accepted every native metric and log-metric filter. No
synthetic false incident was generated.

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

## Result

The conflict-classifier fix, validator/projection monitoring, exact-commit
artifact, corrected probes, queue policy, and pre-release production canary are
deployed and healthy. The rollback revision remains available if a later
observation crosses an alert threshold.
