# Gold Grant Verification — Implementation Checklist

Date: July 16, 2026
Status: Backend settlement services deployed; client compatibility, legacy
migration, and production acceptance remain before broad rollout.
Source strategy: [strategy-refresh.md](strategy-refresh.md)

This checklist implements the backend-settlement architecture in
`strategy-refresh.md`. It replaces the archived client/read-time reconciliation
approach; do not reuse its state transitions or completion rules.

## Definition of Done

- `progression.gold` is the only persistent wallet displayed or spent.
- A reward-eligible run is terminal `validated` only after its exact grant is
  committed once into canonical ownership.
- The settlement transaction atomically updates canonical ownership, reward
  grant, and terminal run session state.
- Closing Game Over, losing local state, or never polling again cannot prevent a
  validated server reward from being paid.
- Replay validation, settlement dispatch, repair, and ownership commands are
  idempotent under duplicate delivery and transaction retry.
- Legacy read-time reconciliation is removed from the normal new-run path after
  its migration closes.

## Locked Constraints and Invariants

Do not relax these without updating the strategy in the same change:

- `validated_settled` means canonical wallet application is complete; it never
  means replay validation alone succeeded.
- `run_sessions.state == validated` and reward status `final` require the same
  settlement transaction to have committed the exact grant.
- The Dart validator may derive authoritative replay reward data, but it must
  not duplicate TypeScript ownership normalization, canonical revision, or gold
  application behavior.
- Firestore event delivery, scheduled repair, and an optional fast validation
  lane are dispatch mechanisms. They all invoke the same settlement authority.
- The client may refresh or animate canonical gold, but it must not settle,
  award, or retry a payout on the server's behalf.
- Provisional reward value may appear only in run-result context. It is never a
  persistent wallet total or economy input.
- Settlement changes canonical revision exactly once per applied grant, so
  racing ownership commands follow the existing stale-revision contract.
- No deployment may emit a new non-terminal state to clients that cannot parse
  it. Deploy protocol/client compatibility before enabling server emission.

## Locked Implementation Order

1. Baseline, migration inventory, and rollout controls
2. Shared state/protocol contract for `settlement_pending`
3. Functions-owned atomic settlement transaction
4. Server dispatcher, retry, and stale-settlement repair
5. Validator atomic handoff and projection decoupling
6. Client one-wallet and Game Over simplification
7. Legacy migration, cutover, and normal-path reconciler removal
8. Observability, production verification, and optional fast lane

Do not mark a later phase complete until the preceding phase's done criteria and
focused checks pass.

## Deployment Record — July 16, 2026

- [x] Firebase Functions settlement authority, retry-enabled Firestore handoff
  trigger, and five-minute repair schedule deployed to
  `rpg-runner-d7add` / `europe-west1`.
- [x] Cloud Run validator revision `replay-validator-00018-kz8` deployed with
  image
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator:settlement-handoff-20260716-2107`
  and serving 100% of traffic.
- [x] Grant `roles/eventarc.eventReceiver` to
  `sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com`, the minimum
  Eventarc delivery permission required by the Firestore trigger.
- [x] Confirm trigger state `ACTIVE`, retry policy enabled, repair schedule
  enabled (`every 5 minutes`), validator revision serving, and container startup
  log present.
- [x] Flutter web client deployed to Firebase Hosting on July 17, 2026 at
  `https://rpg-runner-d7add.web.app`. The release journals a finalized replay
  locally before Game Over permits normal exit/restart/back navigation.

This is a backend and web-client deployment record, not broad-rollout approval.
Before users on older native app builds can create runs, release the same client
compatibility and replay-journaling changes there (or enforce a minimum
version), then complete the legacy inventory in Phase 0/6, structured
observability and runbook work in Phases 3/7, and an end-to-end settlement test
with the client closed.

---

## Phase 0 — Baseline, Inventory, and Rollout Plan

Objective:

- establish the current state of grants and define a recoverable rollout before
  changing terminal semantics

Tasks:

- [ ] Record the current production/staging counts for:
  - [ ] `provisional_created`, `provisional_visible`, `validated_settled`,
    `revocation_visible`, and `revoked_final` reward grants
  - [ ] `validated_settled` grants absent from
    `progression.appliedRewardGrantIds`
  - [ ] terminal `validated` runs with missing, mismatched, or unapplied grants
  - [ ] validation and canonical reconciliation latency percentiles
- [ ] Document the migration population, retention window, and operator owner.
- [ ] Define rollout flags and their safe defaults:
  - [ ] new settlement dispatcher enabled
  - [ ] stale-settlement repair enabled
  - [ ] legacy read-time repair enabled
  - [ ] optional fast validation lane enabled
