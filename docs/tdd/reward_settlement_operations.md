# Reward Settlement Operations

This document describes the implemented operational contract for verified run
rewards. It applies to the Functions settlement authority, the Cloud Run replay
validator, and the Firestore documents they share.

## Authority and delivery

`settleAcceptedRunSession` is the only code path that changes canonical
`progression.gold` for a validated replay. It accepts no player-supplied reward
amount and atomically writes canonical ownership, the reward grant, and the
terminal run session.

The validator commits an accepted run, `settlement_pending` grant, and
`settlement_pending` session before requesting the IAM-only immediate endpoint.
The immediate request is the latency path. Firestore/Eventarc and the five
minute `runSettlementRepair` schedule are independent delivery fallbacks. They
all call the same transaction and must remain enabled.

Validation lease acquisition makes at most two immediate compare-and-set
attempts. This absorbs the expected race between replay finalization and a
freshly dispatched validation task without turning it into Cloud Tasks' 30
second minimum retry. A second conflict remains a retryable task outcome; the
worker never steals an active, unexpired lease.

Before validation starts, upload/finalize expiry and scheduled cleanup share one
transactional terminalization helper. It writes server-authored
`expiredAtMs`/`terminalAtMs` fields and changes a matching
`provisional_created` or `provisional_visible` grant to `revoked_final` in the
same commit. A finalize enqueue failure deliberately leaves the run `uploaded`;
validation repair remains its durable dispatch recovery lane. If an old
provisional grant has no run session, or its run is already terminal, cleanup
marks it `revoked_final` after a 48-hour grace period. It never touches an
active validation grant.

An already terminal `validated` run is accepted as an idempotent no-op only
when its accepted run, settled grant, and canonical applied-grant id still
match. Any missing or contradictory record returns the explicit
`invariant_violation` outcome without changing gold; it is an operator incident,
not a retryable payout.

Every new accepted handoff sets
`settlementRepairDisposition = retryable`. The repair worker cursor-classifies
older pending sessions that predate the field. Its settlement query reads only
the explicit retryable lane in stable document-id order. A persisted-data
invariant transactionally changes the disposition to `quarantined` and records
the attempt time and incident reason without changing the session's
`settlement_pending` state, grant, or canonical wallet. Infrastructure failures
leave the disposition retryable; the five-minute schedule remains the retry
cadence.

## Observability contract

Functions emit Cloud Logging entries with message `run_settlement` and these
stable JSON fields:

| Event | Required fields | Meaning |
| --- | --- | --- |
| `settlement_transaction` | `deliverySource`, `outcome`, `durationMs`, `transactionAttempts`, optional `pendingAgeMs` | One settlement attempt. Outcomes are `settled`, `already_settled`, `not_ready`, or `invariant_violation`. |
| `settlement_eventarc_delivery` | `deliverySource`, `outcome` | Firestore fallback delivery. |
| `settlement_repair_scan` | `scannedCount`, `settledCount`, `classifiedCount`, `quarantinedCount`, `failureCount`, `retryablePendingCount`, optional `oldestRetryableAgeMs`, optional `pageCursor`, `noProgress` | Five-minute repair page, cursor progress, and backlog health. |
| `stale_settlement_repair` | `pendingAgeMs`, `outcome` | A repair attempt after the stale threshold. |
| `settlement_repair_failure` | `errorClass` | A retryable repair infrastructure failure. |
| `legacy_reward_grant_migration` | `outcome`, `scannedCount`, `settledCount`, `invariantViolationCount` | A bounded migration page. |
| `projection_enqueue` | `outcome` | Separate board projection task enqueue result. |

Cloud Run emits JSON logs with `event: replay_validator.dispatch`. Important
phases are `settlement_handoff` (duration from server finalize),
`settlement_dispatch_start`, `settlement_dispatch_outcome`,
`settlement_dispatch_fallback`, `projection`, and `projection_retry`.

No metric contains a uid, replay body, or player-facing error message. A run
session id is retained only as an incident correlation key.

## Dashboard and alerts

Create log-based metrics from the events above before broad rollout. The
dashboard must show:

- finalize-to-handoff from validator `settlement_handoff.durationMs`;
- handoff-to-terminal from `settlement_transaction.pendingAgeMs` where outcome
  is `settled`;
- immediate dispatch start/outcome/fallback rates and duration;
- settlement outcomes by `deliverySource`, including idempotent no-ops;
- stale repair age and result;
- retryable pending count/oldest age, quarantine count, cursor movement, and
  no-progress scans;
- invariant violations; and
- projection enqueue/retry latency separately from payout latency.

Initial alert policy:

- Page immediately for any `invariant_violation` or stale pending age over
  15 minutes.
- Page when no repair attempt succeeds within five minutes after that stale
  threshold.
- Warn when immediate fallback exceeds 5% over 15 minutes, or when its p95
  start-to-response time exceeds one second.
- Warn when the payout p99 exceeds 15 seconds over a representative 15-minute
  window. The initial p95 target is two seconds.
- Warn on sustained projection retries, but do not escalate them as payout
  incidents unless settlement metrics also fail.

The rollout owner records the observed p50/p95/p99 values for two weeks before
changing these thresholds or enabling any fast validation lane.

### Production alert deployment — July 19, 2026

The `rpg-runner-d7add` project has the following enabled Cloud Monitoring
policies, defined and reconciled by
`functions/monitoring/reward_settlement/apply_alerts.ps1`:

- settlement invariant violation (critical log-match alert);
- retryable reward pending longer than 15 minutes (critical log-match alert);
- immediate settlement fallback ratio above 5% in 15 minutes (warning); and
- p99 durable-finalize-to-settlement-handoff latency above 15 seconds in 15
  minutes (warning).

The latter two policies use only three low-cardinality user-defined log-based
metrics. Logs-based metrics start collecting only after their creation, so the
initial latency/rate windows intentionally have no historical backfill. All
four policies route to the `RPG Runner production alerts` email channel; confirm
the Google Cloud verification email before relying on inbox delivery. The
latency distribution uses 1.5-second linear buckets through five minutes, so
low-volume percentile alerts remain within about 1.5 seconds of the observed
handoff latency instead of overstating a sample from a broad bucket.

The same reconciliation script manages the `RPG Runner - Reward settlement`
Cloud Monitoring dashboard. It charts durable handoff percentiles, immediate
attempt/fallback activity and ratio, and validator 5xx responses. Three log
panels keep settlement decisions/pending age, repair/invariant signals, and
validator fallback/projection retries visibly separate without high-cardinality
metric labels.

### Planned replay-drill maintenance

Expected queue pauses, lease conflicts, or retry responses must use the bounded
`snooze_replay_drill.ps1` helper before the drill begins. It snoozes only the
payout-latency, validator-5xx, and validation-retry policies for an explicit
reason and a maximum of 60 minutes; it does not disable policy evaluation.
Use `-WhatIf` to verify the exact policy set before creating a snooze. Let the
snooze expire after the drill and acknowledge its known incidents through the
Monitoring console; never change a threshold or disable a policy to hide drill
signals.

### Client-closed production verification — July 19, 2026

The fresh competitive run
`run_1fc15abce1a949893a156bce9823e831850df1c4` was force-closed at Game Over
and then reopened. Its first validation Cloud Tasks delivery began just before
durable finalization, exercised the finalize-versus-lease race, and returned
`202` without a 30-second task retry. Durable handoff completed 1.15 seconds
after finalization; Eventarc applied canonical settlement 1.86 seconds after
finalization. The validator's concurrent immediate request later observed the
expected idempotent `already_settled` outcome. Board projection also completed
independently in 0.52 seconds.

## Stale settlement runbook

1. Find the `runSessionId` from a `stale_settlement_repair`,
   `invariant_violation`, or quarantined repair log. Inspect the session,
   matching validated run, grant, and canonical ownership together.
2. For a valid `settlement_pending` handoff, wait for or use **Run now** on the
   `runSettlementRepair` schedule. It invokes the canonical helper; never edit
   gold, grant lifecycle, applied-grant ids, or terminal run state manually.
