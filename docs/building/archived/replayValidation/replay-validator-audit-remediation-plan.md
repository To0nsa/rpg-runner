# Replay Validator Audit Remediation Plan

Date: July 18, 2026  
Status: Complete; replay-validator release block removed July 21, 2026
Evidence baseline:
[Replay Validator Full Audit — July 18, 2026](../../audit/replay-validator-full-audit-2026-07-18.md)  
Baseline Git blob hash: `4b075d4b1b571d3c947d79f9b0bbb22c519aca20`
Successor evidence:
[Replay Validator Successor Audit — July 19, 2026](../../audit/replay-validator-successor-audit-2026-07-19.md)
Successor audit Git blob hash:
`f966a89f8b60c3b7c60dcfa1482d8e5ddbf6534b`
Closure evidence:
[Replay Validator Closure Audit — July 21, 2026](../../audit/replay-validator-closure-audit-2026-07-21.md)
Closure audit Git blob hash:
`df6eed4c8fac8689a7e4599f842d03aa5c1a113a`

Related active plans:

- [Replay Validation Production Plan](replay-validation-plan.md)
- [Replay Validation Implementation Checklist](replay-validation-implementation-checklist.md)
- [Gold Grant Verification Implementation Checklist](../goldGrantVerification/implementation-checklist.md)
- [Gold Grant Verification Backend Settlement Strategy](../goldGrantVerification/strategy-refresh.md)

Related implemented-behavior documentation:

- [Replay Validator Worker](../../tdd/replay_validator_worker.md)
- [Reward Settlement Operations](../../tdd/reward_settlement_operations.md)
- [Ghost Run Flow](../../tdd/ghost_run_flow.md)

## Purpose

This plan converts the July 18 replay-validator audit into active,
release-gated implementation work. It is the source of truth for remediation
status, sequencing, ownership boundaries, validation evidence, rollout, and
closure.

The audit is an immutable evidence baseline. Do not edit it to reflect later
implementation progress, corrections, or changed risk. Record:

- implementation progress and closure evidence in this plan;
- implemented architecture and invariants in the relevant `docs/tdd/**`
  documents;
- player-facing behavior changes in `docs/gdd/**` when applicable;
- newly discovered audit evidence in a new dated audit, not by rewriting the
  July 18 baseline.

When all work and release gates in this plan are complete, move this plan to
`docs/building/archived/replayValidation/` without changing or moving the
baseline audit.

## Current decision

The replay-validator-specific release block is removed. The July 21 closure
audit found no remaining release-blocking finding after every original and
successor row completed its implementation, deployed verification, production
inventory, and cleanup gate.

Production revision `replay-validator-00025-wfv` serves 100% on manifest digest
`sha256:92adcfe4bfc57647b0be5c11105aee9f466f555e786b51084f0a00fd5351fa22`.
Both queues were empty at final observation, the two temporary services and
temporary service identity were removed, and exact cleanup reported zero
residual data for both disposable accounts.

Closure evidence is in
[Release Closure Verification](release-closure-verification-2026-07-21.md) and
[Replay Validator Closure Audit](../../audit/replay-validator-closure-audit-2026-07-21.md).

On July 19 the repository owner confirmed that no staging project exists and
the game has no released users. Production is therefore the approved controlled
pre-release environment for smoke and disposable-account canary verification.
The owner later authorized an explicit fault-drill window. Lease expiry and
task exhaustion used a temporary private service and queue; concurrent
validation, overwrite rejection, projection recovery, and pagination used
bounded disposable fixtures while the affected production queue was empty.
Evidence and restoration checks are in
[Pre-Release Fault Drills](pre-release-fault-drills-2026-07-19.md).

## Local implementation update — July 18, 2026

The first local remediation tranche is implemented but is not production
closure evidence:

- token-fenced expiring validation leases, stale-lease reclaim, and scheduled
  bounded validation repair;
- compressed/expanded byte, JSON-depth, frame, duration, and simulation
  wall-time limits;
- atomic accepted, rejected, and exhausted-error Firestore handoffs;
- exact Storage generation capture, validation reads, validated-run lineage,
  leaderboard lineage, and generation-pinned ghost promotion;
- explicit replay/command decoding checks plus ticket identity, canonical
  loadout digest, compatibility allowlists, and immutable ranked-board windows;
- canonical shared tick-to-duration conversion;
- conditional player-best writes, version-preconditioned top-10 writes, and
  independent scheduled board reconciliation;
- empty-board and paginated ghost reconciliation;
- fail-closed readiness and projection stubs;
- checked-in queue/Cloud Run resource policy, unprivileged container runtime,
  bounded build contexts, and current Google API client dependencies.

Focused protocol, service, Storage/Firestore adapter, projection, ghost, and
Functions compile tests are passing. Full emulator/client/Core/container gates,
live inventory and repair, target-environment IAM/config verification, staged
fault injection, deployed smoke tests, and the successor audit remain open.
The evidence baseline hash was rechecked after implementation and remains
`4b075d4b1b571d3c947d79f9b0bbb22c519aca20`.

## Planning principles

### Selected approach: invariant-first remediation

Implement the work in dependency order:

1. freeze authority and recovery contracts;
2. make validation finite, fenced, and recoverable;
3. bind validation to immutable replay evidence and explicit compatibility;
4. make every terminal transition atomic or durably resumable;
5. make projection and ghost lifecycle convergent under retries and
   concurrency;
6. complete operational assurance, repair, and staged rollout.

This approach is preferred over isolated one-finding patches because lease,
retry, terminalization, projection, and storage-generation changes share wire
contracts and persisted state. They must be migrated together without parallel
legacy authority paths.

### Locked boundaries

- `packages/runner_core/**` remains the deterministic simulation authority.
- `packages/run_protocol/**` owns shared replay, ticket, validated-run,
  leaderboard, and ghost wire contracts.
- `functions/src/**` owns authenticated run issuance/finalization, canonical
  wallet settlement, scheduled repair, task creation, and backend operational
  controls.
- `services/replay_validator/**` owns replay input validation, deterministic
  replay execution, validation evidence, and non-wallet projection work.
- The validator must not duplicate canonical wallet normalization or gold
  application.
- The client never becomes a retry, validation, settlement, leaderboard, or
  ghost authority.
- Generated `functions/lib/**` and `functions/lib_test/**` outputs are never
  hand-edited.

### Locked safety invariants

Do not mark a phase complete if any invariant below is weakened.

- Every lease-owned write is fenced to the exact lease attempt.
- Every nonterminal validation state has a bounded automatic recovery path.
- Cloud Tasks and application state have one documented retry authority.
- External replay input has explicit byte, collection, tick, duration, and
  execution-time limits before or during consumption.
