# AGENTS.md - Replay Validator Service

Instructions for AI coding agents working in `services/replay_validator/`.

## Service Responsibility

`services/replay_validator` is the Dart Cloud Run worker that validates uploaded
run replays asynchronously. It owns:

- HTTP service wiring for `GET /healthz` and `POST /tasks/validate`
- Cloud Tasks dispatch handling by `runSessionId`
- replay loading from Cloud Storage
- run-session lease/status reads and writes in Firestore
- deterministic replay execution through `runner_core`
- validation result persistence through `run_protocol`
- accepted-run handoff to backend settlement, leaderboard projection, and ghost
  artifact publishing after deterministic validation

It is not a client-facing app, a Firebase callable backend, or an authoring
tool.

## Hard Boundaries

- keep callable request/response authority in `functions/src/**`
- keep shared wire contracts in `packages/run_protocol/**`
- keep gameplay truth in `packages/runner_core/lib/**`
- do not add Flutter, Flame, or UI dependencies
- do not make this service invent run tickets or bypass backend run-session
  state
- do not write generated runtime source or authoring assets from this service

The worker may consume Core to replay a run, but it must not become a second
gameplay implementation.

## Current Important Files

- `bin/server.dart`: service entrypoint
- `lib/src/app.dart`: environment-driven worker construction and HTTP routes
- `lib/src/validator_worker.dart`: validation lease, replay checks,
  deterministic replay, settlement handoff, terminal rejection, leaderboard,
  and ghost flow
- `lib/src/replay_loader.dart`: Cloud Storage replay loading
- `lib/src/run_session_repository.dart`: Firestore run-session lease/status
  repository
- `lib/src/leaderboard_projector.dart`: leaderboard projection writes
- `lib/src/ghost_publisher.dart`: ghost artifact publication
- `lib/src/reward_settlement_writer.dart`: wallet-neutral reward revocation
  transitions for rejected runs
- `lib/src/google_api_helpers.dart`: Google API auth/client helpers
- `lib/src/metrics.dart`: dispatch/validation logging metrics

Read `validator_worker.dart` before changing validation behavior; most safety
rules are coordinated there.

## Deterministic Validation Rules

Replay acceptance depends on strict contract matching:

- run-session id, digest, tick rate, seed, level, character, loadout, mode, and
  board binding must match the server-issued ticket
- command ticks must be strictly increasing and within the replay tick range
- input axes and hold masks must stay inside protocol bounds
- accepted runs must be produced by replaying `GameCore` from the ticket and
  replay blob, not by trusting client summaries
- practice runs must not include board binding fields
- ranked runs must include a board id/key matching the ticket

Use wall-clock time only for metadata, retry scheduling, and terminal timestamps.
Gameplay validation must come from the replay inputs and deterministic Core.

## Failure, Retry, And Settlement Rules

- malformed or mismatched replays become terminal rejected runs
- transient worker/internal failures use the retry and grace-window paths
- incident-mode auto-revoke pause must remain fail-closed and explicit
- accepted runs must atomically hand off `validated_runs`, a
  `settlement_pending` grant, and a `settlement_pending` run session; the
  validator must never write canonical gold, `validated_settled`, or terminal
  `validated`
- rejected/internal-error reward revocation must stay wallet-neutral
- leaderboard and ghost projection must only run for accepted board-backed runs
- terminal states must be idempotent enough for Cloud Tasks retry behavior

Do not weaken validation or settlement rules to make a client-side bug pass.

## Environment And Deployment

`ReplayValidatorApp.fromEnvironment()` enables the real worker only when the
required environment is present. Important environment variables include:

- `PORT`
- `GCLOUD_PROJECT` or `GOOGLE_CLOUD_PROJECT`
- `REPLAY_STORAGE_BUCKET`
- `VALIDATOR_INTERNAL_ERROR_GRACE_WINDOW_MS`
- `VALIDATOR_INCIDENT_MODE_PAUSE_AUTO_REVOKE`
- `VALIDATOR_INCIDENT_MODE_RETRY_DELAY_MS`

Keep local stub behavior available for missing configuration so health checks
and local runs remain predictable.

Deploy the Functions settlement dispatcher and repair job before deploying a
validator revision that emits `settlement_pending`; deploying only the
validator would strand accepted rewards.

## Testing And Build Expectations

Minimum checks for service changes:

- `dart analyze services/replay_validator`
- `dart test services/replay_validator/test`

For deployment-sensitive changes, also verify the executable still compiles:

- `dart compile exe services/replay_validator/bin/server.dart -o .tmp/replay_validator_server`

Add focused tests around:

- validation rejection reasons
- retry/grace-window behavior
- reward settlement on accepted/rejected/internal-error paths
- leaderboard and ghost projection gating
- Firestore/Storage codec behavior when touched

## Cross-Layer Responsibilities

Changes here may require matching updates in:

- `packages/run_protocol/**` for replay, run ticket, validated run, board, or
  leaderboard contract changes
- `packages/runner_core/lib/**` when replayed gameplay behavior changes
- `functions/src/**` when run-session status, board metadata, cleanup, or Cloud
  Tasks dispatch contracts change
- `lib/ui/state/run/**` and `lib/ui/state/boards/**` when client-visible status
  or ghost/leaderboard behavior changes
- deployment docs in `services/replay_validator/README.md`

## Common Failure Modes To Avoid

- trusting `clientSummary` instead of replaying Core
- accepting a replay whose board binding or digest does not match the ticket
- writing a final reward or terminal `validated` state from the validator
- adding non-deterministic gameplay inputs during validation
- treating Cloud Tasks retries as exactly-once delivery
- making environment configuration mandatory for local health checks

---

For shared protocol contracts, see `packages/run_protocol/AGENTS.md`. For
callable run-session orchestration, see `functions/AGENTS.md`.
