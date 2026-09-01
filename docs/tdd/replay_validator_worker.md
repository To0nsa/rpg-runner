# Replay Validator Worker (What / How / Why)

This doc describes how the replay validator worker works today in `services/replay_validator`.

## 1) What it is

The replay validator worker is a Cloud Run HTTP service that consumes run validation tasks and deterministically validates replay uploads.

Main entrypoints:
- `GET /live`
- `GET /ready`
- `POST /tasks/validate`
- `POST /tasks/project`

Core runtime classes:
- `ReplayValidatorApp`
- `DeterministicValidatorWorker`
- `FirestoreRunSessionRepository`
- `GoogleCloudStorageReplayLoader`
- `FirestoreLeaderboardProjector`
- `FirestoreGhostPublisher`

---

## 2) Why it exists

The worker is the server-side authority that decides whether a submitted run is valid.

Why this separate worker model exists:
- Keeps validation deterministic and server-controlled.
- Decouples expensive replay simulation from callable latency budgets.
- Makes retries/idempotency explicit via Cloud Tasks + run-session lease state.
- Produces canonical artifacts (`validated_runs`, reward grants, leaderboard projection, ghost manifests).

---

## 3) End-to-end trigger flow

1. Client uploads replay blob and calls `runSessionFinalizeUpload`.
2. Backend records upload metadata, enqueues a Cloud Task for validator (`/tasks/validate`), then transitions state to `pending_validation`.
3. Cloud Tasks sends `POST /tasks/validate` with `runSessionId`.
4. `ReplayValidatorApp` parses body and calls `worker.validateRunSession(runSessionId: ...)`.

Task enqueue configuration uses:
- `REPLAY_VALIDATION_QUEUE_LOCATION` (default `europe-west1`)
- `REPLAY_VALIDATION_QUEUE_NAME` (default `replay-validation`)
- `REPLAY_VALIDATOR_TASK_URL` or `REPLAY_VALIDATOR_URL`

---

## 4) Worker pipeline (`DeterministicValidatorWorker`)

## 4.1 Input + lease acquisition

- Rejects empty `runSessionId` as `badRequest`.
- Acquires a validation lease through `RunSessionRepository.acquireValidationLease(...)`.
- Lease transitions state to `validating`, increments `validationAttempt`, and
  writes a cryptographically random token plus an expiry.
- Every validation-owned session/result transition must prove that exact,
  unexpired token. A stale worker cannot write after another delivery reclaims
  the lease.
- An active lease returns HTTP 503 so Cloud Tasks retries. An expired lease can
  be reclaimed with a new token. Already-terminal sessions remain idempotent
  successful no-ops.
- Firestore REST may represent an update-time precondition conflict as error
  code 400 with structured status `FAILED_PRECONDITION`. The repository treats
  only that exact structured status, plus 409/412, as contention; unrelated
  HTTP 400 input errors are not reclassified.

Accepted pre-lease states are intentionally permissive:
- `uploaded`
- `pending_validation`

This avoids races between task dispatch timing and finalize state transition.

## 4.2 Ticket-time and board authority

The worker treats ticket and upload timestamps as Unix epoch milliseconds and
rejects impossible authority metadata before loading replay bytes:

- `issuedAtMs` must be positive and `expiresAtMs` must be greater than it.
- Ticket lifetime must be exactly 24 hours.
- Issuance and replay finalization may be at most five minutes ahead of the
  worker clock to tolerate bounded infrastructure clock skew.
- Replay finalization must be at or after issuance and strictly before ticket
  expiry.
- Ranked ticket issuance must fall within the bound board's half-open
  `[opensAtMs, closesAtMs)` window.
- Missing or malformed ranked board window timestamps are rejected.

Queue delay after a valid finalize does not invalidate a ticket: validation may
run after `expiresAtMs` when the server-authored `finalizedAtMs` proves the
replay was finalized before expiry.

## 4.3 Immutable evidence and compatibility prerequisites

- New upload finalizations must include the positive Cloud Storage object
  generation captured from object metadata.
- Replay download uses both the finalized object path and exact generation,
  with a generation-match precondition. A missing legacy generation or a
  replaced/deleted generation is a stable evidence rejection; the worker never
  substitutes the latest object at that path.
