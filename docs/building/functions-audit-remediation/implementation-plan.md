# Firebase Functions Audit Remediation Plan

- Created: July 18, 2026
- Status: Production verification recorded; owner-dependent rollout and closure gates remain
- Evidence baseline:
  [Firebase Functions Audit — 2026-07-18](../../audit/functions/functions-audit-2026-07-18.md)
- Read-only live configuration:
  [Functions Remediation Live Configuration Baseline — 2026-07-18](live-configuration-baseline-2026-07-18.md)
- Production deployment:
  [Functions Audit Remediation Production Deployment — 2026-07-19](production-deployment-2026-07-19.md)
- Production verification:
  [Functions Audit Remediation Production Verification — 2026-07-19](production-verification-2026-07-19.md)
- App Check web rollout:
  [App Check Client Rollout Evidence — 2026-07-19](app-check-client-rollout-2026-07-19.md)
- Quota rollout:
  [Quota Selection and Enforcement Evidence — 2026-07-19](quota-selection-and-enforcement-2026-07-19.md)

## Purpose

Close findings F-01 through F-12 from the July 18 Firebase Functions audit
without weakening authentication, deterministic replay validation, ownership
revision/idempotency, reward settlement, or account-erasure guarantees.

The audit is an immutable point-in-time evidence record. This document is the
active source of truth for remediation order, implementation status, validation
evidence, rollout, and closure. Do not edit the audit to reflect later fixes.

## Relationship to Existing Plans

This plan coordinates existing active domain plans rather than replacing their
detailed designs:

- F-02 server-time authority is also tracked by the
  [run-start latency corrective plan](../optimizeStartRun/plan.md) and its
  [implementation checklist](../optimizeStartRun/implementation-checklist.md).
- F-04, F-07, and F-08 settlement/reward lifecycle work must stay aligned with
  the
  [gold-grant settlement strategy](../goldGrantVerification/strategy-refresh.md)
  and
  [implementation checklist](../goldGrantVerification/implementation-checklist.md).
- F-01 ownership and entitlement changes must preserve the server-authoritative
  store rules in the
  [Town store plan](../store/town-store-rewarded-refresh-plan.md) and
  [implementation checklist](../store/town-store-implementation-checklist.md).
- F-02, F-06, and F-08 must preserve the replay lifecycle and retention
  contracts in the
  [replay-validation plan](../replayValidation/replay-validation-plan.md) and
  [implementation checklist](../replayValidation/replay-validation-implementation-checklist.md).

When a finding changes behavior already covered by one of those documents,
update that domain document in the same change. This plan owns the final audit
closure status even when a domain plan owns the detailed implementation.

## Goals

- Restore server authority over currency, entitlements, loadouts, run time, and
  board windows.
- Make settlement repair, upload expiry, provisional rewards, profile mutation,
  and account erasure converge under retries and concurrency.
- Bound authenticated resource consumption and idempotency storage.
- Remove known production dependency vulnerabilities or record a reviewed,
  time-bounded exception.
- Make the test/runtime harness representative of the Node 24 deployment.
- Produce staging and production evidence for configuration that local emulator
  tests cannot verify.

## Non-goals

- Redesigning deterministic Core gameplay.
- Replacing replay validation with a live authoritative game server.
- Introducing a second ownership wallet or client-side reward authority.
- Preserving dangerous public command paths for compatibility.
- Treating App Check as a substitute for authorization or rate limiting.
- Closing findings solely because code was merged.
- Editing generated `functions/lib/**` or `functions/lib_test/**`.

## Status Model

Use these exact statuses in the tracking table:

| Status | Meaning |
| --- | --- |
| `Open` | The audit finding is confirmed and implementation has not started. |
| `In progress` | Design or implementation work is active. |
| `Code complete` | Source, tests, and required docs are complete locally. |
| `Validated` | All local and staging acceptance checks pass. |
| `Deployed` | The compatible implementation and configuration are deployed. |
| `Production verified` | Required production behavior and telemetry are recorded. |
| `Closed` | All finding-specific closure criteria and evidence are satisfied. |
| `Risk accepted` | A named owner approved a time-bounded exception with an expiry date. |

`Code complete`, `Deployed`, and `Closed` are different states. A checkbox is
not closure evidence unless it links to a test result, deployment record,
production query, or approved risk record.

## Finding Tracker

All findings start open. Update this table as work lands.

