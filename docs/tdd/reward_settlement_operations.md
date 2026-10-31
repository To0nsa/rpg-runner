# Reward Settlement Operations

This document describes the implemented operational contract for verified run
rewards. It applies to the Functions settlement authority, the Cloud Run replay
validator, and the Firestore documents they share.

## Per-run timing diagnostics

Client, Functions and validator emit JSON `event = run_reward_timing`, schema 1,
correlated by `runSessionId`. Each process supplies a `clockId`, increasing
`sequence`, `monoUs` and `utcMs`. Measured stages have paired `span` IDs,
`started` and `completed`/`failed` outcomes, and monotonic `durationUs`. A completed
operation can be an idempotent no-op; use the separate result/state event to
determine acceptance or payout. A missing end event means incomplete evidence,
not a zero-duration operation. Retried requests get distinct spans; worker stages
after lease acquisition include the validation attempt.

Client logging is enabled by default in the dev flavor (including release APKs)
and can be overridden with `--dart-define=RUN_REWARD_TRACE=true|false`. Other
flavors default off. Output goes to the app's local console/logcat, not Firebase
Analytics or an uploaded player log. Capture before playing; logcat rotation and
process death can lose evidence. Backend phase events use structured Cloud
Logging and are always enabled. No per-tick or per-frame log stream is emitted.

| Owner | Stages / meaning |
| --- | --- |
| Client | `run_end`; `local_replay_save` covers recorder finalization, encoding/compression and file save; `local_journal` covers auth and durable spool insertion; `spool_write` includes the persisted step, attempt and retry time. |
| Client | `submission_pump`, `spool_recovered`, `lifecycle`; `upload_grant`, `upload`, `finalize`, `status_poll` and `status_received`; `submission_failure` includes retryability. |
| Functions | `grant_handler`, `finalize_handler`, `status_handler` start after payload parsing and UID matching; they include account/quota checks and domain operations. `upload_metadata`, `finalize_commit`, `finalize_result`, `validation_enqueue` separate storage inspection, durable transaction completion and task creation. |
| Validator | `lease_acquire`, `replay_load_decode` (parent), `replay_download`, `replay_decompress`, `replay_json`, `replay_protocol_digest`, `replay_contract`, `replay_compute` (parent including Core setup/scoring), `replay_simulation` (tick loop), `archive_account_fence`, `replay_archive`, `handoff_commit`. |
| Settlement | Validator `settlement_request` observes the actual dispatch, with `settlement_response` for its result. Functions `settlement_commit` ends after the transaction returns; `settlement_result` distinguishes `settled` from duplicate/no-op outcomes and includes delivery source and transaction attempts. Existing rejection, fallback and repair metrics remain authoritative for those paths. |
| Client completion | `canonical_fetch`, `canonical_applied` (current account revision), `receipt_acknowledged`, then `gold_frame` / `xp_frame` and `gold_target_frame` / `xp_target_frame`. |