- Ticket `uid` and `runSessionId` must match the stored session.
- The canonical loadout digest is recomputed from the ticket snapshot.
- The current hard-cutover compatibility tuple is:
  - current game compatibility: `2026.08.0`
  - draining game compatibility: `2026.03.0`
  - replay/command encoding: `1` / `1`
  - ruleset: `rules-v2`
  - score: `score-v1`
  - ghost: `ghost-v1`
- Both game-compatibility labels execute the same current normal `GameCore`
  constructor, polygon-terrain authority, and capsule combat narrow phase.
  `rules-v1` tickets are rejected: there is no historical AABB-combat
  simulation path. Deployment therefore waits until old ruleset issuance has
  stopped and all old sessions/tasks are drained or explicitly closed. The old
  game-compatibility label remains a separate bounded ticket drain until its
  issuance has stopped for at least the 24-hour ticket lifetime and the
  active-session audit is empty.
- A ranked ticket carries the board window captured at issuance. Validation
  uses that immutable ticket snapshot, so later board closure or deletion does
  not reinterpret an already issued run.

## 4.4 Decode + structural validation

Validation gates include:
- non-empty bytes
- uploaded `contentLengthBytes` match
- compressed-byte limit checked before/full download
- streamed download bytes are accumulated with a chunk-aware `BytesBuilder`
  and compacted to one `Uint8List`, avoiding growable integer-list capacity
  overhead near the deployed memory boundary
- optional streaming gzip decode when payload has gzip magic header
- expanded-byte limit enforced while streaming decompressed output
- JSON nesting-depth limit checked before `jsonDecode`
- JSON object decode
- protocol parse (`ReplayBlobV1.fromJson(..., verifyDigest: true)`)

## 4.5 Session binding validation

Replay must match issued ticket/session metadata:
- `runSessionId`
- digest (`canonicalSha256`)
- `tickHz`
- seed
- level
- character
- loadout snapshot (canonical JSON comparison)
- ticket identity, canonical loadout digest, exact Storage generation, and
  every compatibility version
- board ticket keys must match the ticket's mode, level, and version fields
- mode/board binding invariants:
  - practice: board fields must be absent
  - board modes: `boardId` + `boardKey` must exist and match ticket

## 4.6 Command stream sanity validation

Checks include:
- strictly increasing frame ticks
- `moveAxis` and aim components in `[-1, 1]`
- hold masks are internally consistent (`valueMask` cannot set bits outside `changedMask`)
- `totalTicks >= max(command tick)`
- bounded command-frame count and total run duration
- explicit replay/command version, known-bit, axis-pair/range, and numeric
  validation in production code; assertions are not a security boundary
- the client starts Core and records the replay at the ticket's exact `tickHz`;
  the validator rejects a replay at any other rate

## 4.7 Deterministic simulation replay

Worker reconstructs `GameCore` from ticket data and passes it to the shared
`runReplaySimulation` loop. That loop replays command frames tick-by-tick:
- maps each frame only to its matching next simulation tick, then calls
  `core.applyCommands(...)`; Core rejects stale or future command ticks
- `core.stepOneTick()`
- drains events and captures final `RunEndedEvent`
- checks a monotonic simulation deadline throughout the tick loop

If no end event is produced, worker forces give-up and requires a terminal `RunEndedEvent`.

From terminal event it computes authoritative result:
- score (via `buildRunScoreBreakdown(...)`)
- distance meters
- duration seconds
- end reason
- gold earned
- stats payload

Outputs `ValidatedRun(accepted: true, ...)`.

## 4.8 Replay throughput gate

The server executable accepts a non-HTTP `benchmark` subcommand. It uses the
same `runReplaySimulation` function as `DeterministicValidatorWorker`, records
deterministic no-enemy command streams for the normal generated Field and
Forest terrain, then replays 36,000 ticks per level through fresh normal
`GameCore` construction. Auto-scroll is disabled only for this bounded fixture
so the simulation measures the complete ten-minute stream instead of ending at
the normal runner pressure limit.

The JSON report includes revision/dirty state, runtime/OS, tick and command
counts, elapsed time, real-time multiple, final distance/geometry version, and
deterministic-outcome gates. The local hard gates are at least 2x real time and
less than 300 seconds for each 36,000-tick level. Phase 7 must rerun the same
compiled binary inside the release container with one CPU and 512 MiB before
issuing compatible sessions; local results do not replace that deployment
evidence.