| ID | Severity | Phase | Status | Implementation evidence | Validation/deployment evidence |
| --- | --- | ---: | --- | --- | --- |
| F-01 | Critical | 1 | Production verified | Public command allowlist and transactional loadout authorization | Public reward rejection, valid settlement, ownership inventory, and no-repair adjudication are in the [production verification](production-verification-2026-07-19.md) |
| F-02 | Critical | 1 | Production verified | Callable-owned clock plus validator ticket/window gates | Client-time rejection and legacy ticket/window adjudication are in the [production verification](production-verification-2026-07-19.md) |
| F-03 | High | 2 | Production verified | Functions 7.3.0, Admin 14.2.0, Cloud Tasks 6.2.3, patched dependency graph | No known vulnerabilities; Node 24, signed URLs, task retry, triggers, and schedules are production verified |
| F-04 | High | 3 | Deployed | Cursor-paged repair, legacy classifier, quarantine, and explicit retry disposition | Multi-page and exact-once tests pass; repair/validator revisions and queue policy are deployed |
| F-05 | High | 4 | Production verified | Tombstone-first leased deletion, strict guards, early Auth disable, and repeated reconciliation | Two synthetic workflows converged, including the complete canary; age, Auth, Storage, projection, and final-pass evidence are recorded; privacy review remains |
| F-06 | High | 5 | In progress | App Check rollout, payload bounds, atomic quotas, idempotent run creation, replay cap, and bounded idempotency | Quotas are selected, load-tested, and production-enforced; retention and migration are complete; web attestation is verified; native App Check measurements, channel confirmation, and App Check enforcement remain |
| F-07 | Medium | 3 | Deployed | Shared transactional expiry before callable error return | Expiry, repeat, and cleanup-race tests pass; remediated Functions source is deployed |
| F-08 | Medium | 3 | Production verified | Atomic provisional-grant revocation, projection suppression, and orphan cleanup | The invalid replay was rejected, its grant was revoked, and leaderboard/ghost projection was suppressed in production |
| F-09 | Medium | 6 | Deployed | Server-time transactional rename cooldown | Boundary/concurrency and focused Flutter tests pass; authoritative profile Functions are deployed |
| F-10 | Medium | 6 | Production verified | Transactional profile creation plus consistency repair | Live profile/index inventory and the repair schedule found zero mismatches or repairs |
| F-11 | Low | 2 | Production verified | Node 24 test harness and explicit Firestore deny tests | 167/167 tests pass; Node 24 Functions, Firestore rules, and required indexes are live |
| F-12 | Low | 2 | Production verified | Auth-first lazy external dependency construction | Production unauthenticated and UID-mismatch checks fail before domain work or dependency use |

## Read-only Baseline Record — July 18, 2026

This record contains identifiers needed to reproduce the audit-remediation
baseline without copying IAM policy or environment-secret output into the
repository.

- Local branch/commit at inspection: `master` /
  `d924895cf32f25abd6fdc4f3317fbfbc9936dcc9`.
- The working tree was already dirty with settlement, projection, validator,
  editor, and documentation work. Those changes were preserved and are not
  represented by the local commit identifier.
- Configured live project: `rpg-runner-d7add`.
- Active Functions are second generation, Node.js 24, region
  `europe-west1`, and report Firebase source hash
  `d6a94d180b584255231040aa2c8b1cb6878c3e03`.
- `loadoutOwnershipExecuteCommand` live revision:
  `loadoutownershipexecutecommand-00006-qow`, created
  `2026-07-18T20:26:16.573629Z`.
- `runSessionCreate` live revision:
  `runsessioncreate-00006-bil`, created
  `2026-07-18T20:26:16.421839Z`.
- Replay validator live revision: `replay-validator-00020-ps7`, created
  `2026-07-18T19:54:14.486824Z`.
- A read-only download of the deployed Functions source artifact confirmed
  that the live ownership parser has no client-command allowlist and the live
  run validators/handlers still accept and forward request `nowMs`.
- No deployment, IAM change, data mutation, or repair was performed during
  this baseline inspection.

The exact Flutter client versions, complete IAM/task/scheduler/TTL/lifecycle
export, and whether every uncommitted local settlement file is represented by
the live revisions remain open Phase 0 tasks.

The linked read-only configuration baseline now records the web release,
Functions runtime/update range, public-versus-internal invoker posture, queues,
schedules, Eventarc triggers, Firestore protection/index/TTL state, and replay
bucket controls without storing IAM identities or environment values. Native
store releases, restricted log preservation, and exact local-to-deployed source
provenance remain open.

## Locked Implementation Order

1. Establish the deployment baseline and contain exploitable behavior.
2. Close F-01 and F-02 trust-boundary defects.
3. Upgrade dependencies and make the runtime/test harness release-equivalent.
4. Close settlement, expiry, and provisional-grant convergence defects.
5. Replace synchronous account erasure with a concurrency-safe workflow.
6. Add resource-abuse controls and bounded idempotency storage.
7. Close profile timestamp and creation races.
8. Run cross-layer staging validation and the live-project configuration audit.
9. Record production evidence, close findings, and archive this plan.

Later design and test preparation may proceed in parallel, but no broad rollout
may bypass the critical or high-severity gates.

## Global Invariants

Every phase must preserve these constraints:

1. A client may request an action but cannot choose its reward, entitlement,
   authoritative time, board window, or validation result.
2. Canonical ownership remains revisioned and transactionally idempotent.
3. `progression.gold` is the only spendable persistent wallet.
4. Ranked replay validation uses a server-issued ticket whose loadout was
   authorized against canonical ownership at issuance.
5. Settlement, projection, and ghost publication remain separate delivery
   lanes; projection failure cannot roll back wallet settlement.
6. Retried commands, tasks, triggers, schedules, and deletion pages converge
   without duplicate rewards or resurrected user data.
7. User callables authenticate and match UID before constructing external
   dependencies or touching state.
8. Direct client Firestore access stays fail-closed.
9. Contract changes update Functions, Flutter adapters/state, shared protocol,
   replay validator, tests, and documentation in the same change.
10. Migrations finish in one pass; do not leave a permanent insecure legacy
    path beside the new authority path.

---

## Phase 0 — Baseline, Containment, and Investigation

### Objective

Determine what is deployed, stop further exploitation if affected code is live,
and preserve enough evidence to repair existing data safely.

### Baseline tasks

- [ ] Record the exact commit, Functions revisions, Cloud Run validator
  revision, Flutter web/native versions, and deployment timestamp currently
  serving production.
- [ ] Record whether the uncommitted settlement files present during the audit
  are deployed, pending deployment, or local-only.
- [ ] Land or isolate unrelated dirty-worktree changes before implementation so
  audit remediation commits have reviewable scope.