Frame observations wrap only the canonical hub account values and Game Over
wallet. Pending run gold and store prices cannot satisfy them. They require a
painted, current route in the foreground and an exact canonical revision/target
match. The target event means the displayed integer reached the canonical total;
XP can emit its first frame while still counting up. These are Flutter
post-paint frame observations, not GPU presentation timestamps or proof of human
attention. Framework callbacks run after the rendering pipeline flushes; see
[Flutter's post-frame contract](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html).
Pending presentation correlations are capped at 64 and cleared on account reset
or AppState disposal.
An unpainted revision superseded by another account update can remain unobserved;
do not label the missing sample as instant completion. Disposing or covering a
screen cannot create a visible-update event.

Compare `monoUs` only within the same `clockId`. Parent spans overlap their
children and must not be added together. UTC differences across client/server
need clock-offset uncertainty; across server instances they are wall-clock
approximations. Pair enqueue/lease events with Cloud Tasks and Cloud Run request
and startup logs: the gap includes dispatch scheduling, startup and handler
entry and is not pure queue time. Task execution may start before the enqueue
RPC returns. Startup before application entry cannot be measured by in-process
timers. Stored `finalizedAtMs`, `settledAtMs` and pending-age values are application
markers, not Firestore commit timestamps; completed transaction spans establish
commit acknowledgement. Existing aggregate settlement durations now use a
monotonic clock; the historical metric fields and their meanings remain intact.

Logging failures are swallowed at the sink boundary without changing operation
results or errors. Diagnostic data contains no UID, auth/session token, signed
URL, replay content or arbitrary exception message. Run IDs belong in log
payloads, never metric labels. Instrumentation overhead is included in observed
latency and must be considered when comparing instrumented and older samples.

## Authority and delivery

The native client uses the `runSubmission` callable with `operation` equal to
`grant`, `finalize`, or `status`. One deployed, scale-to-zero instance serves
these operations; the legacy exports remain available for installed clients.
Each operation retains its original payload, authentication, deletion fence and
quota. Ticket issuance stays in `runSessionCreate`, including its independent
release pause. There is no warm-instance reservation or keepalive timer.

After consuming a ticket for an actual run, AppState starts best-effort upload
permission preparation without awaiting it. The coordinator keeps at most four
owner/run-bound promises in memory, joins ongoing preparation, consumes the
permission once and renews on submission when less than 30 seconds remain or
the replay exceeds its content binding. Account reset/disposal clears this
cache; credentials are never persisted. Preparation failure cannot prevent play.
`upload_grant_prepare`/`upload_grant_reused` distinguish this path. Backend
`grant_account_guard`, `grant_quota`, `grant_transaction` and `grant_signing`
separate the remaining warm grant cost; quota enforcement precedes signing.

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
leave the disposition retryable; during pre-release cost containment the
15-minute schedule remains the retry cadence. Before public release, remeasure
this fallback path and restore the production cadence and alert timing.

## Client completion lifetime

`AppState` owns one foreground submission scheduler across run, hub and meta
routes. `RunnerGameWidget` observes status; disposing it does not stop upload,
verification or canonical wallet refresh. The app shell suspends scheduling
outside the resumed lifecycle and rediscovers the account's durable spool on
resume. Embedders forward this lifecycle using `setRunSubmissionForeground`.
Recovery waits for successful bootstrap before discovering the spool. A resume
event during failed sign-in cannot start another authentication attempt; explicit
bootstrap retry owns sign-in and starts discovery after success when foreground.
Developer Practice never activates the queue.

The queue deduplicates each run's in-flight operation, spaces background
requests by at least one second globally, and backs off delayed runs. Long-lived
pending runs share one status request per minute. A new run retains fast checks.
Upload retries preserve the coordinator's durable retry deadline. Account
changes, accepted deletion and disposal fence late status and ownership writes.

Submission recovery reconciles server state before repeating an interrupted
operation. An uploaded replay retains its object path and completion marker;
if finalization did not commit, only finalization repeats. If its response was
lost after commit, the client resumes server completion without issuing another
upload grant. Final receipts are persisted as awaiting acknowledgement even
when recovered from a retry. Transient failures back off for 2, 5, 15 and then
30 seconds before the existing longer schedule; throttling waits at least 30
seconds. Expired authentication preserves the pending replay for renewed auth.
Journal mutations serialize their read-modify-write operations so different
runs cannot erase one another's pending entries.

A final reward receipt stays in the spool until canonical ownership loads and
local pending selection is reapplied. Failed refreshes retry even after leaving
Game Over or restarting the app. Successful acknowledgement removes the receipt;
repeated status requests do not reload the same acknowledged reward. The app
announces newly verified gold without interrupting play. Provisional gold remains
unspendable; this client lifecycle cannot grant rewards.

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
- Page when no repair attempt succeeds within fifteen minutes after that stale
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
one-time production cutover used a bounded `inventory` then `apply` migration;
after verification, its runtime flags were disabled and the scheduled function
was removed. A future data migration must be introduced as a new, finite,
source-controlled operation with its own inventory, apply verification, and
retirement step. It must not reintroduce a dormant periodic production job.

The settlement repair configuration remains:

| Variable | Default | Purpose |
| --- | --- | --- |
| `RUN_SETTLEMENT_STALE_THRESHOLD_MS` | `900000` | Stale-pending alert threshold in milliseconds. |
| `RUN_SETTLEMENT_REPAIR_BATCH_SIZE` | `64` | Bounded repair page size. |

### Production record — July 18, 2026

The `rpg-runner-d7add` / `europe-west1` rollout completed inventory and apply:
11 grants scanned, 11 already applied, and zero repaired, terminalized, or
invariant-violating records. The deployment then set
`LEGACY_REWARD_GRANT_MIGRATION_MODE=off` and
`LEGACY_READ_RECONCILIATION_ENABLED=false`; a subsequent scheduled run confirmed
the migration is a no-op. The retired five-minute scheduled function was then
removed so it cannot create recurring Scheduler charges or be re-enabled by a
later Firebase Functions deployment.

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