---

## 5) Side effects after validation

On accepted run:
1. Copy the exact finalized upload generation to the validator-owned immutable
   `replay-submissions/validated/<runSessionId>.bin.gz` path using source and
   destination generation preconditions. The accepted handoff records both
   source and sealed-artifact lineage in the run session; a pre-handoff copy
   left behind by a crashed worker is verified and reused on retry.
2. Atomically persist `validated_runs/<runSessionId>`, update the matching
   `reward_grants/<runSessionId>` to `settlement_pending`, and update the run
   session to `settlement_pending` with
   `settlementRepairDisposition = retryable`.
3. Request the private `runSettlementImmediate` Functions endpoint with the
   Cloud Run service identity and only the run-session id. The endpoint invokes
   the Functions-owned settlement transaction; it never accepts client reward
   values.
4. If that bounded request fails, times out, or races another delivery, leave
   the durable handoff unchanged. The retry-enabled Firestore/Eventarc
   dispatcher and scheduled stale-pending repair invoke the same transaction.
5. A Firestore-triggered Cloud Task independently invokes `/tasks/project` for
   board modes. That task projects leaderboard top/player-best state and then
   updates ghost artifacts/manifests. A failure returns HTTP 503 for Cloud
   Tasks retry; it never re-enters replay validation or changes payout state.

Pending-object cleanup may delete an old upload only when it has no matching
run session, belongs to an unfinalized/expired session, or the accepted session
has recorded its sealed validated artifact. It must preserve validating and
unarchived source evidence. Non-Top-10 validated artifacts keep the 15-day
retention policy; an active ghost is instead pinned by its independently durable
`ghosts/...` generation.

Leaderboard projection uses conditional compare-and-replace for player best
and an update-time precondition for changed top-10 materialized views. The
view stores `materializationSchemaVersion: 1` and a `materializedRevision`
computed from its exact ordered consumer payload while excluding top-level and
entry-level timestamps. An unchanged revision skips the view commit and does
not advance `updatedAtMs`. Missing, malformed, or older revision metadata
causes one safe rewrite; that one-way rewrite removes the retired
`sourceRevision` field rather than retaining a second skip authority.

A duplicate task always attempts top-10 convergence even when the candidate is
already the stored best. The candidate no-write comparison explicitly rolls
back its Firestore transaction before refresh so it cannot retain a
pessimistic lock. Current Top-10 player bests are marked `ghostEligible` only
when the value returned by the ranking query is false. Outgoing players use a
deletion-fenced conditional transaction that reads the actual stored value and
skips an already-false demotion. Every deletion-fence setup failure likewise
rolls back its opened transaction.

After ghost publication/reconciliation, projection refreshes the view again
so `ghostAvailable` is true only for a current active/exposed manifest whose
identity and source replay evidence match the leaderboard entry, and is
cleared on demotion. The materialized revision includes the source replay
fields persisted in the Top-10 entry, but not hidden promoted-manifest fields.
`runProjectionReconciliation` independently pages through boards every 15
minutes and sends board reconciliation tasks, so convergence does not depend
on a new score.

Ghost reconciliation derives exposure from the current top 10, including an
empty top 10, and pages through every prior manifest. Promotion copies the
exact validated source generation with source and destination preconditions.
The manifest records source generation, promoted generation, and replay digest
before it becomes callable-visible. Destination collisions are idempotent only
when Storage metadata proves the existing object matches the source evidence.

The validator never writes canonical gold, `validated_settled`, or terminal
`validated`. The settlement transaction applies the exact grant once to
canonical ownership, records its applied revision, and only then marks the run
terminal `validated`.

On protocol/rules rejection:
1. Atomically create rejected `ValidatedRun(accepted: false, rejectionReason,
   ...)`.
2. In the same commit, move the matching provisional reward grant to
   `revoked_final` and the lease-owned run session to terminal `rejected`.

On unexpected/transient worker errors:
- If attempt budget remains, state becomes `pending_validation`.
- `validationNextAttemptAtMs` is the earliest scheduled-repair eligibility
  timestamp. It is not the ordinary task scheduler.
- If the attempt budget is exhausted, the original internal-error grace start
  is preserved across leases. After grace, reward revocation and terminal
  `internal_error` commit atomically.