- The replay bytes validated are the exact immutable object generation later
  retained or promoted.
- Production decoding never relies on Dart assertions for untrusted-input
  safety.
- Ticket identity and every compatibility version are enforced explicitly.
- A terminal run state and its final reward-grant disposition cannot disagree.
- A worse player result cannot overwrite a better result under concurrency.
- Materialized top-10 and ghost state converge after duplicate delivery,
  partial failure, concurrency, and periods with no new player submissions.
- Missing production configuration fails closed and cannot acknowledge work.
- Raw backend exceptions are never persisted as player-visible messages.

## Finding traceability

| Audit ID | Severity | Remediation phase | Closure gate |
|---|---|---:|---|
| `RV-C01` | Critical | 1 | Fenced lease recovery and redelivery tests |
| `RV-C02` | Critical | 1 | Production repository grace round-trip test |
| `RV-C03` | Critical | 1 | Bounded-resource adversarial test and deployed limits |
| `RV-H01` | High | 1 | One retry authority plus lost-task repair |
| `RV-H02` | High | 2 and 5 | Generation-pinned validation and ghost promotion |
| `RV-H03` | High | 4 | Partial-projection convergence test |
| `RV-H04` | High | 4 | Concurrent best/top-10 convergence test |
| `RV-H05` | High | 4 and 6 | Fail-closed startup and readiness smoke test |
| `RV-H06` | High | 2 | Explicit AOT protocol rejection tests |
| `RV-H07` | High | 2 | Compatibility and immutable-board fixture matrix |
| `RV-H08` | High | 3 | Atomic rejection/internal-error fault-injection test |
| `RV-H09` | High | 5 | Paginated reconciliation and scheduled cleanup test |
| `RV-M01` | Medium | All phases and 6 | Risk-based adapter/integration coverage |
| `RV-M02` | Medium | 2 | Shared duration conversion contract tests |
| `RV-M03` | Medium | 6 | Readiness, telemetry, safe-error, and alert evidence |
| `RV-L01` | Low | 6 | Hardened container and bounded build context |
| `RV-L02` | Low | 6 | Correct executable docs and deployment configuration |
| `RV-L03` | Low | 6 | Reviewed dependency upgrade or documented deferral |

No finding is closed merely because source code changed. Closure requires the
phase's tests, documentation, data migration, deployment verification, and
recorded evidence.

## Locked implementation order

1. Phase 0 — Contract freeze, live inventory, and rollback preparation
2. Phase 1 — Fenced validation lifecycle, retry recovery, and resource bounds
3. Phase 2 — Immutable replay evidence and explicit compatibility
4. Phase 3 — Atomic rejection and internal-error finalization
5. Phase 4 — Convergent leaderboard projection
6. Phase 5 — Generation-pinned ghost lifecycle and retention
7. Phase 6 — Integration assurance, observability, and deployment hardening
8. Phase 7 — Data repair, staged rollout, and independent re-audit

Phases may be developed in parallel only where their contracts are already
frozen and their migrations do not overlap. A later phase cannot be deployed
before every earlier deployment gate passes.

---

## Phase 0 — Contract freeze, live inventory, and rollback preparation

Objective:

- turn the audit findings into explicit contracts and establish a recoverable
  production baseline before changing persisted state

### Contract decisions

- [x] Define the validation lease contract:
  - [x] unique lease/attempt token
  - [x] lease acquisition and expiry timestamps
  - [x] expected-state and update-time preconditions
  - [x] stale lease reclaim rules
  - [x] stale worker write rejection
  - [x] duplicate active-delivery behavior
- [x] Select and document one retry authority.
  - [x] Prefer Cloud Tasks queue policy for ordinary delivery retries.
  - [x] Treat persisted retry timestamps as observability or repair input, not
        an unimplemented scheduler.
  - [x] Define how scheduled repair restores work after queue exhaustion,
        deletion, or retention expiry.
  - [x] Define how the internal-error grace window survives task-budget
        exhaustion.
- [x] Define hard replay limits:
  - [x] compressed bytes
  - [x] expanded bytes
  - [x] JSON/object nesting where applicable
  - [x] frame count
  - [x] command count/density
  - [x] total ticks and duration
  - [x] maximum simulation wall time
- [x] Derive limits from currently valid content and expected gameplay duration;
      do not select values that reject issued tickets.
- [x] Define the immutable replay identity:
  - [x] bucket
  - [x] object path
  - [x] object generation
  - [x] content digest
  - [x] finalized timestamp
- [x] Define the supported compatibility matrix for:
  - [x] replay version
  - [x] command encoding version
  - [x] game compatibility version
  - [x] ruleset version
  - [x] score version
  - [x] ghost version
- [x] Define immutable board validation data captured at ticket issuance.
- [x] Define the projection truth model:
  - [x] player best is canonical per-player board state
  - [x] top 10 is a recoverable materialized view
  - [x] stale projection writers cannot replace newer revisions
  - [x] reconciliation does not depend on a new score arriving
- [x] Define one canonical tick-to-duration conversion rule.
- [x] Update the relevant TDD documents with these decisions in the same change
      that implements them. Proposed decisions remain in this building plan
      until implemented.

### Environment and data inventory

- [x] Record the deployed Cloud Run:
  - [x] image digest and revision
  - [x] service account
  - [x] region
  - [x] CPU and memory
  - [x] request timeout
  - [x] container concurrency
  - [x] minimum and maximum instances
  - [x] startup and readiness behavior
- [x] Record both validation and projection queue:
  - [x] region
  - [x] target URL
  - [x] OIDC service account and audience
  - [x] maximum attempts and retry duration
  - [x] minimum/maximum backoff and doublings
  - [x] dispatch rate and maximum concurrent dispatches
  - [x] task retention
- [x] Verify least-privilege IAM for Functions, task dispatch, validator,
      Firestore, and Storage paths.
- [x] Inventory persisted state without mutating it:
  - [x] `validating` sessions grouped by lease age
  - [x] `pending_validation` sessions grouped by next-attempt age
  - [x] internal-error retries grouped by first-error age
  - [x] terminal runs whose reward-grant state disagrees
  - [x] missing or malformed reward grants
  - [x] player-best/top-10 disagreement by board
  - [x] active ghost manifests outside top 10
  - [x] expired demoted manifests/objects
  - [x] replay objects whose finalized generation is missing from session data
- [x] Store counts and query timestamps in a dated rollout record; do not put
      production identifiers or sensitive payloads in repository docs.

### Rollback and migration preparation

