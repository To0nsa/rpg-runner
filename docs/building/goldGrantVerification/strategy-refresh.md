# Gold Grant Verification: Backend Settlement Strategy

Date: July 16, 2026
Status: Backend settlement services are deployed; client compatibility, legacy
migration, and production observability remain before broad rollout.

## Position

The game has one gold wallet: `progression.gold`.

It is verified, spendable, and the only value persistent wallet surfaces may
display. A run-result screen may show what a run earned, but that value is not
wallet gold until the backend has completed deterministic validation and
canonical settlement.

The client must observe settlement, never cause it.

## Root Problem

The current system has the right safety intention but the wrong completion
boundary:

1. The validator marks `reward_grants` as `validated_settled`.
2. A later client ownership read reconciles that grant into
   `progression.gold`.
3. Persistent UI compensates by displaying
   `progression.gold + unverifiedGold`.

This gives one reward two meanings: final according to submission status, but
not yet present in the spendable wallet. It is why Town can show enough gold in
its header while its purchase and refresh commands remain unavailable.

Client polling, local settlement markers, or a second display total can hide
that split, but they do not repair it. They make client activity part of the
payout pipeline.

## Target Invariant

For a reward-eligible accepted run:

> `run_sessions.state == validated` and a final reward projection are allowed
> only after the exact reward grant has been applied once to canonical
> `progression.gold` in a backend transaction.

Consequences:

- `validated_settled` means **canonical wallet applied**, not merely replay
  accepted.
- The validated run, reward grant, canonical ownership write, and terminal run
  state have a server-owned ordering. The client cannot observe successful
  validation with stale canonical settlement.
- The canonical ownership revision advances when settlement changes wallet or
  progression hooks. Concurrent commands therefore receive normal
  stale-revision handling rather than silently applying against an old wallet.
- Repeated delivery, trigger retry, and crash recovery cannot double-credit a
  grant. Grant idempotency is enforced in the same Firestore transaction as the
  wallet write.

## Implementation Snapshot

Backend:

- `finalizeRunSessionUpload` creates one provisional
  `reward_grants/{runSessionId}` document.
- The Dart replay validator deterministically validates the uploaded replay and
  atomically writes `validated_runs/{runSessionId}`, a matching
  `settlement_pending` grant, and a `settlement_pending` run session.
- Firebase Functions owns the atomic canonical settlement transaction, its
  Firestore handoff trigger, and a five-minute repair scan.
- Legacy `validated_settled` grants still use the read-time reconciler during
  the migration window. New handoffs cannot use that path.

Client:

- `RunSubmissionCoordinator` persists replay-upload work in SharedPreferences.
- `RunnerGameWidget` polls status only while the run route is mounted.
- Persistent UI reads canonical `progression.gold` only. Game Over may show a
  pending result amount explicitly labelled as not spendable.

The refactor removes client-driven reward reconciliation from the normal path.
The existing read-time reconciler becomes a migration/repair mechanism rather
than the way ordinary payouts complete.

## Target Server Workflow

### State Model

Add an explicit non-terminal `settlement_pending` run-session state. It means
the replay is accepted and its required validation artifacts are durable, but
the canonical wallet transaction has not committed yet.

| Validation result | Run-session state | Reward-grant state | Wallet meaning |
| --- | --- | --- | --- |
| Replay upload accepted | `pending_validation` | `provisional_created` | No reward is spendable. |
| Validator owns the replay | `validating` | `provisional_created` | No reward is spendable. |
| Replay accepted; settlement requested | `settlement_pending` | `settlement_pending` | Server is settling; no final reward is projected. |
| Settlement transaction commits | `validated` | `validated_settled` | Grant applied exactly once to canonical wallet. |
| Replay rejected or final internal-error policy revokes it | terminal rejection state | `revoked_final` | No wallet mutation. |

`settlement_pending` is a server-internal completion state. It must decode as
non-terminal in `run_protocol`, the Flutter submission model, and all backend
state validators. It is never a client-visible second balance.

### Validation and Settlement Sequence

1. Finalize persists the upload metadata and exactly one provisional reward
   grant, then durably queues validation.
2. The validator acquires its existing validation lease and replays Core
   deterministically. It writes the accepted `validated_runs` record and any
   validation-required artifacts.
3. The validator derives the authoritative gold from the accepted replay,
   changes the grant to `settlement_pending`, and changes the run session to
   `settlement_pending`. It does **not** write `validated_settled` and does
   **not** mark the run `validated`.
4. A trusted Firebase Functions settlement dispatcher reacts to that state
   transition. A Firestore event is the primary delivery mechanism; it is only
   retryable orchestration, not payout authority.