- [x] Export the deployed Functions configuration, IAM invoker bindings, task
  queue settings, scheduler jobs, Firestore indexes/TTL policies, and Storage
  lifecycle settings into a restricted deployment record. Non-secret evidence
  is linked above; identity detail remains in the restricted cloud policy.
- [ ] Preserve relevant Functions, Firestore, Cloud Tasks, and validator logs
  for the investigation window.

### Immediate containment

- [x] If F-01 is deployed, make the public ownership callable reject
  `awardRunGold`, `learnProjectileSpell`, `learnSpellAbility`, `unlockGear`,
  and production `resetOwnership` requests before any state mutation.
- [x] If an immediate safe ownership patch cannot deploy, temporarily disable
  the affected command endpoint and surface a controlled maintenance error.
  Not required because the direct patch deployed successfully.
- [x] If F-02 is deployed for ranked modes, deploy the server-time boundary fix
  or temporarily suspend new ranked ticket issuance; do not accept
  client-selected board windows.
- [x] Confirm the replay validator and settlement services remain available
  while dangerous client award paths are blocked.
- [x] Record containment start/end times and the exact behavior disabled.

### Data investigation

- [x] Inventory canonical gold deltas attributable to public `awardRunGold`
  commands versus validated settlement grants.
- [x] Find repeated, synthetic, or impossible awarded run IDs and balances.
- [x] Compare equipped/selected gear, spells, abilities, characters, and
  loadouts with canonical ownership and the server catalog.
- [x] Identify ranked tickets whose issued/expiry times fall outside expected
  server time or whose board window does not contain issuance.
- [ ] Identify managed boards created outside expected scheduler/callable
  windows.
- [x] Identify accepted runs bound to impossible tickets or unauthorized
  loadouts.
- [x] Produce a repair candidate set without mutating data during inventory.
- [x] Define the recovery policy for affected balances, ownership, leaderboard
  entries, and ghosts before applying corrections.

### Done when

- [x] Deployed exposure is known and contained.
- [ ] Current deployed and local baselines are reproducible.
- [ ] Investigation queries, counts, and proposed repair policy are reviewed.
- [x] No destructive repair has occurred without an approved rollback/export.

---

## Phase 1 — Restore Client Trust Boundaries

### F-01 — Ownership, entitlement, economy, and loadout authority

#### Target design

The public callable supports only user-intent commands. Server-originated
rewards and entitlement grants use internal domain functions that are not
reachable through a client-selected command type.

Public commands may include semantic selection/equip actions and
server-validated store purchase/refresh actions. They may not include:

- reward credit;
- direct entitlement learning/unlocking;
- reset/admin operations;
- arbitrary canonical document or whole-selection replacement.

The server validates selected content twice:

1. when the ownership command mutates canonical selection/loadout; and
2. when a run ticket snapshots that loadout.

The second check is defense in depth against legacy or corrupted canonical
documents.

#### Implementation

- [x] Split the public command type allowlist from internal ownership mutation
  operations.
- [x] Remove `awardRunGold`, `learnProjectileSpell`, `learnSpellAbility`,
  `unlockGear`, and `resetOwnership` from the production client-callable path.
- [x] Remove the matching callable methods and command DTOs from Flutter APIs,
  controllers, pending-command/outbox logic, and tests where they imply client
  authority.
- [x] Route verified run gold exclusively through the Functions-owned
  settlement transaction.
- [x] Route permanent unlocks through verified store purchase/progression
  helpers with price, offer, ownership, and revision checks.
- [x] Replace public whole-selection mutation with narrow semantic commands. If
  a transitional selection command is unavoidable within the same migration,
  normalize and authorize every nested field before write and remove it once
  callers migrate.
- [x] Build or centralize a backend content catalog that can validate:
  - [x] known character IDs;
  - [x] known level/mode combinations;
  - [x] item domain and equipment slot compatibility;
  - [x] owned gear;
  - [x] learned projectile spells;
  - [x] learned abilities and allowed ability slots.
- [x] Make `equipGear`, `setAbilitySlot`, `setProjectileSpell`, and any retained
  loadout command prove ownership/learning transactionally.
- [x] Make run-session creation reject a canonical snapshot containing unknown,
  incompatible, or unowned content.
- [x] Preserve revision, payload hashing, and idempotency semantics for all
  remaining public commands.
- [x] Decide how old offline outbox entries for removed command types are
  discarded and surfaced without infinite retry.
- [x] Complete the approved production data repair from Phase 0. The inventory
  produced no mutation candidate; the two legacy tickets were adjudicated
  without rewriting accepted evidence.

#### Tests

- [x] An authenticated caller cannot submit each server-only command type.
- [x] Unknown command types fail before a Firestore write.
- [x] A unique run ID cannot credit gold through the ownership callable.
- [x] A caller cannot unlock or learn arbitrary catalog IDs.
- [x] A caller cannot equip known-but-unowned content.
- [x] A caller cannot place an unlearned ability or projectile spell.
- [x] A caller cannot inject an arbitrary whole selection/loadout.
- [x] Store purchase still unlocks exactly once and charges exact gold once.
- [x] Settlement still credits validated gold exactly once.
- [x] Run creation rejects corrupted/legacy unauthorized canonical loadouts.
- [x] Allowed selection/equip commands preserve revision and idempotency
  behavior.
- [x] Flutter pending-command recovery terminates removed commands safely.

#### Documentation

- [x] Update `docs/tdd/firebase_cloud_functions_overview.md`.
- [x] Update ownership/authentication TDDs and public Flutter API docs.
- [x] Correct the Town store plan's obsolete client `awardRunGold` and direct
  unlock baseline.