- [x] Define deployment order for additive schema reads before new writes.
- [x] Define a bounded, cursor-based, idempotent repair command/job with
      `off`, `inventory`, and explicit `apply` modes.
- [x] Define rollback behavior that preserves new fields and never restores
      unfenced writes.
- [x] Define feature controls for:
  - [x] validation dispatch
  - [x] stale-lease reclaim
  - [x] automatic internal-error revocation
  - [x] leaderboard projection
  - [x] ghost publication
- [x] Confirm disabling a side effect cannot acknowledge and lose its durable
      task.

Done when:

- [x] every contract decision is recorded and reviewed
- [x] live configuration and data inventory is captured
- [x] migration and rollback paths are idempotent and bounded
- [x] no implementation phase relies on an unresolved authority decision

---

## Phase 1 — Fenced validation lifecycle, retry recovery, and resource bounds

Resolves: `RV-C01`, `RV-C02`, `RV-C03`, `RV-H01`

Objective:

- ensure validation work is finite, retry-safe, fenced, and automatically
  recoverable after worker or task failure

### Shared/session contract

- [x] Add additive lease metadata to the run-session contract.
- [x] Preserve backward reads for sessions created before the migration.
- [x] Ensure new writers emit the complete lease contract before strict reads
      are enabled.
- [x] Preserve the first internal-error timestamp across every repository
      decode, lease, retry, and terminal transition.
- [x] Distinguish public status/error codes from operator-only diagnostic
      details.

### Lease repository

- [x] Acquire a lease transactionally with:
  - [x] unique token
  - [x] expected source state
  - [x] incremented attempt
  - [x] start and expiry timestamps
  - [x] document precondition
- [x] Require the lease token on:
  - [x] retry scheduling
  - [x] accepted handoff
  - [x] rejection handoff
  - [x] internal-error terminalization
  - [x] any validation-owned message/status write
- [x] Reject every stale lease writer without mutating current state.
- [x] Reclaim expired `validating` sessions transactionally.
- [x] Make active duplicate delivery explicitly retryable or prove another
      durable recovery task exists before acknowledging it.
- [x] Handle an acquisition conflict separately from an already active lease;
      do not collapse invalid state and transient contention into success.

### Retry and repair

- [x] Check in declarative Cloud Tasks queue policy or an equivalent
      reviewable configuration source.
- [x] Align worker retry accounting with actual Cloud Tasks attempt headers.
- [x] Remove or rename application retry schedules that are not enforced.
- [x] Add a scheduled Functions repair job that:
  - [x] scans a bounded page
  - [x] requeues expired leases
  - [x] requeues orphaned pending validations
  - [x] respects the original internal-error grace start
  - [x] uses deterministic task names/idempotency
  - [x] emits repaired/skipped/conflict metrics
- [x] Ensure queue exhaustion cannot permanently strand a run.
- [x] Ensure incident-mode pause has a durable revisit mechanism.

### Bounded input and execution

- [x] Reject an object larger than the finalized compressed-byte contract
      before full materialization where possible.
- [x] Replace unbounded gzip decoding with bounded streaming decompression.
- [x] Stop decoding immediately when the expanded-byte limit is exceeded.
- [x] Enforce frame, command, tick, and run-duration limits before simulation.
- [x] Enforce a monotonic wall-time deadline during simulation.
- [x] Classify limit violations as stable player-input rejection, not transient
      infrastructure errors.
- [x] Prevent error messages from echoing large/malicious input.

### Deployment controls

- [x] Set explicit Cloud Run CPU, memory, timeout, concurrency, and maximum
      instances based on adversarial and representative load tests.
- [x] Set explicit queue dispatch rate and concurrent dispatch limits.
- [x] Ensure Cloud Run timeout exceeds the application deadline plus bounded
      terminal-write allowance.
- [x] Alert on container OOM, request timeout, lease expiry, and repair backlog.

### Required tests

- [x] crash immediately after lease acquisition
- [x] request timeout after lease acquisition
- [x] active duplicate task delivery
- [x] expired lease reclaim
- [x] stale worker attempting every write type
- [x] queue exhaustion followed by repair
- [x] internal-error grace across production repository round trips
- [x] incident mode across process restarts
- [x] gzip expansion past the limit
- [x] replay at and one unit beyond every size/count/tick limit
- [x] simulation deadline cancellation
- [x] concurrent reclaim attempts

Done when:

- [x] no worker crash or queue exhaustion can strand a run indefinitely
- [x] stale writers cannot terminalize a newer attempt
- [x] the first internal-error timestamp remains immutable
- [x] adversarial replay work remains within measured CPU, memory, and time
      budgets
- [x] deployed service and queue limits match checked-in policy

---

## Phase 2 — Immutable replay evidence and explicit compatibility

Resolves: `RV-H02` validation half, `RV-H06`, `RV-H07`, `RV-M02`

Objective:

- prove that validation uses an immutable finalized object and explicitly
  interprets only supported protocol/game rules

### Immutable upload lineage

- [x] Carry storage generation through:
  - [x] upload finalization record
  - [x] run session
  - [x] validator replay reference
  - [x] validated-run evidence
  - [x] leaderboard candidate
  - [x] ghost promotion input and manifest
- [x] Require finalized generation and digest for every newly finalized upload.
- [x] Read the exact generation from Cloud Storage with a generation
      precondition.
- [x] Reject a missing/replaced generation as a stable evidence failure.
- [x] Prevent upload URL reuse from changing finalized evidence:
  - [x] use generation preconditions on upload/finalization; or
  - [x] promote finalized bytes immediately to an immutable evidence object.
- [x] Preserve old-session handling explicitly; do not silently treat “latest”
      as the generation for legacy sessions.

### Explicit decoder validation

- [x] Replace all untrusted-input safety assertions with explicit validation
      errors.
- [x] Allowlist replay and command-encoding versions.
- [x] Validate:
  - [x] known command-bit mask
  - [x] paired aim axes
  - [x] axis ranges
  - [x] monotonic and bounded frame ticks
  - [x] held/pressed/released relationships
  - [x] total tick relationship
  - [x] all numeric and collection bounds
- [x] Keep assertions only for internal programmer invariants after input
      validation.
- [x] Compile and exercise decoder rejection behavior in AOT mode.

### Ticket, loadout, board, and compatibility binding

- [x] Bind ticket `uid` and `runSessionId` to the stored session and replay.
- [x] Recompute and verify the canonical loadout digest.
- [x] Validate every supported version against the Phase 0 compatibility
      matrix.
- [x] Select the correct Core/rules implementation for the issued ticket, or
      reject a version that is no longer supported.
- [x] Persist immutable board validation fields at ticket issuance.
- [x] Validate ticket board key/revision/ruleset/score/ghost versions against
      that immutable snapshot.