3. If the helper reports `already_settled`, verify the canonical applied-grant
   id and leave the data unchanged. Duplicate delivery is expected.
4. If it reports `invariant_violation`, verify the session now has
   `settlementRepairDisposition = quarantined`. Preserve the documents and
   investigate the binding that failed. Repair requires a reviewed, idempotent
   migration or code change, never a compensating client award. An approved
   repair must restore all matching invariants before an operator explicitly
   returns the disposition to `retryable`.
5. For infrastructure failures, restore the immediate/Eventarc/repair delivery
   path. The durable pending handoff remains the recovery point.
6. Alert if the repair cursor does not move while retryable count is non-zero,
   or if quarantine count changes. Never bulk-unquarantine without preserving an
   export and incident disposition.

## Legacy migration

Normal canonical reads and ownership commands never reconcile grants. The
finite `runLegacyRewardGrantMigration` schedule is the only final legacy
adapter. During the one-time production cutover,
`LEGACY_READ_RECONCILIATION_ENABLED=true` temporarily preserves the previous
read-time repair behavior so deploying the migration cannot strand an older
grant. Set it to `false` only after the inventory and `apply` migration finish;
the compatibility branch is then removed after the rollback window.

Its environment-controlled mode defaults to `off`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `LEGACY_REWARD_GRANT_MIGRATION_MODE` | `off` | `inventory` records candidates without grant/canonical writes; `apply` performs idempotent repair. |
| `LEGACY_READ_RECONCILIATION_ENABLED` | `true` during migration | Temporary compatibility path; set to `false` only after verified `apply` completion. |
| `LEGACY_REWARD_GRANT_MIGRATION_BATCH_SIZE` | `64` | Bounded page size, clamped to 1–200. |
| `RUN_SETTLEMENT_STALE_THRESHOLD_MS` | `900000` | Stale-pending alert threshold in milliseconds. |
| `RUN_SETTLEMENT_REPAIR_BATCH_SIZE` | `64` | Bounded repair page size. |

Run `inventory` to completion first. Review invalid bindings and the count of
`validated_settled` grants absent from canonical applied-grant ids. Only then
deploy with `apply`; it uses the same applied-grant idempotency and weekly
progression hooks as new settlement. After its persisted migration cursor marks
the finite population complete, return the mode to `off`.

### Production record — July 18, 2026

The `rpg-runner-d7add` / `europe-west1` rollout completed inventory and apply:
11 grants scanned, 11 already applied, and zero repaired, terminalized, or
invariant-violating records. The deployment then set
`LEGACY_REWARD_GRANT_MIGRATION_MODE=off` and
`LEGACY_READ_RECONCILIATION_ENABLED=false`; a subsequent scheduled run confirmed
the migration is a no-op. The five-minute Cloud Scheduler job was then paused to
avoid ongoing no-op invocations; explicitly resume it before any future
maintenance migration (a later Firebase Functions deployment may re-enable it).

## Board projection retry boundary

Accepted board runs create a Firestore-triggered Cloud Task in the dedicated
`replay-projection` queue. It calls `POST /tasks/project` with the task service
identity. That endpoint projects leaderboard state and then publishes ghosts.
A projection failure returns HTTP 503 so Cloud Tasks retries it; it never
rewinds validation, changes a reward grant, or alters canonical gold.

The projection queue must not use the validation queue's `/tasks/validate` URI
override. Grant `sa-replay-task-dispatch` `roles/run.invoker` on the validator
Cloud Run service and permit the Functions service account to create projection
tasks and impersonate that dispatch identity.

Firestore/Eventarc delivery is a separate authenticated hop. In addition to
project-level `roles/eventarc.eventReceiver`, the control-plane service account
`sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com` requires
`roles/run.invoker` on both generated Cloud Run services:
`runprojectiononaccepted` and `runsettlementonhandoff`. The latter is the
durable settlement fallback; the former is required before an accepted ranked
run can enqueue projection work. Verify these two bindings after every Firebase
Functions deployment. `eventReceiver` alone does not authorize the Cloud Run
invocation.