---

## 6) Retry policy and idempotency

Cloud Tasks is the ordinary retry-timing authority. The checked-in deployment
policy configures:

- maximum attempts: `8`
- minimum backoff: `30s`
- maximum backoff: `4h`
- maximum retry duration: `24h`

The worker's default attempt budget is also `8`. A scheduled
`runValidationRepair` Functions job runs every five minutes and:

- moves an expired `validating` lease back to `pending_validation` while
  clearing its token;
- requeues pending validation after its repair-eligibility timestamp;
- uses a transactionally incremented generation in the task name;
- restores immediate repair eligibility if enqueue fails.

Idempotency controls:
- Token-fenced lease acquisition ensures only one current validator instance
  can mutate processing state.
- The initial task name is deterministic
  (`run-<sanitizedRunSessionId>`).
- Repair task names are deterministic per persisted generation
  (`run-<sanitizedRunSessionId>-repair-<generation>`), avoiding Cloud Tasks
  tombstone collisions after an exhausted task.
- Accepted, rejected, and exhausted-error handoffs use multi-document
  preconditions.
- A precondition conflict during lease acquisition becomes an
  `alreadyValidating` retry result. A conflict during an owned atomic handoff
  becomes a stale-lease result. The worker records `lease` or
  `lease_conflict` retry telemetry and returns HTTP 503 for Cloud Tasks instead
  of leaking an unclassified HTTP 500.

Default validation resource limits:

- compressed replay: `8 MiB`
- expanded replay: `32 MiB`
- JSON nesting depth: `64`
- command frames: `250,000`
- run duration: `6 hours`
- simulation wall time: `2 minutes`
- lease duration: `10 minutes`

---

## 7) Run-session states touched by worker path

Relevant states in lifecycle:
- `uploaded`
- `pending_validation`
- `validating`
- `settlement_pending`
- `validated`
- `rejected`
- `internal_error`

The validation worker itself transitions:
- to `validating` (lease)
- to `settlement_pending` after an accepted replay handoff
- to `rejected` / `internal_error` for terminal failure paths
- or back to `pending_validation` with next retry timestamp

Firebase Functions transitions `settlement_pending` to `validated` only in the
canonical settlement transaction.

---

## 8) Deployment mode behavior

`ReplayValidatorApp.fromEnvironment()` behavior:
- If `GCLOUD_PROJECT`/`GOOGLE_CLOUD_PROJECT` and `REPLAY_STORAGE_BUCKET` are present:
  - wires full deterministic worker with Firestore/Storage integrations.
- If missing:
  - falls back to `StubValidatorWorker`, which returns `notImplemented`.

`SETTLEMENT_DISPATCH_URL` enables the immediate settlement request. It must be
an HTTPS URL for the IAM-protected `runSettlementImmediate` Function.
`SETTLEMENT_DISPATCH_TIMEOUT_MS` bounds the request (default: 4000 ms). Missing
the URL disables only the immediate path; Eventarc and repair still settle a
durable accepted handoff.

Validation lease/recovery configuration:

- `VALIDATOR_LEASE_DURATION_MS` (default `600000`)
- `VALIDATOR_ORPHANED_TASK_REPAIR_DELAY_MS` (default `900000`)

Replay resource configuration:

- `VALIDATOR_MAX_COMPRESSED_REPLAY_BYTES` (default `8388608`)
- `VALIDATOR_MAX_EXPANDED_REPLAY_BYTES` (default `33554432`)
- `VALIDATOR_MAX_JSON_NESTING_DEPTH` (default `64`)
- `VALIDATOR_MAX_COMMAND_FRAMES` (default `250000`)
- `VALIDATOR_MAX_RUN_DURATION_SECONDS` (default `21600`)
- `VALIDATOR_MAX_SIMULATION_WALL_TIME_MS` (default `120000`)

Missing project/bucket configuration leaves liveness available but makes
`/ready` return `503`; validation remains `501` and projection remains
retryable rather than acknowledging work. Invalid configured numeric/boolean
limits fail startup instead of silently selecting defaults. The checked-in
Cloud Run policy uses `/ready` as its startup probe and `/live` as its
liveness probe. Neither endpoint ends in `z`, because Cloud Run reserves some
such externally routed paths and can intercept `/healthz` before it reaches the
container.

