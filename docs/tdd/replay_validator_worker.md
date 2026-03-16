# Replay Validator Worker (What / How / Why)

This doc describes how the replay validator worker works today in `services/replay_validator`.

## 1) What it is

The replay validator worker is a Cloud Run HTTP service that consumes run validation tasks and deterministically validates replay uploads.

Main entrypoints:
- `GET /healthz`
- `POST /tasks/validate`

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
- Lease transitions state to `validating` and increments `validationAttempt`.
- If lease is not acquired (`notFound`, `alreadyTerminal`, `alreadyValidating`, invalid state), worker exits idempotently without reprocessing.

Accepted pre-lease states are intentionally permissive:
- `uploaded`
- `pending_validation`

This avoids races between task dispatch timing and finalize state transition.

## 4.2 Load prerequisites

- If mode requires board, loads board metadata (`BoardRepository`).
- Loads replay bytes from Cloud Storage (`ReplayLoader`) using uploaded object path.

## 4.3 Decode + structural validation

Validation gates include:
- non-empty bytes
- uploaded `contentLengthBytes` match
- optional gzip decode when payload has gzip magic header
- JSON object decode
- protocol parse (`ReplayBlobV1.fromJson(..., verifyDigest: true)`)

## 4.4 Session binding validation

Replay must match issued ticket/session metadata:
- `runSessionId`
- digest (`canonicalSha256`)
- `tickHz`
- seed
- level
- character
- loadout snapshot (canonical JSON comparison)
- mode/board binding invariants:
  - practice: board fields must be absent
  - board modes: `boardId` + `boardKey` must exist and match ticket

## 4.5 Command stream sanity validation

Checks include:
- strictly increasing frame ticks
- `moveAxis` and aim components in `[-1, 1]`
- hold masks are internally consistent (`valueMask` cannot set bits outside `changedMask`)
- `totalTicks >= max(command tick)`

## 4.6 Deterministic simulation replay

Worker reconstructs `GameCore` from ticket data and replays command frames tick-by-tick:
- `core.applyCommands(...)`
- `core.stepOneTick()`
- drains events and captures final `RunEndedEvent`

If no end event is produced, worker forces give-up and requires a terminal `RunEndedEvent`.

From terminal event it computes authoritative result:
- score (via `buildRunScoreBreakdown(...)`)
- distance meters
- duration seconds
- end reason
- gold earned
- stats payload

Outputs `ValidatedRun(accepted: true, ...)`.

---

## 5) Side effects after validation

On accepted run:
1. Persist `validated_runs/<runSessionId>`.
2. Write reward grant (`reward_grants/<runSessionId>`) if accepted and `goldEarned > 0`.
3. For board modes only:
   - project leaderboard top/player best
   - update ghost artifacts/manifests
4. Mark `run_sessions/<runSessionId>` terminal state `validated`.

On protocol/rules rejection:
1. Persist rejected `ValidatedRun(accepted: false, rejectionReason, ...)`.
2. Mark run session terminal state `rejected`.

On unexpected/transient worker errors:
- If attempt budget remains, state becomes `pending_validation` with `validationNextAttemptAtMs`.
- If budget exhausted, terminal state becomes `internal_error`.

---

## 6) Retry policy and idempotency

Default retry backoff schedule (`validationAttempt` based):
- 30s, 2m, 5m, 15m, 30m, 1h, 2h, 4h

`maxRetryAttempts` default: `8`.

Idempotency controls:
- Lease acquisition ensures only one validator instance claims processing.
- Task name is deterministic (`run-<sanitizedRunSessionId>`), so duplicate enqueue returns already-exists safely.
- Existing reward grant doc short-circuits duplicate creation.

---

## 7) Run-session states touched by worker path

Relevant states in lifecycle:
- `uploaded`
- `pending_validation`
- `validating`
- `validated`
- `rejected`
- `internal_error`

Worker itself transitions:
- to `validating` (lease)
- to `validated` / `rejected` / `internal_error`
- or back to `pending_validation` with next retry timestamp

---

## 8) Deployment mode behavior

`ReplayValidatorApp.fromEnvironment()` behavior:
- If `GCLOUD_PROJECT`/`GOOGLE_CLOUD_PROJECT` and `REPLAY_STORAGE_BUCKET` are present:
  - wires full deterministic worker with Firestore/Storage integrations.
- If missing:
  - falls back to `StubValidatorWorker`, which returns `notImplemented`.

This makes local/dev boot safe even before cloud dependencies are configured.

---

## 9) Observability

`ValidatorMetrics` currently logs structured dispatch lines to stdout (`ConsoleValidatorMetrics`), including:
- `runSessionId`
- `status`
- `attempt`
- `mode`
- `phase`
- optional rejection reason/message

Cloud Run logs can be filtered on `replay_validator.dispatch` for operational triage.

---

## 10) How this connects to ghost runs

Ghost availability depends on accepted board-mode validation.

Only after validator acceptance does the pipeline:
- project leaderboard top entries (`ghostEligible` updates), and
- publish/refresh ghost manifests via `GhostPublisher`.

So ghost runs are downstream of validator success, not client-side upload success.

---

## 11) Quick troubleshooting checklist

1. Task reaches `/tasks/validate` and includes non-empty `runSessionId`.
2. Lease acquired (session not already terminal/validating).
3. Replay object exists and size/content metadata match uploaded fields.
4. Replay digest/ticket binding checks pass.
5. Deterministic simulation emits `RunEndedEvent`.
6. `validated_runs` document is written.
7. Session terminal state updated as expected.
8. For board modes: leaderboard projection + ghost publication succeeded.

---

## Related docs

- `docs/tdd/firebase_cloud_functions_overview.md`
- `docs/tdd/ghost_run_flow_what_how_why.md`
- `docs/tdd/authentication_flow_and_authorization.md`