- [ ] Define the stale `settlement_pending` threshold, retry policy, alert
  target, and incident escalation owner.
- [ ] Capture a green baseline using the validation commands in Phase 8.

Done when:

- [ ] every pre-existing grant population has a documented migration outcome
- [ ] rollback does not leave accepted rewards stranded or double-payable
- [ ] baseline validation is recorded

---

## Phase 1 — Freeze Shared State and Wire Contracts

Objective:

- make `settlement_pending` an explicit, non-terminal contract before any
  backend writes it

Tasks:

- [x] Add `settlement_pending` to the TypeScript run-session state machine in
  `functions/src/runs/session_state.ts`.
- [x] Add `settlementPending` / `settlement_pending` mapping to
  `packages/run_protocol/lib/submission_status.dart`.
- [x] Update Flutter run-submission status mapping and UI labels to treat the
  state as non-terminal processing.
- [x] Update callable parsing/projection so final reward status is impossible
  while the session is non-terminal, including `settlement_pending`.
- [x] Add the intermediate reward-grant lifecycle state
  `settlement_pending`; keep `validated_settled` exclusively for a canonically
  applied grant.
- [x] Update cleanup eligibility and all lifecycle validators for the new
  non-terminal state.
- [ ] Decide and document backward compatibility:
  - [ ] release clients that parse `settlement_pending` before enabling it
  - [ ] retain safe server behavior for supported older clients, or enforce the
    minimum app version before server rollout
- [x] Add protocol and backend tests for parsing, serialization, terminal
  classification, and forbidden transitions.

Done when:

- [ ] all layers agree that `settlement_pending` is valid and non-terminal
- [ ] no status projection can emit `final` before terminal validated
- [ ] the server can be deployed without exposing an unparseable state

---

## Phase 2 — Extract the Functions-Owned Settlement Transaction

Objective:

- create one atomic and idempotent authority for applying accepted rewards

Tasks:

- [x] Extract reusable reward-application and weekly progression logic from
  `functions/src/ownership/reward_grants.ts` into a transaction-safe helper.
- [x] Add a settlement entry point, owned by `functions/src/**`, that accepts
  only a `runSessionId` and obtains every reward value from Firestore.
- [x] In one Firestore transaction, read and validate:
  - [x] `run_sessions/{runSessionId}` in `settlement_pending`
  - [x] accepted `validated_runs/{runSessionId}`
  - [x] matching `reward_grants/{runSessionId}` in `settlement_pending`
  - [x] canonical ownership for the matching uid
- [x] Verify run-session id, uid, mode, board/reward context, and grant binding
  before any mutation.
- [x] Apply the grant only if its id is absent from
  `progression.appliedRewardGrantIds`.
- [x] Update gold, weekly progression fields, applied-grant ids, and canonical
  revision in one canonical write.
- [x] Mark the reward grant `validated_settled` with applied audit fields in the
  same transaction.
- [x] Mark the run session `validated` with terminal fields in the same
  transaction.
- [ ] Return an explicit result for settled, already-settled, not-ready, and
  invariant-violation outcomes; only retryable outcomes may be retried by a
  dispatcher.
- [x] Keep legacy reconciliation separate from this helper until Phase 7. Do
  not make a canonical client read required for a newly accepted reward.

Done when:

- [ ] a new accepted run cannot reach `validated` without an applied grant
- [ ] duplicate calls change neither gold nor revision after the first commit
- [ ] a transaction failure commits no partial canonical, grant, or session
  state

Focused tests:

- [x] first settlement applies gold and increments revision exactly once
- [x] duplicate settlement is an idempotent no-op
- [ ] Firestore transaction retry is safe
- [x] concurrent purchase/refresh observes normal stale-revision behavior
- [ ] missing, mismatched, malformed, rejected, and overflow inputs cannot pay
- [ ] weekly progression hooks apply once and preserve rollover rules

---

## Phase 3 — Add Server Settlement Dispatch and Repair

Objective:

- make settlement progress independently of any client activity

Tasks:

- [x] Add a retry-enabled Firebase Functions Firestore dispatcher for the
  transition to `run_sessions.state == settlement_pending`.
- [x] Ensure duplicate event delivery and events for already-terminal sessions
  call the Phase 2 helper safely and do not create another payout path.
- [x] Add a scheduled stale-settlement repair scan for
  `settlement_pending` sessions.
- [x] Make repair invoke the exact Phase 2 helper; it must not directly edit
  canonical gold, reward grants, or run state.
- [ ] Bound repair scan pages, retries, and per-run work; emit an actionable
  metric when a session remains stale after the configured threshold.