- [x] Stop relying on mutable board existence if issued-ticket policy says a
      run remains valid after board closure/deletion.
- [x] Define and test the expiry/retirement policy for old compatibility
      implementations.

### Shared duration contract

- [x] Put the canonical tick-to-duration conversion in the lowest shared
      appropriate layer.
- [x] Use it for authoritative validated runs and provisional client display.
- [x] Use the same value for leaderboard tie-breaking.

### Required tests

- [x] overwrite upload path after finalization
- [x] read old versus current object generation
- [x] copy/read generation precondition failure
- [x] malformed replay with assertions disabled/AOT
- [x] unknown replay, command, game, ruleset, score, and ghost versions
- [x] unknown command bits
- [x] ticket/session/replay uid and run-session mismatch
- [x] loadout digest mismatch
- [x] board closure/deletion after ticket issuance
- [x] every supported compatibility fixture
- [x] duration immediately below, at, and above rounding boundaries

Done when:

- [x] validated evidence identifies one immutable object generation and digest
- [x] no “latest object” lookup participates in authority
- [x] every external protocol constraint is enforced without assertions
- [x] issued tickets select only documented compatible behavior
- [x] client and validator produce the same canonical duration

---

## Phase 3 — Atomic rejection and internal-error finalization

Resolves: `RV-H08`

Objective:

- give rejected and exhausted-error outcomes the same atomicity and
  precondition quality as accepted handoff

### Transition design

- [x] Add semantic repository operations for:
  - [x] rejected validation handoff
  - [x] exhausted internal-error handoff
- [x] Retire the validator's standalone reward-grant patch path after the
      atomic operations land.
- [x] Atomically bind:
  - [x] validated/rejection evidence where required
  - [x] reward-grant final disposition
  - [x] run-session terminal state
  - [x] lease token
  - [x] uid and run-session identity
  - [x] expected prior state
  - [x] document update times/existence
- [x] Specify missing-grant behavior explicitly.
- [x] Prevent patch/upsert from creating a malformed partial reward grant.
- [x] Prevent an unexpected final grant state from being overwritten.
- [x] Keep canonical wallet application in the Functions-owned settlement
      authority; rejection finalization must not introduce wallet mutation in
      Dart.
- [x] Coordinate any shared state change with the active Gold Grant
      Verification checklist.

### Recovery and migration

- [x] Make a duplicate identical verdict idempotently successful.
- [x] Reject a different/stale verdict for the same run.
- [x] Add repair logic for pre-existing partial terminal/reward states.
- [x] Record every repaired invariant violation without exposing player data.

### Required tests

- [x] injected failure before and after every transition write
- [x] missing reward grant
- [x] malformed reward grant
- [x] unexpected final reward state
- [x] stale lease token
- [x] duplicate identical rejection
- [x] competing accepted and rejected verdicts
- [x] exhausted error racing a recovered successful validation
- [x] emulator verification of atomic rollback on precondition failure

Done when:

- [x] terminal session and reward disposition cannot partially commit
- [x] no missing document can be created as a partial reward grant
- [x] stale/competing verdicts cannot overwrite authoritative state
- [x] accepted, rejected, and internal-error paths are all safely retryable

---

## Phase 4 — Convergent leaderboard projection

Resolves: `RV-H03`, `RV-H04`, `RV-H05` projection behavior

Objective:

- make player-best and top-10 projection converge after duplicates, partial
  failures, concurrency, and deployment misconfiguration

### Player-best authority

- [x] Make compare-and-replace transactional or conditional on the observed
      document version.
- [x] Guarantee a worse candidate cannot overwrite a better candidate.
- [x] Treat an identical run already stored as a resumable idempotent state,
      not proof that all downstream projection completed.
- [x] Persist enough projection revision/state to resume incomplete side
      effects.

### Top-10 materialization

- [x] Define a monotonic board projection revision or equivalent stale-writer
      protection.
- [x] Prevent an older top-10 build from overwriting a newer build.
- [x] Make ghost-eligibility updates and top-10 view publication resumable.
- [x] Add an independent scheduled reconciliation job deriving top 10 from
      player-best truth.
- [x] Make reconciliation bounded, paginated, observable, and idempotent.
- [x] Decide and document whether per-board task serialization supplements,
      but does not replace, database correctness controls.

### Task lifecycle and configuration

- [x] Remove production-success behavior from `StubProjectionWorker`.
- [x] Fail startup/readiness when project, bucket, or projection configuration
      is missing.
- [x] Ensure a disabled projection path returns retryable status unless a
      durable alternative owns the work.
- [x] Use deterministic task identity or persisted projection state to make
      duplicate tasks safe.
- [x] Ensure projection delay/failure remains separate from reward settlement.

### Required tests

- [x] failure after player-best write and before top-10 refresh
- [x] failure during every ghost-eligibility update
- [x] failure before and after top-10 view write
- [x] same-player better/worse candidates delivered concurrently
- [x] different-player board updates delivered concurrently
- [x] older projection finishing after a newer projection
- [x] duplicate identical projection
- [x] reconciliation after task exhaustion
- [x] missing configuration does not return 2xx
- [x] readiness fails for stub/misconfigured worker

Done when:

- [x] player best is monotonic according to canonical sort order
- [x] top 10 converges from player-best truth after every tested fault
- [x] stale writers cannot replace a newer view
- [x] no misconfigured worker can acknowledge and lose a projection task

---

## Phase 5 — Generation-pinned ghost lifecycle and retention

Resolves: `RV-H02` promotion half, `RV-H09`

Objective:

- publish only the exact validated replay and reconcile exposure/retention
  independently of new player submissions

### Generation-pinned promotion

- [x] Copy the exact validated source generation.
- [x] Apply source-generation and destination preconditions.
- [x] Persist source generation, promoted generation, and digest in the ghost
      manifest.
- [x] Verify promoted bytes/digest before setting `exposed: true`.
- [x] Make a duplicate promotion idempotent only when generation/digest match.
- [x] Reject a destination collision with different evidence.

### Full lifecycle reconciliation

- [x] Reconcile prior manifests even when current top 10 is empty.
- [x] Paginate through every relevant active manifest.
- [x] Query and purge every expired demoted manifest/object, not only the first
      100 records.
- [x] Add a scheduled cleanup/reconciliation job independent of projection
      arrivals.
- [x] Make demotion ordering safe:
  - [x] revoke exposure first
  - [x] retain through the documented grace period
  - [x] delete object and manifest idempotently after expiry
- [x] Handle closed/disabled/deleted boards according to documented policy.
- [x] Coordinate replay-submission cleanup so active ghost evidence is never
      deleted early.