The projection endpoint is active only in the fully configured worker. The
Functions `runProjectionOnAccepted` trigger enqueues it in the separate
`replay-projection` queue with the Cloud Tasks service identity. It is optional
for a player reward: a queue or artifact outage must not delay settlement.
The scheduled `runProjectionReconciliation` enqueues board-id tasks through
the same endpoint for leaderboard and ghost convergence.

The digest-pinned distroless container runs as numeric UID/GID `65532`. Root
`.dockerignore` and `.gcloudignore` files restrict the build context to the
service and its two local Dart package dependencies.

---

## 9) Observability

`ValidatorMetrics` logs structured dispatch lines to stdout
(`ConsoleValidatorMetrics`), including:

- `runSessionId`
- `status`
- `attempt`
- `mode`
- `phase`
- optional rejection reason
- optional duration in milliseconds
- safe exception class for projection retries; projection failures prefix the
  failing step and Google API failures append only HTTP status and stable
  provider reason. Raw API messages are excluded because they may contain
  document or object identities.
- bounded projection phases for changed, unchanged, ghost-only, retryable, and
  account-deletion-skip outcomes; optimistic conflict exhaustion uses a
  dedicated safe exception class in retry telemetry.

Accepted runs additionally emit `settlement_dispatch_start`,
`settlement_dispatch_outcome`, `settlement_dispatch_fallback`, or
`settlement_dispatch_disabled` phases. These separate immediate delivery
latency/failure from replay validation correctness.

Cloud Run logs can be filtered on `replay_validator.dispatch` for operational
triage. Run-session ids remain log-only correlation data and are never
extracted as metric labels.

`services/replay_validator/monitoring/` is the executable monitoring source. It
defines four label-free log metrics and ten alert policies covering:

- validation retry/lease-conflict activity;
- projection and ghost-reconciliation retries;
- terminal validator internal errors;
- replay resource-limit rejection bursts;
- Cloud Run request 5xx, unhealthy probes, and sustained memory pressure;
- validation and projection queue backlog;
- scheduled validation-repair and projection-reconciliation failures.

Validation backlog alerts after 30 minutes during pre-release cost containment
and projection backlog after 30 minutes, beyond normal
dispatch/reconciliation cadence. Before public release, remeasure validation
recovery and restore its production alert threshold. Alerts reuse the
production notification channel and are reconciled idempotently by
`monitoring/apply_alerts.ps1`.

---

## 10) How this connects to ghost runs

Ghost availability depends on accepted board-mode validation.

Only after validator acceptance does the independent projection pipeline:
- project leaderboard top entries (`ghostEligible` candidate updates),
- publish/refresh ghost manifests via `GhostPublisher`, and
- materialize `ghostAvailable` from active/exposed manifests in the final
  top-10 refresh.

So ghost runs are downstream of validator success, not client-side upload success.
When an active manifest's source lineage, digest, and promoted ghost generation
match a current top entry, reconciliation verifies that pinned ghost generation
and acknowledges it without rereading a short-lived source artifact. If the
ghost is absent, source evidence is still required to repair it; a missing
source and ghost remains a retryable integrity failure.

---

## 11) Quick troubleshooting checklist

1. Task reaches `/tasks/validate` and includes non-empty `runSessionId`.
2. Lease acquired with token/expiry (session not already terminal or protected
   by an active lease).
3. Replay object exists and size/content metadata match uploaded fields.
4. Replay digest/ticket binding checks pass.
5. Deterministic simulation emits `RunEndedEvent`.
6. `validated_runs` document is written.
7. Accepted runs reach `settlement_pending` with the matching grant before any
   immediate request.
8. Immediate dispatch succeeds, or Eventarc/repair eventually settles the same
   handoff exactly once.
9. Expired validation leases and orphaned pending work appear in
   `runValidationRepair` metrics and are requeued.
10. Session becomes `validated` only with the canonical applied-grant record.
11. For board modes: projection task completes eventually; its retry health is
    monitored separately from the settled reward.

---

## Related docs

- `docs/tdd/firebase_cloud_functions_overview.md`
- `docs/tdd/reward_settlement_operations.md`
- `docs/tdd/ghost_run_flow.md`
- `docs/tdd/authentication_flow_and_authorization.md`