- [ ] Update relevant GDD ownership/store/loadout rules if the documented
  player-facing unlock flow is incomplete or stale.

#### F-01 closure

- [x] No client-callable type can directly grant gold or entitlements.
- [x] Every newly issued ticketed loadout is catalog-valid and owned.
- [x] Existing affected data has been inventoried and repaired or explicitly
  adjudicated.
- [x] Negative emulator and Flutter contract tests pass.
- [x] Production rejection/settlement telemetry is verified.

### F-02 — Server-time authority

The
[run-start corrective plan](../optimizeStartRun/plan.md#workstream-0-restore-server-time-authority)
owns the detailed callable changes. This section adds audit closure requirements.

#### Implementation

- [x] Remove `nowMs` from public run, board, leaderboard, upload-grant, and
  finalize request interfaces.
- [x] Explicitly reject or ignore a supplied legacy `nowMs` at the public
  boundary, and record the chosen compatibility behavior in the TDD.
- [x] Introduce a testable internal clock abstraction below callable handlers.
- [x] Make public handlers capture server time once per operation and pass that
  value through all related calculations.
- [x] Use server time for board-window resolution/provisioning, ticket
  issue/expiry, run timestamps, upload leases, finalize expiry, and active-board
  reads.
- [x] Make replay validation reject:
  - [x] expired tickets;
  - [x] tickets issued beyond allowed clock skew;
  - [x] issuance outside the bound board window;
  - [x] impossible `expiresAtMs <= issuedAtMs`;
  - [x] expiry durations outside the protocol policy.
- [x] Ensure cleanup and validation use the same documented time units and
  expiry policy.
- [x] Inventory and adjudicate impossible boards/tickets/runs from Phase 0.

#### Tests

- [x] Forged past/future request time cannot influence a public response or
  persisted timestamp.
- [x] Historical board-boundary tests use an injected internal clock.
- [x] Upload lease duration and finalize expiry use server time.
- [x] Replay validation covers expired, future-issued, wrong-window, and
  malformed-duration tickets.
- [x] Competitive and weekly exact UTC boundary tests remain deterministic.
- [x] Normal Flutter request compatibility remains intact.

#### F-02 closure

- [x] No public request field influences an authority-time decision.
- [x] Validator expiry and board-window checks are deployed.
- [x] Existing impossible timestamp data is repaired, invalidated, or
  explicitly adjudicated.
- [x] The run-start plan's Phase 0 authority items are complete.
- [x] Production authority and telemetry evidence are recorded under the
  approved no-staging waiver.

### Phase 1 validation

- [x] `corepack pnpm --dir functions build`
- [x] `corepack pnpm --dir functions test` — 167 passed with complete compiled
  test discovery
- [x] `dart analyze packages/run_protocol`
- [x] `dart test packages/run_protocol/test` — 35 passed
- [x] `dart analyze services/replay_validator`
- [x] `dart test services/replay_validator/test` — 65 passed
- [x] `dart analyze` — no issues
- [x] Relevant Flutter ownership, profile, run, submission, and account state
  tests — 118 passed
- [x] `corepack pnpm --dir functions audit --prod` — no known vulnerabilities

### Phase 1 done when

- [x] F-01 and F-02 are at least `Validated`.
- [x] No dangerous compatibility path remains callable.
- [x] Cross-layer contracts and documentation agree.
- [x] Replay, settlement, leaderboard, and ghost flows pass end to end in the
  approved production canary.

---

## Phase 2 — Dependencies, Runtime, Tests, and Authentication Order

### F-03 — Production dependency remediation

#### Implementation

- [x] Capture the original advisory report and lockfile hash. The immutable
  audit records 31 production findings; the pre-upgrade lockfile SHA-256 was
  `e0cc931d33ca6d030e5191ac04e1c8b77cc85cf585861af66be08abaaf813dd8`.
- [x] Upgrade `firebase-admin`, `firebase-functions`, and
  `@google-cloud/tasks` to supported compatible releases.
- [x] Regenerate `pnpm-lock.yaml` using the repository package manager.
- [x] Review current SDK documentation for Node support, callable behavior,
  App Check,
  Firestore transactions, Storage signing, Cloud Tasks, and Eventarc changes.
- [x] Keep only the two narrow `uuid` overrides required by current
  `gaxios@6.7.1` and `teeny-request@9.0.0`; both consumers call the preserved
  `uuid.v4()` API. Remove the overrides once their upstream ranges resolve a
  patched version.
- [x] For any remaining critical/high advisory, record (none remain):
  - [ ] dependency and vulnerable path;
  - [ ] application reachability;
  - [ ] compensating control;
  - [ ] named risk owner;
  - [ ] expiry/update date.

#### Validation

- [x] Production dependency audit has no unreviewed critical/high finding and
  currently reports no known vulnerability.
- [x] Build and all tests pass on Node 24.
- [x] Callables start without deprecation/config warnings in the approved
  production canary used in place of staging.
- [x] Storage signed upload/download URLs work.
- [x] Cloud Tasks dispatch and duplicate task handling work.
- [x] Firestore trigger and scheduled functions deploy successfully.

### F-11 — Test/runtime harness alignment

#### Implementation

- [x] Replace the explicit test-file list with deterministic discovery of all
  compiled `functions/test/**/*.test.ts` outputs.
- [x] Fail CI when a source test has no compiled/runnable counterpart.
- [x] Replace the empty “backfill is retired” test with real
  `off`/`inventory`/`apply` migration tests while the schedule exists.
- [ ] After the bounded migration is complete, remove the migration export,
  environment controls, tests, and documentation in one cleanup change.
- [x] Run Functions CI on Node 24, matching `package.json`.
- [x] Pin/document Firebase CLI `15.2.1` in `functions/package.json`.
- [x] Resolve the `firebase.json` `flutter` warning without deleting
  FlutterFire metadata: Functions tests use the focused `firebase.test.json`
  configuration accepted by the pinned CLI.
- [x] Configure emulator project IDs/single-project behavior so expected tests
  do not produce misleading warnings.
- [x] Add a Firestore rules test proving direct clients cannot read/write every
  server-owned collection, including collections that currently rely on
  unmatched default deny.

### F-12 — Authenticate before external dependency construction

#### Implementation

- [x] Change upload-grant, finalize, and ghost handlers to accept optional
  dependencies without default-argument construction.
- [x] Authenticate and match UID before resolving Storage/Cloud Tasks
  dependencies.
- [x] Lazily construct dependencies once after authorization.
- [x] Apply the same review to every callable export.

#### Tests

- [x] Unauthenticated calls return `unauthenticated` with production dependency
  injection omitted and environment variables absent.
- [x] UID mismatch returns `permission-denied` before external client creation.
- [x] Authorized calls still report missing production configuration as
  `failed-precondition`.

### Phase 2 done when

- [x] F-03, F-11, and F-12 are at least `Validated`.
- [x] The default test command discovers and passes every backend test on
  Node 24.
- [x] The dependency audit and any accepted exceptions are recorded.
- [x] Firebase emulator output contains no unexplained configuration warning.

---

## Phase 3 — Settlement and Submission Lifecycle Convergence

Keep this phase synchronized with the gold-grant strategy/checklist.

### F-04 — Progress-safe settlement repair

#### Target behavior

Retryable infrastructure failures remain eligible for repair. Persisted-data
contradictions become explicit operator incidents and are excluded from normal
repair pages without changing canonical gold.

#### Implementation

- [x] Define and document a server-owned retry disposition for each
  `settlement_pending` session.
- [x] Ensure invariant violations are atomically quarantined or marked
  non-retryable.
- [x] Preserve the contradictory documents and identifiers needed for operator
  investigation.
- [x] Query only retryable work with stable ordering and cursor pagination.
- [x] Record retry attempts and outcomes; the five-minute schedule remains the
  retry cadence rather than adding a second Cloud-delivery backoff policy.
- [x] Ensure a failed page resumes after its last confirmed item.
- [x] Add metrics for:
  - [x] retryable pending count and oldest age;
  - [x] quarantine count;
  - [x] page cursor/progress;
  - [x] attempts and outcomes;
  - [x] no-progress scans.
- [x] Update the repair runbook with quarantine inspection and approved
  operator resolution.

#### Tests

- [x] More than one batch of pending records is processed.
- [x] A full batch of invariant violations cannot starve later valid records.
- [x] Duplicate Eventarc/immediate/repair delivery remains exactly-once.
- [x] Transaction conflicts and infrastructure errors remain retryable.
- [x] Quarantine never credits or revokes gold automatically.
- [x] Cursor resume neither skips nor double-applies a valid grant.

### F-07 — Persist expiry before returning an error

#### Implementation

- [x] Replace transaction-callback throw-after-write with a committed transition
  result.
- [x] Return the callable error only after the `expired` state commits.
- [x] Make concurrent grant/finalize/cleanup attempts converge on the same
  terminal state.
- [x] Keep terminal message/timestamps server-authored.

#### Tests

- [x] Upload-grant expiry persists `expired`.
- [x] Finalize expiry persists `expired`.
- [x] Repeated expiry attempts are idempotent.
- [x] Finalize racing cleanup cannot revive an expired session.

### F-08 — Reconcile provisional grants after dispatch failure

#### Implementation

- [x] Define the grant transition for terminal run expiry, rejection, and
  non-retryable dispatch failure.
- [x] Atomically move provisional grants to the appropriate revoked/final state
  whenever the run becomes terminal.
- [x] Suppress provisional reward projection when run/grant states are
  incompatible.
- [x] Add bounded orphan-grant cleanup after a documented grace period.
- [x] Prefer durable dispatch/outbox semantics so a transient enqueue failure
  remains retryable without client activity.
- [x] Ensure cleanup does not delete evidence needed by an active retry.

#### Tests

- [x] Finalize commit followed by enqueue failure is recovered server-side.
- [x] Enqueue failure followed by session expiry revokes the provisional grant.
- [x] Status never shows provisional reward for a terminal incompatible run.
- [x] Duplicate cleanup/dispatch cannot double-transition a grant.
- [x] Active validation grants are not deleted.

### Phase 3 documentation

- [x] Update `docs/tdd/firebase_cloud_functions_overview.md`.
- [x] Update `docs/tdd/reward_settlement_operations.md`.
- [x] Update `docs/tdd/replay_validator_worker.md`.
- [x] Update the gold-grant strategy and checklist statuses/evidence.
- [x] No shared wire state changed; the new repair disposition is
  server-internal and documented here and in the settlement TDD.

### Phase 3 done when

- [x] F-04, F-07, and F-08 are at least `Validated`.
- [x] Multi-page repair proves forward progress.
- [x] Every current production run/grant state pair is consistent; emulator
  cases converge or become an explicit incident.
- [ ] Staging forced-failure tests pass with the client closed.

---

## Phase 4 — Concurrency-Safe Account Erasure

### F-05 — Deletion state machine

#### Target workflow

1. The authenticated callable creates an idempotent deletion request/tombstone.
2. All user callables reject lazy creation and mutation for that UID.
3. Auth refresh tokens are revoked and the account is disabled.
4. A server-authenticated background worker deletes data/artifacts in bounded,
   resumable pages.
5. Reconciliation repeats until every registered location is empty.
6. Firebase Auth is deleted.
7. A minimal completion record is retained only for the documented operational
   and legal retention period, then expires.

#### Design tasks

- [x] Define deletion-request states, attempt metadata, cursor/checkpoint data,
  and terminal outcomes in a TDD.
- [ ] Define the minimal retained deletion audit data and TTL with privacy/legal
  review.
- [x] Define how the Flutter client handles `requested`, `in_progress`,
  `complete`, and retryable failure without requiring the deleted account to
  remain authenticated.
- [x] Register every current user-data collection, projection, cached view, and
  Storage prefix in one deletion inventory.
- [x] Define the update rule that requires new schemas to extend this inventory.

#### Implementation

- [x] Create the deletion tombstone before any destructive sweep.
- [x] Add a shared deletion guard to profile, ownership, run, board,
  leaderboard, ghost, and other user callables.
- [x] Prevent profile/ownership lazy creation once deletion is requested.
- [x] Revoke tokens and disable Auth early; delete Auth after reconciliation.
- [x] Move destructive work into an IAM-authenticated Cloud Task/worker.
- [x] Page Firestore queries and Storage listings with durable cursors.
- [x] Use idempotent delete operations and tolerate already-missing data.
- [x] Repeat queries until empty rather than relying on a single snapshot.
- [x] Rebuild/invalidate affected leaderboard and ghost projections.
- [ ] Record retryable versus terminal operator incidents.
- [ ] Add metrics and alerts for age, attempts, failures, and incomplete
  deletion.
- [x] Update the account-delete callable/client response contract atomically.

#### Tests

- [x] Concurrent writes after tombstone creation are rejected.
- [x] Concurrent lazy loads cannot recreate profile/ownership data.
- [ ] Failure after each deletion stage resumes without losing coverage.
- [x] Accounts larger than one page are fully erased.
- [x] Repeated delete requests resolve to the same workflow.
- [x] Missing documents/objects do not fail the workflow.
- [x] Leaderboard/ghost views no longer expose the deleted user.
- [x] Auth disable/delete ordering and already-deleted users are handled.
- [x] Final reconciliation detects a deliberately reinserted test record.

#### Documentation

- [x] Update `docs/tdd/firebase_cloud_functions_overview.md`.
- [x] Update `docs/tdd/authentication_flow_and_authorization.md`.
- [x] Update `docs/EU-compliance/checklist.md`.
- [ ] Update the privacy/data-retention documentation and public deletion
  behavior if the user-visible contract changes.

### F-05 closure

- [x] No authenticated request can recreate data after deletion begins.
- [x] The workflow is resumable and page-bounded.
- [ ] Staging concurrency/failure tests pass.
- [x] Production deletion age/failure telemetry and one controlled verification
  are recorded.

---

## Phase 5 — Resource Abuse, Idempotency Retention, and Cost Controls

### F-06 — Layered abuse controls

#### Policy decisions

- [x] Define per-UID limits for ownership commands, active run sessions, upload
  grants, finalized replay bytes, expensive leaderboard reads, and ghost URLs.
- [x] Define burst and sustained windows from controlled normal-client
  measurements plus protocol/retry bounds.
- [x] Decide anonymous-account policy: controlled anonymous canaries use the
  same per-UID limits; release authentication remains Play Games, and account
  churn requires App Check rather than a privileged anonymous tier.
- [x] Define maximum request/string/array/object depth and serialized payload
  sizes.
- [x] Define the maximum offline command retry window.
- [x] Set idempotency retention longer than that retry window, then configure
  TTL/cleanup.
- [x] Define App Check rollout by Flutter platform, including debug/staging
  providers and an enforcement rollback.

Do not invent production limits without telemetry. Record the measurements and
rationale next to each chosen value.

#### Implementation

- [x] Add App Check token verification/enforcement to supported user callables.
- [x] Keep Firebase Auth and UID authorization checks after App Check.
- [x] Add atomic per-UID quota/rate state with bounded retention.
- [x] Reject over-limit work before Storage signing, task dispatch, or expensive
  Firestore reads.
- [x] Add an idempotent client request ID to run-session creation.
- [x] Bound concurrently active sessions and upload grants.
- [x] Bound replay size both at signed-upload policy and finalize metadata.
- [x] Store compact ownership idempotency outcomes instead of full canonical
  state snapshots.
- [x] Configure TTL/cleanup for idempotency and rate-limit documents.
- [x] Preserve payload-hash mismatch detection during the retention window.
- [x] Bound command ID length/format and JSON size/depth.
- [x] Add structured metrics for accepted/rejected quotas, App Check failures,
  bytes, active sessions, idempotency growth, and estimated cost drivers.

#### Tests

- [x] Valid app/auth requests remain accepted.
- [x] Missing/invalid App Check tokens follow the deployed monitoring mode;
  enforcement-mode production verification remains part of rollout.
- [x] Burst and sustained limits reject deterministically.
- [x] Concurrent requests cannot exceed an atomic quota.
- [x] Duplicate run-create request IDs return the same session.
- [x] Oversized/deep payloads fail before Firestore work.
- [x] Compact idempotency replay returns the contractually required result.
- [x] Reused command IDs with a different payload still fail.
- [x] TTL is longer than the supported offline retry window.
- [x] Cleanup cannot enable duplicate reward or purchase application.

#### Operational rollout

- [x] Deploy App Check in metrics/monitoring mode first where supported.
- [ ] Confirm legitimate platform attestation success rates.
- [x] Deploy the production web client and record one server-verified
  production-origin reCAPTCHA Enterprise attestation.
- [ ] Record release attestation measurements for every other in-scope
  platform, or explicitly exclude unsupported platforms.
- [ ] Complete the readiness gate for every in-scope platform, then enable the
  global callable enforcement switch with a documented rollback. Unsupported
  production platforms require explicit exclusion or separately reviewed
  endpoints; they cannot use a client-claimed bypass.
- [x] Load-test quotas and transactions in the isolated Firestore emulator
  under the no-staging waiver; record the high-fan-in contention boundary.
- [ ] Alert on sudden rejection, storage, task, and cost increases.

### F-06 closure

- [ ] High-value callables have layered app/auth/quota controls.
- [x] Idempotency and rate-limit storage are bounded.
- [x] Normal controlled clients, retries, and offline recovery remain
  functional under enforced quotas.
- [x] Isolated load plus production monitor/enforcement evidence are recorded
  under the no-staging waiver.

---

## Phase 6 — Server-Authoritative Profile Consistency

### F-09 — Rename cooldown

#### Implementation

- [x] Remove `displayNameLastChangedAtMs` from the client-write authority
  contract.
- [x] Read the existing profile and enforce the 24-hour cooldown inside the same
  transaction that reserves the new normalized name.
- [x] Define the initial-name exception explicitly.
- [x] Use one captured server timestamp for the cooldown decision and persisted
  value.
- [x] Return the authoritative timestamp to Flutter.
- [x] Keep client countdown display advisory; server rejection is final.
- [x] Define behavior for legacy future timestamps and repair impossible values.

#### Tests

- [x] Initial naming succeeds.
- [x] Rename before 24 hours fails.
- [x] Rename at the exact boundary succeeds.
- [x] Caller-supplied old/future timestamps cannot influence the result.
- [x] Concurrent rename attempts preserve uniqueness and cooldown.

### F-10 — Atomic first profile creation

#### Implementation

- [x] Replace non-transactional read-then-set with atomic create/reload or a
  transaction.
- [x] Keep profile and display-name index agreement in one transaction whenever
  a name is present.
- [x] Add a consistency checker/repair procedure for orphaned index claims.
- [x] Inventory existing index/profile mismatches before repair. The live
  read-only inventory and repair job found zero mismatches.

#### Tests

- [x] Concurrent first load calls create one equivalent profile.
- [x] First load racing first update preserves the chosen name and index.
- [x] Concurrent claims for the same normalized name have one winner.
- [x] Retry after transaction conflict returns the persisted profile.
- [x] Orphan repair never steals a valid claim from another UID.

### Phase 6 documentation

- [x] Update `docs/tdd/firebase_cloud_functions_overview.md`.
- [x] Update profile/authentication TDDs.
- [x] Update `docs/EU-compliance/checklist.md` if stored timestamp semantics
  change.
- [x] Update player-facing profile documentation for the authoritative
  24-hour rule.

### Phase 6 done when

- [x] F-09 and F-10 are at least `Validated`.
- [x] Profile/index inventory and any repair are complete.
- [x] Flutter displays only server-returned cooldown state.

---

## Phase 7 — Cross-Layer Release and Live-Project Verification

### Local validation matrix

- [x] Functions:
  - [x] `corepack pnpm --dir functions build`
  - [x] `corepack pnpm --dir functions test` (167/167)
  - [x] `corepack pnpm --dir functions audit --prod` (no known vulnerabilities)
- [x] Shared protocol:
  - [x] `dart analyze packages/run_protocol`
  - [x] `cd packages/run_protocol && dart test test` (35/35)
- [x] Replay validator:
  - [x] `dart analyze services/replay_validator`
  - [x] `cd services/replay_validator && dart test test` (73/73 after the
    production conflict-classification regression)
- [x] Flutter:
  - [x] `dart analyze`
  - [x] targeted ownership/profile/run/submission/account widget and state tests
    (`flutter test test/ui/state`, 118/118; targeted profile widget/API
    matrix, 34/34)
- [x] Firestore rules:
  - [x] authenticated and unauthenticated direct reads/writes fail for every
    server-owned collection
- [x] Repository:
  - [x] generated output was not hand-edited
  - [x] `git diff --check`
  - [ ] required TDD/GDD/building documents are current

### Staging verification

The repository owner waived a separate staging environment on July 19, 2026
because no staging project exists and the game has no live users. Production
was used as the empty-user canary. Unchecked authenticated end-to-end cases
remain required production verification; the waiver does not count them as
passed.

- [ ] Deploy compatible protocol/client readers before emitting any new state.
- [ ] Verify callable auth, UID mismatch, App Check, quota, and payload-bound
  failures.
- [x] Run one valid and one invalid replay through upload, validation,
  settlement, leaderboard projection, and ghost eligibility.
- [ ] Exercise immediate dispatch failure, Eventarc retry, scheduled repair,
  quarantine, and multi-page progress.
- [ ] Exercise upload expiry and enqueue failure with the client closed.
- [ ] Exercise account deletion with concurrent writes and more than one page.
- [ ] Exercise profile rename boundaries and concurrent first creation.
- [x] Confirm signed upload/download URL scope and TTL.
- [x] Confirm task queue identity, OIDC/IAM, retry, rate, and target policy.
- [x] Confirm scheduled jobs, regions, time zones, and Eventarc retry policy.
- [x] Confirm Firestore indexes and scheduled-retention policies match source
  assumptions.
- [ ] Confirm Storage IAM, CORS, lifecycle, object prefixes, and retention.

### Production rollout

- [x] Define the empty-user production canary and rollback posture under the
  repository owner's no-staging waiver.
- [x] Deploy server containment before clients can use removed dangerous
  commands.
- [ ] Deploy compatible Flutter clients and enforce a minimum compatible
  version where required.
- [x] Deploy the App Check-capable Flutter web release and verify its exact
  Hosting bundle and one production-origin attestation.
- [x] Deploy Functions/validator changes in the documented contract-safe order.
- [ ] Enable App Check enforcement and quotas gradually after monitoring mode.
- [x] Enable reviewed per-UID quotas after an isolated load test and a
  zero-would-reject production monitor canary.
- [x] Verify no spike in auth, stale revision, quota, App Check, upload,
  validation, settlement, or profile errors during the recorded canary window;
  longer observation remains.
- [ ] Verify settlement latency, pending age, quarantine count, repair progress,
  deletion age, idempotency growth, and resource cost.
- [x] Record exact deployed revisions and configuration.

### Finding closure review

For each F-01 through F-12:

- [ ] Link the implementing changes.
- [x] Link local and approved production-canary test evidence.
- [x] Link migration/inventory evidence when applicable.
- [x] Link deployment revision/configuration.
- [x] Link production verification or approved risk acceptance.
- [ ] Change the tracker status to `Closed` only after all required evidence is
  present.

### Plan completion

- [ ] All Critical findings are `Closed`.
- [ ] All High findings are `Closed` or have an unexpired named risk acceptance.
- [ ] All Medium and Low findings are `Closed`.
- [ ] The release-block decision is superseded by a dated closure review; the
  original audit remains unchanged.
- [ ] Move this plan to
  `docs/building/archived/functions-audit-remediation/implementation-plan.md`.
- [ ] Update active links that refer to this plan.

## Risks and Rollback Principles

| Risk | Mitigation and rollback principle |
| --- | --- |
| Old clients submit removed ownership commands | Reject safely server-side, stop infinite outbox retry, and enforce a compatible client version where necessary. Never restore client grant authority as rollback. |
| Ownership repair changes legitimate progress | Inventory first, export affected records, use reviewed deterministic repair rules, and retain an audit trail. |
| Server-time cutover invalidates forged/legacy tickets | Reject impossible tickets; do not grandfather ranked authority. Communicate maintenance if affected volume is material. |
| Dependency upgrade changes SDK behavior | Keep it isolated, test on Node 24, deploy to staging/canary, and roll back the package/lockfile together. |
| Settlement quarantine hides payable work | Alert on every quarantine, preserve artifacts, provide operator adjudication, and keep retryable work in a separate progressing queue. |
| Deletion tombstone locks an account after worker failure | Make deletion resumable and operator-visible; do not remove the tombstone to restore normal writes. |
| App Check blocks legitimate clients | Observe by platform before enforcement and keep a time-bounded configuration rollback, without weakening UID authorization. |
| TTL removes required idempotency evidence | Set retention beyond the supported retry window and never use TTL for reward-settlement proof that must be permanent. |
| New wire states break old clients | Deploy tolerant readers first, then writers; enforce minimum compatible versions before emission. |

## Decision Log

Record material changes to locked order, authority boundaries, state machines,
retention, quota values, or rollout here.

| Date | Decision | Rationale | Approved by |
| --- | --- | --- | --- |
| 2026-07-18 | Keep the audit immutable and track remediation in `docs/building/`. | Separates point-in-time evidence from active implementation status. | Repository owner |
| 2026-07-18 | Use this document as the umbrella tracker while retaining domain plans. | Avoids conflicting detailed designs for run start, settlement, store, and replay validation. | Repository owner |
| 2026-07-18 | Keep abuse limits unset in source and default both App Check and quota decisions to monitoring. | The plan prohibits invented production limits; telemetry and platform attestation success must precede enforcement. | Repository owner |
| 2026-07-18 | Support seven days of offline ownership-command retries and retain compact idempotency outcomes for 14 days. | Retention exceeds the supported retry window while bounding the former full-canonical storage amplification. | Repository owner |
| 2026-07-19 | Use production as the deployment canary and waive a separate staging deployment. | No staging project exists and the game has no live users; monitoring remains fail-open and authenticated end-to-end verification is still required. | Repository owner |
| 2026-07-19 | Do not mutate the two accepted pre-cutover tickets that lack embedded board-window fields. | Their issuance matches the canonical board windows and all identity/loadout/settlement evidence is valid; rewriting accepted ticket evidence adds risk without repairing an authority violation. | Pending closure review |
| 2026-07-19 | Add and deploy the `idempotency.expiresAtMs` collection-group ascending index. | The live retention job exposed the missing query prerequisite; after the index reached `READY`, all six legacy outcomes compacted successfully. | Repository owner (production authorization) |
| 2026-07-19 | Classify only structured HTTP 400 `FAILED_PRECONDITION` responses as Firestore contention. | Production returned this shape for an update-time race; arbitrary HTTP 400 input failures must not be broadened into retryable conflicts. | Repository owner (production authorization) |
| 2026-07-19 | Configure a domain-restricted reCAPTCHA Enterprise provider and deploy the App Check-capable web client while retaining monitor mode. | One verified production-origin sample proves the web path, but native platforms and sustained success rates remain unmeasured, so global enforcement would be premature. | Repository owner (production authorization) |
| 2026-07-19 | Source-control and enforce the reviewed per-UID quota defaults after isolated load validation and a zero-would-reject production monitor canary. | The game is not live and has no organic distribution; values combine the controlled-client maxima with protocol/retry bounds and generous margins. A complete enforcement canary passed all six routes. | Repository owner (production authorization) |