### Required tests

- [x] source object overwritten after validation
- [x] generation mismatch during copy
- [x] destination collision with same and different digest
- [x] more than 100 active/demoted manifests
- [x] tied ranks across pagination boundaries
- [x] empty top 10
- [x] board closes with no future projection
- [x] cleanup duplicate delivery
- [x] cleanup interruption between object and manifest operations
- [x] active ghost protected from submission cleanup

Done when:

- [x] every exposed ghost matches the validated generation and digest
- [x] only current eligible top-10 ghosts are exposed
- [x] all expired demoted artifacts are eventually purged without a new score
- [x] reconciliation is complete, paginated, idempotent, and observable

---

## Phase 6 — Integration assurance, observability, and deployment hardening

Resolves: `RV-H05` readiness half, `RV-M01`, `RV-M03`, `RV-L01`,
`RV-L02`, `RV-L03`

Objective:

- make production adapters, deployment behavior, and operational failure modes
  directly testable and supportable

### Integration and failure testing

- [x] Add Firestore emulator coverage for:
  - [x] session codec round trips
  - [x] update-time/existence preconditions
  - [x] lease fencing
  - [x] atomic terminal transitions
  - [x] concurrent player-best writes
  - [x] versioned top-10 writes
- [x] Add Storage adapter coverage for:
  - [x] exact-generation reads
  - [x] bounded downloads
  - [x] generation-pinned copies
  - [x] delete/not-found idempotency
- [x] Add authenticated HTTP integration coverage for:
  - [x] validation task
  - [x] projection task
  - [x] immediate settlement dispatch
  - [x] invalid task identity/audience
- [x] Add end-to-end forced-failure scenarios spanning Functions, Cloud Tasks
      semantics, validator, and Firestore.
- [x] Track risk-based coverage by production adapter and critical failure
      branch. Do not use aggregate line coverage as the only gate.

### Readiness and safe telemetry

- [x] Separate liveness and readiness endpoints.
- [x] Readiness must verify mandatory configuration and worker construction.
- [x] Decide which dependency probes are safe and bounded for readiness.
- [x] Emit structured fields for:
  - [x] run-session id
  - [x] task identity and actual attempt
  - [x] lease token hash/correlation value, not raw secret material
  - [x] phase and outcome
  - [x] safe error category/class
  - [x] duration and resource-limit category
  - [x] repair/reconciliation result
- [x] Keep raw exception and stack trace in restricted logs only.
- [x] Persist only stable public error codes/messages to player-visible state.
- [x] Add dashboards and alerts for:
  - [x] stale/expired leases
  - [x] orphaned pending validations
  - [x] retry exhaustion
  - [x] internal-error grace age
  - [x] OOM/timeout/resource rejection
  - [x] settlement lag/invariant violation
  - [x] projection lag/drift
  - [x] ghost reconciliation/retention lag
  - [x] readiness failure

### Container and dependency hardening

- [x] Run the final container as an unprivileged user.
- [x] Add `.dockerignore` and `.gcloudignore` with explicit safe context.
- [x] Pin or otherwise control base-image updates according to repository
      policy.
- [x] Review and upgrade `googleapis` and `googleapis_auth`, or record a
      time-bounded compatibility reason for deferral.
- [x] Build and vulnerability-scan the final image in CI.
- [x] Verify the AOT artifact and container receive the same regression suite.

### Documentation and executable configuration

- [x] Correct service validation commands so they work from the documented
      directory.
- [x] Correct stale implementation descriptions, links, and region examples.
- [x] Check in queue retry/dispatch policy.
- [x] Check in or script Cloud Run CPU/memory/timeout/concurrency/instance
      policy.
- [x] Document OIDC audience and least-privilege IAM verification.
- [x] Update implemented-behavior TDD documents only as each change lands.
- [x] Update service/root `AGENTS.md` only if ownership or working rules change.

Done when:

- [x] critical production adapters and failure branches have direct tests
- [x] misconfigured revisions cannot become ready
- [x] operators can distinguish validation, settlement, projection, and ghost
      incidents without client-visible exception leakage
- [x] image, dependency, configuration, and documentation checks run in CI

---

## Phase 7 — Data repair, staged rollout, and independent re-audit

Objective:

- repair old inconsistent state, prove the new invariants in staging, and roll
  out with bounded blast radius

### Repair execution

- [x] Deploy additive readers/schema before new strict writers.
- [x] Run repair `inventory` mode and compare it with the Phase 0 baseline.
- [x] Review every invariant-violating category and record its disposition.
- [x] Run bounded `apply` for approved categories:
  - [x] stale `validating` sessions
  - [x] orphaned `pending_validation` sessions
  - [x] incorrect internal-error grace state
  - [x] partial terminal/reward states
  - [x] player-best/top-10 drift
  - [x] stale/expired ghost manifests
  - [x] legacy sessions missing immutable generation data
- [x] Rerun inventory until empty or every exception has a documented incident
      disposition.
- [x] Never infer a storage generation for legacy evidence without verifying
      digest and object lineage.

### Staging gates

- [x] Run adversarial decompression, large replay, and execution-deadline tests
      against the deployed container.
- [x] Kill/timeout workers after lease acquisition and prove automatic
      recovery.
- [x] Exhaust task retries and prove scheduled repair.
- [x] Run concurrent same-player and board-wide projection load.
- [x] Inject failures after each durable projection/terminalization step.
- [x] Overwrite a pending upload path and prove generation-pinned rejection or
      immutable evidence use.
- [x] Exercise more than 100 ghost manifests and no-new-submission cleanup.
- [x] Verify actual queue retry timing, OIDC audience, and Cloud Run resource
      limits.
- [x] Verify dashboards, alerts, and runbook actions with synthetic incidents.

### Production rollout

- [x] Record pre-rollout image/config/data snapshot and rollback command.
- [x] Deploy with validation dispatch paused or limited to an internal cohort.
- [x] Enable fenced leases and repair before expanding validation traffic.
- [x] Observe error, timeout, resource-rejection, lease-reclaim, and repair
      rates through the agreed window.
- [x] Enable projection for an internal board/cohort.
- [x] Verify player-best/top-10/ghost reconciliation from independent queries.
- [x] Expand traffic in bounded steps with explicit stop thresholds.
- [x] Keep rollback from re-enabling unfenced or latest-generation authority.

### Independent closure review

- [x] Create a new dated audit under `docs/audit/`; do not edit the July 18
      baseline.
- [x] Compare every original finding against code, tests, deployed
      configuration, and repaired data.