5. The dispatcher calls one reusable Functions-owned settlement transaction.
   That transaction reads the run session, validated run, reward grant, and
   canonical ownership; verifies their session id and uid bindings; applies the
   reward idempotently; advances the ownership revision; marks the grant
   `validated_settled`; and marks the run session `validated`.
6. Only after that transaction commits may `loadRunSessionSubmissionStatus`
   return terminal `validated` and reward status `final`.

The transaction must reject malformed or mismatched documents and leave the run
non-terminal for safe retry/incident handling. It must not pay a grant merely
because a client supplied a summary or because a document has a matching id.

### Settlement Transaction Contract

The settlement helper belongs in `functions/src/**`, alongside the ownership
transaction code. The Dart validator must not reimplement canonical ownership
normalization, revision behavior, or gold application.

For `runSessionId`, the transaction must:

1. Require `run_sessions.state == settlement_pending` or recognize an already
   settled terminal result as an idempotent no-op.
2. Require an accepted `validated_runs/{runSessionId}` document whose uid,
   session id, mode, and reward context match the run session and grant.
3. Require `reward_grants/{runSessionId}` in `settlement_pending` for the same
   uid. A missing or mismatched reward-eligible grant is an operational error,
   not a zero-gold success.
4. Resolve canonical ownership inside the transaction and apply the grant only
   if its id is absent from `progression.appliedRewardGrantIds`.
5. Update gold, weekly progression hooks, the applied-grant set, and canonical
   revision as one canonical write.
6. Write grant audit fields (`appliedAtMs`, `appliedProfileId`,
   `appliedRevision`) and `validated_settled` in the same transaction.
7. Write run-session terminal fields and `state: validated` in that same
   transaction.

The applied-grant set is the idempotency proof. Firestore transaction retries
and duplicate event delivery are expected; they must return the already-settled
result without changing gold, revision, weekly counters, or terminal timestamps.

## Failure, Retry, and Recovery

### Dispatcher Reliability

The Firestore settlement dispatcher must enable retry. A successful replay can
remain `settlement_pending` only while the server is retrying the transaction;
it must never require a client status or ownership read to resume payout.

Add a scheduled server-side repair scan for stale `settlement_pending` sessions.
It re-invokes the same settlement helper, records a metric, and escalates only
after an explicit operational timeout. This covers deployment gaps, exhausted
event retries, and manual recovery without creating a second payout path.

### Rejected and Revoked Runs

Rejection has no wallet mutation. The backend must close the rejection grant
and terminal run state together, or leave both non-terminal for retry. A client
must never compensate a revocation with negative gold because provisional gold
was never canonical.

### Migration and Legacy Repair

Historical `validated_settled` grants may exist without their id in canonical
`appliedRewardGrantIds`. Before enabling the new dispatcher:

1. Inventory and backfill provisional/legacy grants to an explicit state.
2. Run a server-side repair job using the same settlement helper or a dedicated
   legacy adapter with equivalent idempotency checks.
3. Verify no reward-eligible `validated` run lacks an applied grant id.
4. Retire read-time reconciliation from ordinary canonical loads and ownership
   commands once the migration is complete.

Until the migration closes, legacy reconciliation is an explicitly monitored
repair fallback. It must not be needed for new runs and must not be triggered by
normal client navigation.

## Client and UI Contract

### One Wallet

Remove `displayGold` and `unverifiedGold` from persistent UI. Hub, Town, and
Profile display direct canonical `progression.gold`; store affordability and
commands use that same value.

### Game Over

Game Over may show `runRewardGold` as result context while the status is
non-terminal. It may not present that number as the player wallet.

When the server returns terminal `validated`, the client refreshes canonical
ownership for presentation. That read observes an already-settled wallet; it
does not settle it. `Collect` is an acknowledgement and animation only. It
must not write an award command or invoke any payout API.

After the slow-path threshold, the player can exit with a processing message.
The server continues independently. On the next foreground ownership refresh,
or an optional ownership-profile subscription/notification, persistent UI sees
the updated one wallet. No durable client settlement marker is required for
correctness.

### Submission Durability

The local submission spool remains responsible for interrupted upload and
finalize work. It may retain non-terminal submission status for run-result
presentation, but it must not become a reward ledger or a prerequisite for
canonical payout. It can be removed after the server reaches any terminal run
state.

## Validation Latency and Observability

Correctness does not depend on a fast lane. Cloud Tasks validation and the
server settlement dispatcher are the durable baseline.

An optional bounded immediate validation attempt may be added later to improve
the normal Game Over flow. It must use the existing validator lease, follow a
durably queued fallback, run with a trusted backend identity, and have no
different settlement behavior.

Initial rollout targets, to be reviewed after two weeks of representative
production traffic:

| Contract | Initial target |
| --- | --- |
| Game Over slow-path threshold | 10 seconds from durable finalize. |
| Finalize-to-`settlement_pending` | p95 ≤ 8 seconds; p99 ≤ 30 seconds. |
| `settlement_pending`-to-terminal settlement | p95 ≤ 2 seconds; p99 ≤ 15 seconds. |
| Stale settlement repair dispatch | First attempt within 5 minutes of the configured stale threshold. |
| Correctness | Zero terminal validated runs without the exact grant recorded in canonical applied-grant ids. |

Emit structured, privacy-safe metrics for:

- finalize-to-validation and validation-to-settlement durations
- settlement transaction outcome, retry count, and idempotent no-op count
- stale settlement repair count and age
- final reward projection before/after terminal status violations
- mode, replay-size bucket, validator attempt, cold-start indicator, and
  settlement error class

Alert on p99 settlement latency, stale repair use, transaction failures, and
any invariant violation. The fast validation lane, if enabled later, gets
separate latency and fallback metrics.

## Implementation Plan

### Phase 1 — Freeze the New Contract and Migration Boundary

- Add `settlement_pending` to the TypeScript run-session state machine, shared
  Dart submission protocol, Flutter status mapping, cleanup rules, and tests.
- Redefine `validated_settled` to mean canonical wallet applied. Add the
  intermediate grant state; remove all code paths that use it to mean replay
  acceptance only.
- Document and inventory existing legacy grants. Decide the deployment order and
  rollback behavior before enabling the new terminal-state invariant.

### Phase 2 — Extract the Backend Settlement Authority

- Extract reward application and weekly-progression logic from read-time
  reconciliation into one Functions-owned transaction helper.
- Make the helper verify uid/session/reward bindings, use applied-grant
  idempotency, increment canonical revision, and atomically write canonical,
  grant, and terminal run session.
- Add focused emulator tests for duplicate delivery, transaction retry,
  concurrent ownership commands, missing/mismatched documents, overflow, and
  all-or-nothing failure behavior.

### Phase 3 — Drive Settlement from the Server

- Add the retry-enabled Firestore settlement dispatcher and stale-pending repair
  job. Both call the same transaction helper.
- Change the validator accepted path to write accepted validation data and
  `settlement_pending`, then stop. It must not set final reward state or mark a
  run validated.
- Keep rejection/revocation terminalization server-owned and idempotent.
- Decouple non-wallet leaderboard and ghost projection retries from payout
  correctness. A projection delay must not require a client action to settle
  verified gold.

### Phase 4 — Simplify Client Completion Semantics

- Remove persistent `displayGold`/`unverifiedGold` use and update page/state
  tests to assert canonical-only wallet rendering.
- Treat `settlement_pending` as a processing status in Game Over. Refresh
  canonical ownership only after terminal validated for display.
- Remove durable client canonical-settlement markers and any retry loop whose
  purpose is to make a server payout happen.
- Keep upload-resume reliability and normal foreground ownership refreshes.
- Make Collect a presentation-only acknowledgement and test that it cannot
  mutate gold.

### Phase 5 — Migrate, Observe, and Optimize

- Run the legacy repair/backfill, prove the terminal invariant in production
  telemetry, then remove routine read-time reconciliation.
- Add the optional fast validation lane only after the durable baseline meets
  the latency targets. Keep it behind a rollout flag and preserve Cloud Tasks
  fallback.
- Update backend, validator, protocol, UI, deployment, and strategy
  documentation together whenever the cross-layer contract changes.

## Acceptance Criteria

- There is exactly one persistent visible gold wallet, and it is always direct
  canonical `progression.gold`.
- A terminal `validated` run has its exact reward grant in canonical
  `appliedRewardGrantIds`, with canonical gold and progression hooks already
  updated.
- A final reward projection cannot be returned for a non-terminal or
  canonical-unapplied accepted run.
- Duplicate validator dispatch, duplicate Firestore event delivery, settlement
  repair, and transaction retry cannot double-credit gold, weekly counters, or
  canonical revision.
- A client that closes Game Over, backgrounds the app, loses local submission
  state, or never polls again cannot prevent a verified server payout.
- Rejected, revoked, malformed, and mismatched rewards cannot mutate canonical
  gold.
- Ownership commands racing with settlement receive normal revision/idempotency
  behavior and never spend a falsely displayed balance.
- Read-time reconciliation is absent from the normal new-run path and retained
  only until the documented legacy migration closes.
- Game Over represents delayed work as processing state; Collect only animates
  an already-settled wallet.
- Metrics and alerts make validation, settlement, retry, and invariant failures
  observable before rollout is expanded.