- [ ] Add structured metrics for dispatch start/outcome, transaction retry,
  idempotent no-op, invariant violation, repair age, and repair outcome.
- [ ] Write an operator runbook for inspecting and replaying a stale settlement
  through the safe helper only.

Done when:

- [ ] a server-accepted run settles while no client is connected
- [ ] event failure, duplicate delivery, and repair execution preserve exact-once
  wallet effects
- [ ] stale settlement has an observable alert and safe remediation path

Focused tests:

- [ ] dispatcher ignores unrelated writes and non-pending sessions
- [ ] dispatcher retries transaction failures
- [ ] duplicate event after success is a no-op
- [ ] repair finds stale pending sessions and uses the same helper
- [ ] repair cannot settle rejected, mismatched, or malformed records

---

## Phase 4 — Refactor Validator Handoff and Non-Wallet Side Effects

Objective:

- have the validator prove replay acceptance and durably request settlement,
  without claiming terminal payout completion

Tasks:

- [x] Replace the validator success path that writes `validated_settled` and
  terminal `validated`.
- [x] Add a validator repository operation that atomically persists the accepted
  validated run, derives server-authoritative gold, sets the matching grant to
  `settlement_pending`, and sets the run session to `settlement_pending`.
- [x] Preserve validation lease/idempotency behavior for duplicate Cloud Tasks
  dispatches and retries.
- [x] Ensure the validator handoff validates the existing grant/session uid and
  run-session bindings before requesting settlement.
- [x] Keep rejected and internal-error transitions server-owned, idempotent, and
  wallet-neutral. Do not mark a rejected run `validated` to release a reward.
- [ ] Decide the retry boundary for leaderboard projection and ghost publishing:
  - [ ] payout settlement must not wait for optional projection work
  - [ ] projection retries must not turn an accepted reward into a revoked one
  - [ ] document any artifact required before the validator may request
    settlement
- [x] Refactor `reward_settlement_writer.dart` so its API cannot imply
  that the validator writes final canonical settlement.

Done when:

- [ ] validator success ends at durable `settlement_pending`, never terminal
  `validated`
- [ ] an interrupted validator handoff leaves a recoverable server state
- [ ] payout correctness is independent of leaderboard/ghost projection retry

Focused tests:

- [ ] accepted replay persists data and requests settlement without terminalizing
- [ ] rejected replay and retry-exhausted internal error never credit gold
- [ ] duplicate validator dispatch cannot create duplicate settlement requests
- [ ] failure before atomic handoff leaves no false final state
- [ ] projection failure follows its documented retry path without blocking or
  reversing a valid payout

---

## Phase 5 — Simplify Client and Game Over Semantics

Objective:

- present one canonical wallet and make the client a consumer of server truth

Tasks:

- [x] Remove `AppState.unverifiedGold` and `AppState.displayGold`.
- [x] Update Hub, Town, Profile, shared gold widgets, and their tests to render
  direct canonical `progression.gold` only.
- [x] Keep store affordability and command checks based on the same canonical
  value.
- [x] Map `settlement_pending` to processing state in Game Over; do not expose
  it as a second currency or a final reward.
- [x] On terminal `validated`, refresh canonical ownership for presentation only
  and render the already-settled wallet.
- [x] Make Collect a local acknowledgement/animation only:
  - [x] it has no economy command, payout callable, or direct Firestore write
  - [x] it cannot increase canonical gold locally
  - [ ] it never blocks exit after the slow-path threshold
- [x] Preserve the local submission spool only for upload/finalize recovery and
  non-terminal result presentation.
- [x] Finalize the replay blob and persist its local submission entry before
  Game Over permits normal exit, restart, or route back navigation. Resume the
  upload from that entry on the next app bootstrap.
- [x] Remove any durable client marker or retry loop whose purpose is to cause
  a canonical payout; keep normal ownership refresh on foreground/root entry.
- [x] Add safe copy for delayed processing, rejection, and retry without showing
  pending gold as wallet value.

Done when:

- [ ] Town header and every gold affordance agree on the same amount
- [ ] leaving Game Over before settlement cannot affect whether the server pays
- [ ] Collect is presentation-only under stale status updates and polling

Focused tests:

- [ ] Hub, Town, and Profile exclude provisional reward gold
- [ ] Game Over shows result context for pending settlement without wallet merge
- [ ] terminal validated refreshes and displays canonical settled gold once
- [ ] Collect cannot mutate AppState progression or call an economy API
- [ ] app restart/background during pending settlement has no local payout
  obligation and later observes the server-settled wallet

---

## Phase 6 — Execute Legacy Migration and Cut Over

Objective:

- move existing data to the new invariant without relying on normal client
  reads

Tasks:

- [ ] Deploy protocol/client compatibility from Phase 1 before enabling new
  server-state emission.
- [ ] Deploy the Phase 2 settlement helper, dispatcher, repair job, metrics, and
  dashboards with the dispatcher disabled or scoped to internal test users.
- [ ] Build and run the legacy inventory/backfill using an idempotent server-side
  adapter; record every repaired, skipped, and invariant-violating item.
- [ ] Verify every reward-eligible terminal `validated` run has the grant id in
  canonical `appliedRewardGrantIds`.
- [ ] Enable validator `settlement_pending` handoff for an internal cohort, then
  progressively expand according to observed latency/error targets.
- [ ] Keep legacy read-time reconciliation enabled only as monitored repair
  during the migration window.
- [ ] Remove routine reconciliation from `loadOrCreateCanonicalState` and
  ownership command execution only after inventory, repair, and telemetry prove
  that new payouts do not depend on it.
- [ ] Remove retired flags, state branches, and tests in one cleanup pass after
  the rollback window closes.

Done when:

- [ ] migration inventory is empty or each exception has an explicit incident
  disposition
- [ ] normal client navigation cannot trigger payout completion for a new run
- [ ] legacy reconciliation has a documented retirement commit and no active
  production dependency

---

## Phase 7 — Observe, Validate, and Optimize

Objective:

- prove correctness and latency in a real deployment before adding optional
  performance work

Tasks:

- [ ] Validate the initial operational targets from the strategy:
  - [ ] Game Over slow-path threshold: 10 seconds from durable finalize
  - [ ] finalize-to-`settlement_pending`: p95 ≤ 8 seconds, p99 ≤ 30 seconds
  - [ ] `settlement_pending`-to-terminal: p95 ≤ 2 seconds, p99 ≤ 15 seconds
  - [ ] stale repair attempts begin within five minutes of the configured stale
    threshold
- [ ] Verify dashboards distinguish validation delay, dispatcher delay,
  transaction conflict, invariant violation, and optional projection delay.
- [ ] Exercise an end-to-end scenario with the app closed after finalize and
  confirm the server settles before the next ownership read.
- [ ] Exercise duplicate task/event/repair delivery and concurrent ownership
  command scenarios in staging.
- [ ] Add the optional fast validation lane only after the durable path meets
  the targets:
  - [ ] durable Cloud Tasks fallback exists before fast dispatch
  - [ ] fast invocation uses trusted service identity
  - [ ] it uses the existing validator lease and Phase 2 settlement authority
  - [ ] it has independent metrics and a rollback flag

Done when:

- [ ] production telemetry satisfies the strategy's correctness invariants
- [ ] alerting and the operator runbook have been exercised
- [ ] fast validation, if enabled, changes latency only—not settlement semantics

---

## Phase 8 — Required Validation Commands

Run the smallest relevant checks after each touched slice, then run the full
cross-layer set before rollout:

- [x] `dart analyze packages/run_protocol`
- [x] `dart test packages/run_protocol/test`
- [x] `dart analyze services/replay_validator`
- [x] `dart test services/replay_validator/test`
- [x] `corepack pnpm --dir functions build`
- [x] `corepack pnpm --dir functions test`
- [x] `dart analyze lib/ui`
- [ ] focused `flutter test` targets for AppState, submission status, Game Over,
  Hub, Town, and Profile
- [ ] relevant integration/emulator test proving settlement without a client
- [x] production deployment verification for Firestore event retry and
  scheduled repair configuration

## Final Acceptance Checklist

- [ ] Persistent UI has exactly one wallet and it is canonical
  `progression.gold`.
- [ ] Final reward projection and terminal validated status are impossible before
  the atomic canonical settlement commit.
- [ ] The exact grant id is recorded in canonical applied-grant ids for every
  reward-eligible terminal validated run.
- [ ] Duplicate validation tasks, event delivery, repair, and transaction retry
  cannot double-credit gold, progression hooks, or canonical revision.
- [ ] Rejected, revoked, malformed, mismatched, or overflowed reward data cannot
  mutate the wallet.
- [ ] Client closure, app restart, backgrounding, and lost local spool state
  cannot prevent server payout completion.
- [ ] Ownership commands racing settlement follow normal revision/idempotency
  behavior and cannot spend a falsely displayed balance.
- [ ] Legacy read-time reconciliation is no longer part of the normal new-run
  path and is removed after the migration window.
- [ ] Collect is presentation-only and delayed Game Over exit never traps a
  player.
- [ ] Metrics, alerts, repair procedures, and rollback controls are verified
  before broad rollout.