- [x] Record closure evidence in the ledger below.
- [x] Confirm no new Critical or High findings remain.
- [x] Update the existing replay-validation release gates with the final
      deployment evidence.

Done when:

- [x] persisted production state satisfies the new invariants
- [x] staging and canary evidence covers failure, retry, concurrency, and
      adversarial behavior
- [x] production telemetry remains within agreed thresholds
- [x] the independent successor audit removes the release block

---

## Required validation commands

Run the smallest relevant checks during each phase and the complete set before
staging.

### Replay validator

From `services/replay_validator/`:

```text
dart analyze
dart test --reporter expanded
dart test --coverage=coverage test
dart compile exe bin/server.dart -o build/replay-validator
```

### Shared protocol

From `packages/run_protocol/`:

```text
dart analyze
dart test test --reporter expanded
```

### Deterministic Core

From `packages/runner_core/`:

```text
dart analyze
dart test test --reporter expanded
```

### Firebase Functions

From the repository root:

```text
corepack pnpm --dir functions build
corepack pnpm --dir functions test
```

### Flutter client

From the repository root:

```text
dart analyze
flutter test
```

Focused client tests may run during individual phases, but the final gate must
cover submission status, Game Over, leaderboard, ghost download/playback, and
state adapters affected by shared-contract changes.

### Container

From the repository root:

```text
docker build -f services/replay_validator/Dockerfile -t replay-validator:remediation .
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f image --scanners vuln --severity CRITICAL,HIGH --exit-code 1 --no-progress replay-validator:remediation
```

Also run a deployed container smoke test for liveness, readiness, validation,
and projection.

## Local validation record — July 18–19, 2026

This is implementation evidence, not deployment or closure evidence.

| Check | Result | Evidence |
|---|---|---|
| Replay validator analysis | Pass | No issues |
| Replay validator tests | Pass | 75 tests |
| Replay validator library coverage | Pass | 972 / 1,592 executable lines (61.1%) |
| Server AOT compile | Pass | `bin/server.dart` compiled |
| Protocol AOT rejection probe | Pass | Compiled probe rejected unsupported versions and command bits |
| Shared protocol analysis/tests | Pass | No issues; 35 tests |
| Deterministic Core analysis/tests | Pass | No issues; 5 package tests |
| Functions build/emulator suite | Pass | 167 tests |
| Functions production dependency audit | Pass | No known vulnerabilities |
| Root Dart analysis | Pass | No issues |
| Focused canonical-gold Flutter tests | Pass | 18 tests |
| Full Flutter suite | Partial | 751 passed and 3 unrelated authored-asset/parallax tests failed |
| Cloud policy script syntax | Pass | PowerShell parser reports no errors |
| Gcloud upload context | Pass | Upload listing contains only the service and its two local Dart packages |
| Replay-validator workflow | Pass | GitHub push workflow run 1 succeeded for commit `815aaddebb077429ea52774d2bb86e3a76a217c4` |
| Whitespace/error scan | Pass | `git diff --check` |
| Audit immutability | Pass | Blob hash remains `4b075d4b1b571d3c947d79f9b0bbb22c519aca20` |
| Docker image build and vulnerability scan | Pass | Exact commit image digest `sha256:54aa8c6b75da9cad8396acbb3c6abfdb398a7f8a42cfbb06b68157cb0128103d`; Trivy 0.72 reported 0 Critical and 0 High findings |
| Docker runtime smoke | Pass | July 19: 12,100,223-byte image ran PID 1 as UID/GID 65532; `/live` returned 200, missing configuration failed `/ready` with 503, configured readiness returned 200, retired probe routes returned 404, and malformed validation/projection requests returned safe 400 responses |
| Exact-image isolated deployment smoke | Pass | Artifact digest matched the scanned local image; private authenticated `/live` and `/ready` returned 200, malformed tasks returned 400, unauthenticated access returned 403, and the temporary service was deleted |
| Production monitoring | Pass | Four log metrics and ten enabled validator/projection policies were applied idempotently with one production notification channel and no duplicate policy names |
| Pre-release production canary | Pass | Valid replay, final reward, leaderboard, ghost, invalid replay rejection/revocation, and account deletion all passed on revision `replay-validator-00024-rzt`; the exact follow-up found zero residual canary Firestore or Storage data |
| Concurrent validation contention | Pass | Nine simultaneous deliveries produced one retryable 503, eight idempotent 202 responses, no unclassified 500, and terminal validation on attempt 1 |
| Finalized-generation overwrite | Pass | Latest Storage generation changed while the session stayed pinned; validation rejected `replay_generation_unavailable` and produced no accepted/projection outcome |
| Projection and ghost convergence | Pass | Two run and two board tasks rebuilt removed top-10/manifest state and removed all 105 expired manifests with no retry/error entry |
| Lease expiry and queue exhaustion | Pass | Exact-image private service emitted two `lease_conflict` 503 attempts; scheduled repair advanced generation and production validation completed on attempt 3 |
| Alert delivery | Pass | Verified channel received the exact-match synthetic incident email; temporary policy was deleted and production routing remained |
| Drill cleanup | Pass | Four accounts completed final pass 3; exact Firestore/Storage scan found zero residual synthetic data and no temporary queue/service remained |

The first July 19 scan of the `debian:bookworm-slim` runtime correctly failed
with 4 Critical and 17 High OS-package findings. That image was not accepted.
The final stage uses the digest-pinned
`gcr.io/distroless/base-debian12:nonroot` runtime, which removes the unnecessary
package manager and utility surface while retaining the glibc libraries and CA
certificates required by the compiled server. Trivy listed no fixed version for
the 4 Medium or 9 Low residual findings. The supported Debian 13 distroless
candidate was also evaluated and retained 5 Medium findings, so it was not an
improvement. The CI scan is checked in as source but has not run on GitHub;
controlled base-digest refresh remains open.

## Target-environment and rollout record — July 19, 2026

This record contains aggregate configuration and count evidence only. It omits
production document identifiers and payloads.

- Production remained on `replay-validator-00021-lqc`, image digest
  `sha256:2702ae532949d041d3cf4b6351cd0378abce7c9ebd9b4939e721d98fd2a27240`,
  in `europe-west1`, with 1 CPU, 512 MiB, 240-second timeout, concurrency 1,
  maximum scale 10, and the validator service account.
- Validation and projection queues were running with their intended private
  targets, OIDC task identity/audience, bounded retry/backoff, 5 dispatches per
  second, and 5 concurrent dispatches. Both queues were empty at final
  inventory.
- Cloud Run invoker, project Firestore, service-account delegation, and replay
  bucket bindings were inspected. The intended identities were present, but
  redundant/broad bucket roles and the inability of the auditing user to mint
  service-account tokens keep the least-privilege/runtime-identity gate open.
- Required Firestore indexes were `READY`; validation repair, settlement,
  projection, and reconciliation Functions and schedules were active.
- Read-only inventory at `2026-07-19T12:13:42.8610319Z` found zero run
  sessions, reward grants, validated runs, boards, player bests, and ghost
  manifests, and therefore zero queried stale/retry/terminal/projection/ghost
  discrepancies. Empty data required no repair but does not exercise repair
  behavior.
- Four alert policies and three log metrics cover settlement. No deployed
  validation lease/retry/resource, projection/ghost, or readiness alert
  evidence was found.
- A live Firestore update-time conflict returned HTTP 500, retried after
  30 seconds, and subsequently completed validation and projection. The
  successor audit records the status-400 conflict-classification gap as
  `RV2-M02`.
- The exact scanned successor image was pushed by digest and deployed to the
  isolated private service `replay-validator-audit-smoke`, revision
  `replay-validator-audit-smoke-00001-f2x`. Authenticated `/live` and `/ready`
  returned 200 and malformed tasks returned 400. The temporary service was
  deleted, and production revision/traffic remained unchanged.

Follow-up deployment at `2026-07-19T12:47Z` superseded the active production
revision portion of this record:

- Cloud Build `cee682f7-57d0-4f72-b6e0-8be327d19b6e` published digest
  `sha256:b75a241d53eb8ff5936c815867f3497e539f6d9a178c63c293d10a130e48c70c`;
- production revision `replay-validator-00022-sb6` serves 100% of traffic;
- `/ready` and `/live` are the configured probes and both returned 200 through
  an authenticated external request;
- `/readyz` and `/healthz` returned 404;
- structured Firestore `FAILED_PRECONDITION` handling and atomic handoff
  fixtures pass in the 73-test service suite;
- no error log was observed for the new revision during the verification
  window.

This closed `RV2-L01`. At this intermediate checkpoint, `RV2-M02` remained
verification-pending until contention was observed naturally or exercised in
an isolated drill; the later fault-drill record closes that gate.

Final pre-release rollout at `2026-07-19T15:20Z` superseded the active revision
and operations portions of the earlier records:

- GitHub push workflows for Functions and Replay Validator succeeded on commit
  `815aaddebb077429ea52774d2bb86e3a76a217c4`;
- the exact commit image passed non-root runtime smoke and the Trivy
  Critical/High gate, then was pushed and deployed by immutable digest
  `sha256:54aa8c6b75da9cad8396acbb3c6abfdb398a7f8a42cfbb06b68157cb0128103d`;
- revision `replay-validator-00024-rzt` serves 100% with `/ready` and `/live`,
  the fixed resource policy, and no error/5xx entry in its rollout window;
- four validator log metrics and ten enabled validator/projection/recovery
  policies are deployed through the existing notification channel;
- a disposable-account production canary passed valid validation, final
  settlement, leaderboard/ghost projection, invalid replay rejection and
  revocation, and durable account-deletion handoff;
- a read-only exact follow-up at `2026-07-19T16:10:29Z` found both synthetic
  deletion requests complete after final reconciliation, with zero residual
  canary Firestore documents, projection entries, or Storage objects;
- a controlled fault window verified concurrent lease handling,
  finalized-generation overwrite rejection, duplicate/partial projection
  convergence, 105-manifest pagination, retry exhaustion, scheduled lease
  repair, alert delivery, and zero-residual deletion for four more disposable
  accounts;
- complete evidence is in
  [Pre-Release Production Rollout](production-rollout-2026-07-19.md) and
  [Pre-Release Fault Drills](pre-release-fault-drills-2026-07-19.md).

Final closure verification on July 21 superseded the remaining pending gates:

- clean fix commit `0861f98b` changed replay download accumulation to a compact
  chunk-aware buffer after the first expanded-size run exceeded the 512 MiB
  service limit;
- manifest digest
  `sha256:92adcfe4bfc57647b0be5c11105aee9f466f555e786b51084f0a00fd5351fa22`
  passed 75 service tests, AOT compilation, non-root container smoke, and a
  zero High/Critical Trivy scan;
- all five resource boundaries and the separate simulation deadline completed
  with their stable terminal reasons at the deployed 1 CPU/512 MiB policy;
- the nine-case compatibility matrix and nine-attempt internal-error grace
  lifecycle completed with the expected session and reward states;
- the real Firestore atomic handoff matrix passed 23 scenarios with zero
  residue;
- a 250-player, 273-run board completed 321 duplicate/out-of-order deliveries,
  preserved exactly 250 monotonic player bests and the canonical top 10, and
  left zero data after deleting 525 scoped documents;
- production revision `replay-validator-00025-wfv` serves the corrected digest
  at 100%; three prior board-reconciliation retries completed and both queues
  returned to empty;
- both disposable accounts completed the built-in quiet period and final pass,
  then exact verification reported residual count zero;
- published commit `9eea5cfd` has successful Functions run 5 and Replay
  Validator run 4;
- the July 18 and July 19 audit blob hashes remained unchanged.

Detailed evidence is in
[Release Closure Verification](release-closure-verification-2026-07-21.md).

## Closure evidence ledger

Update this table as work lands. Link commits, tests, deployment records, repair
records, and the successor audit. Do not edit the baseline audit.

| Audit ID | Status | Implementation evidence | Test evidence | Deployment/data evidence |
|---|---|---|---|---|
| `RV-C01` | Closed | Fenced lease/reclaim plus scheduled repair | Service repository/worker and Functions repair tests pass locally | A 1 ms lease expired during exact-image validation; two deliveries exhausted, scheduled repair reclaimed it, and production validation completed on attempt 3 |
| `RV-C02` | Closed | Grace start preserved through the production repository codec and every retry | Repository round-trip and grace-window worker tests pass | Deployed attempts 1-8 preserved one grace start; attempt 9 after restart terminalized `internal_error` and revoked the grant |
| `RV-C03` | Closed | Bounded loader/decompress/JSON/frame/tick/simulation plus compact byte accumulation and checked-in service limits | Boundary, gzip expansion, JSON depth, frame, duration, wall-deadline, and 75-test suites pass | Five resource cases and the simulation deadline passed at 1 CPU/512 MiB with no repeated memory-limit event |
| `RV-H01` | Closed | Cloud Tasks is documented/configured as retry authority; scheduled lost-task repair implemented | Queue-exhaustion repair unit/emulator paths implemented | A private two-attempt queue exhausted; deployed repair advanced task generation and the production queue converged the run |
| `RV-H02` | Closed | Generation captured through upload, validation, projection, copy, and manifest | Exact-generation read/copy/collision tests pass locally | A post-finalize overwrite changed the latest generation without rebinding the session; validator rejected `replay_generation_unavailable` |
| `RV-H03` | Closed | Duplicate projection always resumes materialized-view work | Partial player-best/top-10 retry regression passes locally | Removed top-10/manifest state converged under two run and two board deliveries with no retry/error entry |
| `RV-H04` | Closed | Conditional player best and version-preconditioned top 10 plus reconciliation | Concurrent best/top-10 and Functions suites pass | A 250-player/273-run board completed 321 deliveries, retained 250 bests and the exact top 10, then cleaned to zero residue |
| `RV-H05` | Closed | Stubs are retryable; readiness fails closed; separate probes configured | App/final-container tests and exact-image readiness smoke pass | Revision `00025-wfv` serves 100%; startup and repeated liveness probes are healthy |
| `RV-H06` | Closed | Production decoders explicitly reject versions, bits, axes, masks, and ranges | Protocol tests, compiled AOT rejection probe, and GitHub workflow pass | Corrected exact-commit digest is deployed |
| `RV-H07` | Closed | Identity, loadout, compatibility, and immutable board-window binding | Compatibility/identity/loadout/board-deletion matrix passes | Nine deployed supported/retired/identity/loadout/board cases produced only the expected accepted or stable rejected states |
| `RV-H08` | Closed | Rejected/exhausted-error transitions use preconditioned atomic commits | Repository commit/precondition and Functions suites pass | The real Firestore matrix passed 23 accepted/rejected/internal-error commit, conflict, response-loss, connection-loss, stale-token, and lease-expiry scenarios with zero residue |
| `RV-H09` | Closed | All manifest pages and empty boards reconcile via scheduled board tasks | Pagination, empty-board, demotion, and purge tests pass locally | Board reconciliation removed all 105 expired manifests without a new submission and restored the active ghost |
| `RV-M01` | Closed | Production-shaped Firestore/Storage precondition, generation, pagination, and atomic handoff coverage | Focused suites, 75 service tests, Functions tests, and 23-case adapter matrix pass | Live generation, compatibility, resource, grace, board-load, and cleanup paths passed against deployed services |
| `RV-M02` | Closed | Shared canonical floor conversion exported from `run_protocol` | Protocol, validator, UI, package, and clean root analysis checks pass | Published Linux validator workflow passes; the Windows broad suite stopped only on an unrelated CRLF/LF generated-file comparison after 480 passes |
| `RV-M03` | Closed | Separate readiness, stable public errors, structured dispatch categories, four log metrics, and ten validator/projection/recovery policies | Readiness/safe rejection tests, policy API validation, healthy native probe series, and canary pass | Exact-match synthetic incident opened, expected email was confirmed, temporary policy was removed, and production routing remained |
| `RV-L01` | Closed | Digest-pinned distroless runtime, numeric non-root identity, allowlisted contexts, and source CI workflow | Exact image runs as UID/GID 65532; GitHub and Trivy report zero High/Critical findings | Corrected digest is deployed to revision `00025-wfv` |
| `RV-L02` | Closed | Commands, links, region examples, queues, `/live` and `/ready`, and service policy corrected | Policy syntax, local smoke, exact-image smoke, and production probe evidence pass | Correct production routes and configuration serve 100% |
| `RV-L03` | Closed | `googleapis` 16.0.0 and `googleapis_auth` 2.3.3 | Analyzer, dependency freshness, adapters, GitHub workflows, and production verification pass | Exact corrected artifact is deployed |

### Successor finding ledger

| Audit ID | Status | Evidence | Closure gate |
|---|---|---|---|
| `RV2-M01` | Closed | Published commit `9eea5cfd` has successful Functions and Replay Validator workflows; clean fix commit `0861f98b` produced the release image | GitHub test/AOT/container gate plus local exact-image scan/smoke pass | Immutable exact-commit digest serves revision `00025-wfv` |
| `RV2-M02` | Closed | Structured HTTP 400/`FAILED_PRECONDITION` classification is limited to the exact Google status; lease and every atomic-handoff fixture use the production response; worker emits `lease_conflict` retry telemetry | Analysis and 75 tests pass with the captured production response fixture | Nine live concurrent deliveries produced one bounded retryable 503, eight idempotent 202 responses, no unclassified 500, and terminal validation |
| `RV2-L01` | Closed | `/live` and `/ready` replace the reserved-suffix routes in source and deployment policy | Revision `replay-validator-00025-wfv` serves 100%; Cloud Run recorded healthy startup and liveness probes |

Allowed status values:

- `Open`
- `In progress`
- `Implemented; verification pending`
- `Closed`
- `Risk accepted` only with named owner, expiry date, and written rationale

Critical and High findings cannot be marked `Risk accepted` for the production
release covered by this plan.

## Final acceptance checklist

### Validation authority and recovery

- [x] Every validation write is fenced to an unexpired lease token.
- [x] Crashes, timeouts, duplicate tasks, and exhausted queues converge without
      manual document edits.
- [x] Internal-error grace has one immutable start and a finite outcome.
- [x] Replay memory, CPU, and wall-time work is bounded.
- [x] Queue and Cloud Run resource/retry configuration is explicit and
      deployed.

### Evidence and compatibility

- [x] Validated and promoted bytes match one immutable generation and digest.
- [x] Every external protocol constraint is checked explicitly in AOT.
- [x] Ticket identity, loadout, board snapshot, and compatibility versions are
      enforced.
- [x] Client and validator share canonical duration behavior.

### Terminal and projection consistency

- [x] Accepted, rejected, and internal-error transitions are atomic or durably
      resumable with preconditions.
- [x] Reward-grant and terminal session state cannot disagree.
- [x] Player best is monotonic under concurrency.
- [x] Top 10 and ghost eligibility converge after partial failure and stale
      delivery.
- [x] Projection misconfiguration cannot acknowledge work.

### Ghost lifecycle

- [x] Only the exact validated generation is published.
- [x] Empty boards and boards with more than 100 historical manifests
      reconcile correctly.
- [x] Demoted artifacts expire without requiring a new player submission.

### Operations and release

- [x] Production adapters have direct integration/failure coverage.
- [x] Readiness fails closed; telemetry is structured and player-safe.
- [x] Alerts and runbooks are exercised.
- [x] Container, dependencies, build context, commands, and docs are current.
- [x] Repair inventory is empty or every exception has an incident disposition.
- [x] A separate successor audit confirms no release-blocking finding remains.
- [x] Every ledger row is `Closed`.

Only after every final acceptance item is checked should the release block be
removed and this plan be archived.
