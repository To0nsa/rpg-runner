# Replay Validator Audit Remediation Plan

Date: July 18, 2026  
Status: Implementation in progress; production release remains blocked  
Evidence baseline:
[Replay Validator Full Audit — July 18, 2026](../../audit/replay-validator-full-audit-2026-07-18.md)  
Baseline Git blob hash: `4b075d4b1b571d3c947d79f9b0bbb22c519aca20`
Successor evidence:
[Replay Validator Successor Audit — July 19, 2026](../../audit/replay-validator-successor-audit-2026-07-19.md)
Successor audit Git blob hash:
`f966a89f8b60c3b7c60dcfa1482d8e5ddbf6534b`

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

The release remains blocked. Passing unit tests and static analysis do not
override the audit findings.

Production rollout may resume only after:

- every Critical and High finding is closed with regression evidence;
- affected persisted data has been inventoried and repaired;
- queue, Cloud Run, IAM, and alert configuration is verified in the target
  environment;
- adversarial, retry, concurrency, and partial-failure staging gates pass;
- a separate dated re-audit finds no remaining release blocker.

The July 19 successor audit is complete and does not remove the block. It found
no new Critical or High issue, but it kept every original Critical/High row at
`Implemented; verification pending` and added two Medium and one Low finding.
The remaining gates are recorded in the closure ledger and July 19 environment
record below.

On July 19 the repository owner confirmed that no staging project exists and
the game has no released users. Production is therefore the approved controlled
pre-release environment for smoke and disposable-account canary verification.
This decision does not authorize destructive crash, exhaustion, or large-load
fault injection; those gates remain deferred until an isolated environment or
explicit test window exists.

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

- [ ] Define the validation lease contract:
  - [ ] unique lease/attempt token
  - [ ] lease acquisition and expiry timestamps
  - [ ] expected-state and update-time preconditions
  - [ ] stale lease reclaim rules
  - [ ] stale worker write rejection
  - [ ] duplicate active-delivery behavior
- [ ] Select and document one retry authority.
  - [ ] Prefer Cloud Tasks queue policy for ordinary delivery retries.
  - [ ] Treat persisted retry timestamps as observability or repair input, not
        an unimplemented scheduler.
  - [ ] Define how scheduled repair restores work after queue exhaustion,
        deletion, or retention expiry.
  - [ ] Define how the internal-error grace window survives task-budget
        exhaustion.
- [ ] Define hard replay limits:
  - [ ] compressed bytes
  - [ ] expanded bytes
  - [ ] JSON/object nesting where applicable
  - [ ] frame count
  - [ ] command count/density
  - [ ] total ticks and duration
  - [ ] maximum simulation wall time
- [ ] Derive limits from currently valid content and expected gameplay duration;
      do not select values that reject issued tickets.
- [ ] Define the immutable replay identity:
  - [ ] bucket
  - [ ] object path
  - [ ] object generation
  - [ ] content digest
  - [ ] finalized timestamp
- [ ] Define the supported compatibility matrix for:
  - [ ] replay version
  - [ ] command encoding version
  - [ ] game compatibility version
  - [ ] ruleset version
  - [ ] score version
  - [ ] ghost version
- [ ] Define immutable board validation data captured at ticket issuance.
- [ ] Define the projection truth model:
  - [ ] player best is canonical per-player board state
  - [ ] top 10 is a recoverable materialized view
  - [ ] stale projection writers cannot replace newer revisions
  - [ ] reconciliation does not depend on a new score arriving
- [ ] Define one canonical tick-to-duration conversion rule.
- [ ] Update the relevant TDD documents with these decisions in the same change
      that implements them. Proposed decisions remain in this building plan
      until implemented.

### Environment and data inventory

- [ ] Record the deployed Cloud Run:
  - [ ] image digest and revision
  - [ ] service account
  - [ ] region
  - [ ] CPU and memory
  - [ ] request timeout
  - [ ] container concurrency
  - [ ] minimum and maximum instances
  - [ ] startup and readiness behavior
- [ ] Record both validation and projection queue:
  - [ ] region
  - [ ] target URL
  - [ ] OIDC service account and audience
  - [ ] maximum attempts and retry duration
  - [ ] minimum/maximum backoff and doublings
  - [ ] dispatch rate and maximum concurrent dispatches
  - [ ] task retention
- [ ] Verify least-privilege IAM for Functions, task dispatch, validator,
      Firestore, and Storage paths.
- [ ] Inventory persisted state without mutating it:
  - [ ] `validating` sessions grouped by lease age
  - [ ] `pending_validation` sessions grouped by next-attempt age
  - [ ] internal-error retries grouped by first-error age
  - [ ] terminal runs whose reward-grant state disagrees
  - [ ] missing or malformed reward grants
  - [ ] player-best/top-10 disagreement by board
  - [ ] active ghost manifests outside top 10
  - [ ] expired demoted manifests/objects
  - [ ] replay objects whose finalized generation is missing from session data
- [ ] Store counts and query timestamps in a dated rollout record; do not put
      production identifiers or sensitive payloads in repository docs.

### Rollback and migration preparation

- [ ] Define deployment order for additive schema reads before new writes.
- [ ] Define a bounded, cursor-based, idempotent repair command/job with
      `off`, `inventory`, and explicit `apply` modes.
- [ ] Define rollback behavior that preserves new fields and never restores
      unfenced writes.
- [ ] Define feature controls for:
  - [ ] validation dispatch
  - [ ] stale-lease reclaim
  - [ ] automatic internal-error revocation
  - [ ] leaderboard projection
  - [ ] ghost publication
- [ ] Confirm disabling a side effect cannot acknowledge and lose its durable
      task.

Done when:

- [ ] every contract decision is recorded and reviewed
- [ ] live configuration and data inventory is captured
- [ ] migration and rollback paths are idempotent and bounded
- [ ] no implementation phase relies on an unresolved authority decision

---

## Phase 1 — Fenced validation lifecycle, retry recovery, and resource bounds

Resolves: `RV-C01`, `RV-C02`, `RV-C03`, `RV-H01`

Objective:

- ensure validation work is finite, retry-safe, fenced, and automatically
  recoverable after worker or task failure

### Shared/session contract

- [ ] Add additive lease metadata to the run-session contract.
- [ ] Preserve backward reads for sessions created before the migration.
- [ ] Ensure new writers emit the complete lease contract before strict reads
      are enabled.
- [ ] Preserve the first internal-error timestamp across every repository
      decode, lease, retry, and terminal transition.
- [ ] Distinguish public status/error codes from operator-only diagnostic
      details.

### Lease repository

- [ ] Acquire a lease transactionally with:
  - [ ] unique token
  - [ ] expected source state
  - [ ] incremented attempt
  - [ ] start and expiry timestamps
  - [ ] document precondition
- [ ] Require the lease token on:
  - [ ] retry scheduling
  - [ ] accepted handoff
  - [ ] rejection handoff
  - [ ] internal-error terminalization
  - [ ] any validation-owned message/status write
- [ ] Reject every stale lease writer without mutating current state.
- [ ] Reclaim expired `validating` sessions transactionally.
- [ ] Make active duplicate delivery explicitly retryable or prove another
      durable recovery task exists before acknowledging it.
- [ ] Handle an acquisition conflict separately from an already active lease;
      do not collapse invalid state and transient contention into success.

### Retry and repair

- [ ] Check in declarative Cloud Tasks queue policy or an equivalent
      reviewable configuration source.
- [ ] Align worker retry accounting with actual Cloud Tasks attempt headers.
- [ ] Remove or rename application retry schedules that are not enforced.
- [ ] Add a scheduled Functions repair job that:
  - [ ] scans a bounded page
  - [ ] requeues expired leases
  - [ ] requeues orphaned pending validations
  - [ ] respects the original internal-error grace start
  - [ ] uses deterministic task names/idempotency
  - [ ] emits repaired/skipped/conflict metrics
- [ ] Ensure queue exhaustion cannot permanently strand a run.
- [ ] Ensure incident-mode pause has a durable revisit mechanism.

### Bounded input and execution

- [ ] Reject an object larger than the finalized compressed-byte contract
      before full materialization where possible.
- [ ] Replace unbounded gzip decoding with bounded streaming decompression.
- [ ] Stop decoding immediately when the expanded-byte limit is exceeded.
- [ ] Enforce frame, command, tick, and run-duration limits before simulation.
- [ ] Enforce a monotonic wall-time deadline during simulation.
- [ ] Classify limit violations as stable player-input rejection, not transient
      infrastructure errors.
- [ ] Prevent error messages from echoing large/malicious input.

### Deployment controls

- [ ] Set explicit Cloud Run CPU, memory, timeout, concurrency, and maximum
      instances based on adversarial and representative load tests.
- [ ] Set explicit queue dispatch rate and concurrent dispatch limits.
- [ ] Ensure Cloud Run timeout exceeds the application deadline plus bounded
      terminal-write allowance.
- [ ] Alert on container OOM, request timeout, lease expiry, and repair backlog.

### Required tests

- [ ] crash immediately after lease acquisition
- [ ] request timeout after lease acquisition
- [ ] active duplicate task delivery
- [ ] expired lease reclaim
- [ ] stale worker attempting every write type
- [ ] queue exhaustion followed by repair
- [ ] internal-error grace across production repository round trips
- [ ] incident mode across process restarts
- [ ] gzip expansion past the limit
- [ ] replay at and one unit beyond every size/count/tick limit
- [ ] simulation deadline cancellation
- [ ] concurrent reclaim attempts

Done when:

- [ ] no worker crash or queue exhaustion can strand a run indefinitely
- [ ] stale writers cannot terminalize a newer attempt
- [ ] the first internal-error timestamp remains immutable
- [ ] adversarial replay work remains within measured CPU, memory, and time
      budgets
- [ ] deployed service and queue limits match checked-in policy

---

## Phase 2 — Immutable replay evidence and explicit compatibility

Resolves: `RV-H02` validation half, `RV-H06`, `RV-H07`, `RV-M02`

Objective:

- prove that validation uses an immutable finalized object and explicitly
  interprets only supported protocol/game rules

### Immutable upload lineage

- [ ] Carry storage generation through:
  - [ ] upload finalization record
  - [ ] run session
  - [ ] validator replay reference
  - [ ] validated-run evidence
  - [ ] leaderboard candidate
  - [ ] ghost promotion input and manifest
- [ ] Require finalized generation and digest for every newly finalized upload.
- [ ] Read the exact generation from Cloud Storage with a generation
      precondition.
- [ ] Reject a missing/replaced generation as a stable evidence failure.
- [ ] Prevent upload URL reuse from changing finalized evidence:
  - [ ] use generation preconditions on upload/finalization; or
  - [ ] promote finalized bytes immediately to an immutable evidence object.
- [ ] Preserve old-session handling explicitly; do not silently treat “latest”
      as the generation for legacy sessions.

### Explicit decoder validation

- [ ] Replace all untrusted-input safety assertions with explicit validation
      errors.
- [ ] Allowlist replay and command-encoding versions.
- [ ] Validate:
  - [ ] known command-bit mask
  - [ ] paired aim axes
  - [ ] axis ranges
  - [ ] monotonic and bounded frame ticks
  - [ ] held/pressed/released relationships
  - [ ] total tick relationship
  - [ ] all numeric and collection bounds
- [ ] Keep assertions only for internal programmer invariants after input
      validation.
- [ ] Compile and exercise decoder rejection behavior in AOT mode.

### Ticket, loadout, board, and compatibility binding

- [ ] Bind ticket `uid` and `runSessionId` to the stored session and replay.
- [ ] Recompute and verify the canonical loadout digest.
- [ ] Validate every supported version against the Phase 0 compatibility
      matrix.
- [ ] Select the correct Core/rules implementation for the issued ticket, or
      reject a version that is no longer supported.
- [ ] Persist immutable board validation fields at ticket issuance.
- [ ] Validate ticket board key/revision/ruleset/score/ghost versions against
      that immutable snapshot.
- [ ] Stop relying on mutable board existence if issued-ticket policy says a
      run remains valid after board closure/deletion.
- [ ] Define and test the expiry/retirement policy for old compatibility
      implementations.

### Shared duration contract

- [ ] Put the canonical tick-to-duration conversion in the lowest shared
      appropriate layer.
- [ ] Use it for authoritative validated runs and provisional client display.
- [ ] Use the same value for leaderboard tie-breaking.

### Required tests

- [ ] overwrite upload path after finalization
- [ ] read old versus current object generation
- [ ] copy/read generation precondition failure
- [ ] malformed replay with assertions disabled/AOT
- [ ] unknown replay, command, game, ruleset, score, and ghost versions
- [ ] unknown command bits
- [ ] ticket/session/replay uid and run-session mismatch
- [ ] loadout digest mismatch
- [ ] board closure/deletion after ticket issuance
- [ ] every supported compatibility fixture
- [ ] duration immediately below, at, and above rounding boundaries

Done when:

- [ ] validated evidence identifies one immutable object generation and digest
- [ ] no “latest object” lookup participates in authority
- [ ] every external protocol constraint is enforced without assertions
- [ ] issued tickets select only documented compatible behavior
- [ ] client and validator produce the same canonical duration

---

## Phase 3 — Atomic rejection and internal-error finalization

Resolves: `RV-H08`

Objective:

- give rejected and exhausted-error outcomes the same atomicity and
  precondition quality as accepted handoff

### Transition design

- [ ] Add semantic repository operations for:
  - [ ] rejected validation handoff
  - [ ] exhausted internal-error handoff
- [ ] Retire the validator's standalone reward-grant patch path after the
      atomic operations land.
- [ ] Atomically bind:
  - [ ] validated/rejection evidence where required
  - [ ] reward-grant final disposition
  - [ ] run-session terminal state
  - [ ] lease token
  - [ ] uid and run-session identity
  - [ ] expected prior state
  - [ ] document update times/existence
- [ ] Specify missing-grant behavior explicitly.
- [ ] Prevent patch/upsert from creating a malformed partial reward grant.
- [ ] Prevent an unexpected final grant state from being overwritten.
- [ ] Keep canonical wallet application in the Functions-owned settlement
      authority; rejection finalization must not introduce wallet mutation in
      Dart.
- [ ] Coordinate any shared state change with the active Gold Grant
      Verification checklist.

### Recovery and migration

- [ ] Make a duplicate identical verdict idempotently successful.
- [ ] Reject a different/stale verdict for the same run.
- [ ] Add repair logic for pre-existing partial terminal/reward states.
- [ ] Record every repaired invariant violation without exposing player data.

### Required tests

- [ ] injected failure before and after every transition write
- [ ] missing reward grant
- [ ] malformed reward grant
- [ ] unexpected final reward state
- [ ] stale lease token
- [ ] duplicate identical rejection
- [ ] competing accepted and rejected verdicts
- [ ] exhausted error racing a recovered successful validation
- [ ] emulator verification of atomic rollback on precondition failure

Done when:

- [ ] terminal session and reward disposition cannot partially commit
- [ ] no missing document can be created as a partial reward grant
- [ ] stale/competing verdicts cannot overwrite authoritative state
- [ ] accepted, rejected, and internal-error paths are all safely retryable

---

## Phase 4 — Convergent leaderboard projection

Resolves: `RV-H03`, `RV-H04`, `RV-H05` projection behavior

Objective:

- make player-best and top-10 projection converge after duplicates, partial
  failures, concurrency, and deployment misconfiguration

### Player-best authority

- [ ] Make compare-and-replace transactional or conditional on the observed
      document version.
- [ ] Guarantee a worse candidate cannot overwrite a better candidate.
- [ ] Treat an identical run already stored as a resumable idempotent state,
      not proof that all downstream projection completed.
- [ ] Persist enough projection revision/state to resume incomplete side
      effects.

### Top-10 materialization

- [ ] Define a monotonic board projection revision or equivalent stale-writer
      protection.
- [ ] Prevent an older top-10 build from overwriting a newer build.
- [ ] Make ghost-eligibility updates and top-10 view publication resumable.
- [ ] Add an independent scheduled reconciliation job deriving top 10 from
      player-best truth.
- [ ] Make reconciliation bounded, paginated, observable, and idempotent.
- [ ] Decide and document whether per-board task serialization supplements,
      but does not replace, database correctness controls.

### Task lifecycle and configuration

- [ ] Remove production-success behavior from `StubProjectionWorker`.
- [ ] Fail startup/readiness when project, bucket, or projection configuration
      is missing.
- [ ] Ensure a disabled projection path returns retryable status unless a
      durable alternative owns the work.
- [ ] Use deterministic task identity or persisted projection state to make
      duplicate tasks safe.
- [ ] Ensure projection delay/failure remains separate from reward settlement.

### Required tests

- [ ] failure after player-best write and before top-10 refresh
- [ ] failure during every ghost-eligibility update
- [ ] failure before and after top-10 view write
- [ ] same-player better/worse candidates delivered concurrently
- [ ] different-player board updates delivered concurrently
- [ ] older projection finishing after a newer projection
- [ ] duplicate identical projection
- [ ] reconciliation after task exhaustion
- [ ] missing configuration does not return 2xx
- [ ] readiness fails for stub/misconfigured worker

Done when:

- [ ] player best is monotonic according to canonical sort order
- [ ] top 10 converges from player-best truth after every tested fault
- [ ] stale writers cannot replace a newer view
- [ ] no misconfigured worker can acknowledge and lose a projection task

---

## Phase 5 — Generation-pinned ghost lifecycle and retention

Resolves: `RV-H02` promotion half, `RV-H09`

Objective:

- publish only the exact validated replay and reconcile exposure/retention
  independently of new player submissions

### Generation-pinned promotion

- [ ] Copy the exact validated source generation.
- [ ] Apply source-generation and destination preconditions.
- [ ] Persist source generation, promoted generation, and digest in the ghost
      manifest.
- [ ] Verify promoted bytes/digest before setting `exposed: true`.
- [ ] Make a duplicate promotion idempotent only when generation/digest match.
- [ ] Reject a destination collision with different evidence.

### Full lifecycle reconciliation

- [ ] Reconcile prior manifests even when current top 10 is empty.
- [ ] Paginate through every relevant active manifest.
- [ ] Query and purge every expired demoted manifest/object, not only the first
      100 records.
- [ ] Add a scheduled cleanup/reconciliation job independent of projection
      arrivals.
- [ ] Make demotion ordering safe:
  - [ ] revoke exposure first
  - [ ] retain through the documented grace period
  - [ ] delete object and manifest idempotently after expiry
- [ ] Handle closed/disabled/deleted boards according to documented policy.
- [ ] Coordinate replay-submission cleanup so active ghost evidence is never
      deleted early.

### Required tests

- [ ] source object overwritten after validation
- [ ] generation mismatch during copy
- [ ] destination collision with same and different digest
- [ ] more than 100 active/demoted manifests
- [ ] tied ranks across pagination boundaries
- [ ] empty top 10
- [ ] board closes with no future projection
- [ ] cleanup duplicate delivery
- [ ] cleanup interruption between object and manifest operations
- [ ] active ghost protected from submission cleanup

Done when:

- [ ] every exposed ghost matches the validated generation and digest
- [ ] only current eligible top-10 ghosts are exposed
- [ ] all expired demoted artifacts are eventually purged without a new score
- [ ] reconciliation is complete, paginated, idempotent, and observable

---

## Phase 6 — Integration assurance, observability, and deployment hardening

Resolves: `RV-H05` readiness half, `RV-M01`, `RV-M03`, `RV-L01`,
`RV-L02`, `RV-L03`

Objective:

- make production adapters, deployment behavior, and operational failure modes
  directly testable and supportable

### Integration and failure testing

- [ ] Add Firestore emulator coverage for:
  - [ ] session codec round trips
  - [ ] update-time/existence preconditions
  - [ ] lease fencing
  - [ ] atomic terminal transitions
  - [ ] concurrent player-best writes
  - [ ] versioned top-10 writes
- [ ] Add Storage adapter coverage for:
  - [ ] exact-generation reads
  - [ ] bounded downloads
  - [ ] generation-pinned copies
  - [ ] delete/not-found idempotency
- [ ] Add authenticated HTTP integration coverage for:
  - [ ] validation task
  - [ ] projection task
  - [ ] immediate settlement dispatch
  - [ ] invalid task identity/audience
- [ ] Add end-to-end forced-failure scenarios spanning Functions, Cloud Tasks
      semantics, validator, and Firestore.
- [ ] Track risk-based coverage by production adapter and critical failure
      branch. Do not use aggregate line coverage as the only gate.

### Readiness and safe telemetry

- [ ] Separate liveness and readiness endpoints.
- [ ] Readiness must verify mandatory configuration and worker construction.
- [ ] Decide which dependency probes are safe and bounded for readiness.
- [ ] Emit structured fields for:
  - [ ] run-session id
  - [ ] task identity and actual attempt
  - [ ] lease token hash/correlation value, not raw secret material
  - [ ] phase and outcome
  - [ ] safe error category/class
  - [ ] duration and resource-limit category
  - [ ] repair/reconciliation result
- [ ] Keep raw exception and stack trace in restricted logs only.
- [ ] Persist only stable public error codes/messages to player-visible state.
- [ ] Add dashboards and alerts for:
  - [ ] stale/expired leases
  - [ ] orphaned pending validations
  - [ ] retry exhaustion
  - [ ] internal-error grace age
  - [ ] OOM/timeout/resource rejection
  - [ ] settlement lag/invariant violation
  - [ ] projection lag/drift
  - [ ] ghost reconciliation/retention lag
  - [ ] readiness failure

### Container and dependency hardening

- [x] Run the final container as an unprivileged user.
- [x] Add `.dockerignore` and `.gcloudignore` with explicit safe context.
- [x] Pin or otherwise control base-image updates according to repository
      policy.
- [x] Review and upgrade `googleapis` and `googleapis_auth`, or record a
      time-bounded compatibility reason for deferral.
- [ ] Build and vulnerability-scan the final image in CI.
- [ ] Verify the AOT artifact and container receive the same regression suite.

### Documentation and executable configuration

- [ ] Correct service validation commands so they work from the documented
      directory.
- [ ] Correct stale implementation descriptions, links, and region examples.
- [ ] Check in queue retry/dispatch policy.
- [ ] Check in or script Cloud Run CPU/memory/timeout/concurrency/instance
      policy.
- [ ] Document OIDC audience and least-privilege IAM verification.
- [ ] Update implemented-behavior TDD documents only as each change lands.
- [ ] Update service/root `AGENTS.md` only if ownership or working rules change.

Done when:

- [ ] critical production adapters and failure branches have direct tests
- [ ] misconfigured revisions cannot become ready
- [ ] operators can distinguish validation, settlement, projection, and ghost
      incidents without client-visible exception leakage
- [ ] image, dependency, configuration, and documentation checks run in CI

---

## Phase 7 — Data repair, staged rollout, and independent re-audit

Objective:

- repair old inconsistent state, prove the new invariants in staging, and roll
  out with bounded blast radius

### Repair execution

- [ ] Deploy additive readers/schema before new strict writers.
- [ ] Run repair `inventory` mode and compare it with the Phase 0 baseline.
- [ ] Review every invariant-violating category and record its disposition.
- [ ] Run bounded `apply` for approved categories:
  - [ ] stale `validating` sessions
  - [ ] orphaned `pending_validation` sessions
  - [ ] incorrect internal-error grace state
  - [ ] partial terminal/reward states
  - [ ] player-best/top-10 drift
  - [ ] stale/expired ghost manifests
  - [ ] legacy sessions missing immutable generation data
- [ ] Rerun inventory until empty or every exception has a documented incident
      disposition.
- [ ] Never infer a storage generation for legacy evidence without verifying
      digest and object lineage.

### Staging gates

- [ ] Run adversarial decompression, large replay, and execution-deadline tests
      against the deployed container.
- [ ] Kill/timeout workers after lease acquisition and prove automatic
      recovery.
- [ ] Exhaust task retries and prove scheduled repair.
- [ ] Run concurrent same-player and board-wide projection load.
- [ ] Inject failures after each durable projection/terminalization step.
- [ ] Overwrite a pending upload path and prove generation-pinned rejection or
      immutable evidence use.
- [ ] Exercise more than 100 ghost manifests and no-new-submission cleanup.
- [ ] Verify actual queue retry timing, OIDC audience, and Cloud Run resource
      limits.
- [ ] Verify dashboards, alerts, and runbook actions with synthetic incidents.

### Production rollout

- [ ] Record pre-rollout image/config/data snapshot and rollback command.
- [ ] Deploy with validation dispatch paused or limited to an internal cohort.
- [ ] Enable fenced leases and repair before expanding validation traffic.
- [ ] Observe error, timeout, resource-rejection, lease-reclaim, and repair
      rates through the agreed window.
- [ ] Enable projection for an internal board/cohort.
- [ ] Verify player-best/top-10/ghost reconciliation from independent queries.
- [ ] Expand traffic in bounded steps with explicit stop thresholds.
- [ ] Keep rollback from re-enabling unfenced or latest-generation authority.

### Independent closure review

- [x] Create a new dated audit under `docs/audit/`; do not edit the July 18
      baseline.
- [x] Compare every original finding against code, tests, deployed
      configuration, and repaired data.
- [x] Record closure evidence in the ledger below.
- [x] Confirm no new Critical or High findings remain.
- [ ] Update the existing replay-validation release gates with the final
      deployment evidence.

Done when:

- [ ] persisted production state satisfies the new invariants
- [ ] staging and canary evidence covers failure, retry, concurrency, and
      adversarial behavior
- [ ] production telemetry remains within agreed thresholds
- [ ] the independent successor audit removes the release block

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
| Pre-release production canary | Pass | Valid replay, final reward, leaderboard, ghost, invalid replay rejection/revocation, and account-deletion request all passed on revision `replay-validator-00024-rzt` |

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

This closes `RV2-L01`. `RV2-M02` remains verification-pending until contention
is observed naturally or exercised in an isolated drill; the other ledger
gates are unchanged.

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
- complete evidence is in
  [Pre-Release Production Rollout](production-rollout-2026-07-19.md).

## Closure evidence ledger

Update this table as work lands. Link commits, tests, deployment records, repair
records, and the successor audit. Do not edit the baseline audit.

| Audit ID | Status | Implementation evidence | Test evidence | Deployment/data evidence |
|---|---|---|---|---|
| `RV-C01` | Implemented; verification pending | Fenced lease/reclaim plus scheduled repair | Service repository/worker and Functions repair tests pass locally | Repair/schedule deployed and a live transient conflict recovered; kill/timeout and backlog drills pending |
| `RV-C02` | Implemented; verification pending | Grace start preserved through production repository codec | Repository round-trip and grace-window worker tests pass locally | Aggregate inventory contained no legacy session; deployed grace-window drill pending |
| `RV-C03` | Implemented; verification pending | Bounded loader/decompress/JSON/frame/tick/simulation plus checked-in service limits | Boundary, gzip expansion, JSON depth, and wall-deadline tests pass locally | Exact-image resource config verified in isolation; adversarial deployed load/alert evidence pending |
| `RV-H01` | Implemented; verification pending | Cloud Tasks is documented/configured as retry authority; scheduled lost-task repair implemented | Queue-exhaustion repair unit/emulator paths implemented | Target queues match policy and a live retry recovered; deliberate exhaustion/repair drill pending |
| `RV-H02` | Implemented; verification pending | Generation captured through upload, validation, projection, copy, and manifest | Exact-generation read/copy/collision tests pass locally | Storage integration and deployed overwrite drill pending |
| `RV-H03` | Implemented; verification pending | Duplicate projection always resumes materialized-view work | Partial player-best/top-10 retry regression passes locally | Staging fault injection pending |
| `RV-H04` | Implemented; verification pending | Conditional player best and version-preconditioned top 10 plus reconciliation | Concurrent best/top-10 tests and 167-test Functions emulator suite pass | Deployed board-wide load verification pending |
| `RV-H05` | Closed | Stubs are retryable; readiness fails closed; separate probes configured | App/final-container tests and exact-image readiness smoke pass | Exact commit revision `00024-rzt` serves 100%; startup and repeated liveness probes are healthy |
| `RV-H06` | Closed | Production decoders explicitly reject versions, bits, axes, masks, and ranges | Protocol tests, compiled AOT rejection probe, and GitHub workflow pass | Exact successful commit digest is deployed |
| `RV-H07` | Implemented; verification pending | Identity, loadout, compatibility, and immutable board-window binding | Compatibility/identity/loadout/board-deletion matrix passes locally | Compatibility retirement/production fixture review pending |
| `RV-H08` | Implemented; verification pending | Rejected/exhausted-error transitions use preconditioned atomic commits | Repository commit/precondition tests and 167-test Functions emulator suite pass | Inventory found no legacy partial data; deployed fault matrix pending |
| `RV-H09` | Implemented; verification pending | All manifest pages and empty boards reconcile via scheduled board tasks | Pagination, empty-board, demotion, and purge tests pass locally | Over-100 deployed lifecycle drill pending |
| `RV-M01` | In progress | Added production-shaped Firestore/Storage precondition and pagination coverage | Focused suites pass; aggregate service coverage is 61.1% | Complete risk matrix and real emulator/Storage integration pending |
| `RV-M02` | Implemented; verification pending | Shared canonical floor conversion exported from `run_protocol` | Duration and 18 focused UI tests pass | Full Flutter suite has 3 unrelated asset-generation failures |
| `RV-M03` | Implemented; verification pending | Separate readiness, stable public errors, structured dispatch categories, four log metrics, and ten validator/projection/recovery policies | Readiness/safe rejection tests, policy API validation, healthy native probe series, and canary pass | Synthetic false incidents were intentionally not generated; runbook alert-response drill remains |
| `RV-L01` | Closed | Digest-pinned distroless runtime, numeric non-root identity, allowlisted contexts, and source CI workflow | Exact image runs as UID/GID 65532; GitHub/Trivy report 0 Critical/High | Exact successful commit digest is deployed to revision `00024-rzt` |
| `RV-L02` | Closed | Commands, links, region examples, queues, `/live` and `/ready`, and service policy corrected | Policy syntax, local smoke, exact-image smoke, and production probe evidence pass | Correct production routes and configuration serve 100% |
| `RV-L03` | Closed | `googleapis` 16.0.0 and `googleapis_auth` 2.3.3 | Analyzer, dependency freshness, adapters, GitHub workflow, and production canary pass | Exact commit artifact is deployed |

### Successor finding ledger

| Audit ID | Status | Evidence | Closure gate |
|---|---|---|---|
| `RV2-M01` | Closed | Commit `815aadde` has successful Functions and Replay Validator push workflows; the exact commit archive produced the release image | GitHub test/AOT/container/Trivy gate and local exact-image scan/smoke pass | Immutable exact-commit digest serves revision `00024-rzt` |
| `RV2-M02` | Implemented; verification pending | Structured HTTP 400/`FAILED_PRECONDITION` classification is limited to the exact Google status; lease and every atomic-handoff fixture use the production response; worker emits `lease_conflict` retry telemetry | Analysis and 75 tests pass; exact successful commit is live and the production canary passed | A new forced concurrent precondition collision was not generated in production |
| `RV2-L01` | Closed | `/live` and `/ready` replace the reserved-suffix routes in source and deployment policy | Revision `replay-validator-00024-rzt` serves 100%; Cloud Run recorded healthy startup and liveness probes |

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

- [ ] Every validation write is fenced to an unexpired lease token.
- [ ] Crashes, timeouts, duplicate tasks, and exhausted queues converge without
      manual document edits.
- [ ] Internal-error grace has one immutable start and a finite outcome.
- [ ] Replay memory, CPU, and wall-time work is bounded.
- [ ] Queue and Cloud Run resource/retry configuration is explicit and
      deployed.

### Evidence and compatibility

- [ ] Validated and promoted bytes match one immutable generation and digest.
- [ ] Every external protocol constraint is checked explicitly in AOT.
- [ ] Ticket identity, loadout, board snapshot, and compatibility versions are
      enforced.
- [ ] Client and validator share canonical duration behavior.

### Terminal and projection consistency

- [ ] Accepted, rejected, and internal-error transitions are atomic or durably
      resumable with preconditions.
- [ ] Reward-grant and terminal session state cannot disagree.
- [ ] Player best is monotonic under concurrency.
- [ ] Top 10 and ghost eligibility converge after partial failure and stale
      delivery.
- [ ] Projection misconfiguration cannot acknowledge work.

### Ghost lifecycle

- [ ] Only the exact validated generation is published.
- [ ] Empty boards and boards with more than 100 historical manifests
      reconcile correctly.
- [ ] Demoted artifacts expire without requiring a new player submission.

### Operations and release

- [ ] Production adapters have direct integration/failure coverage.
- [ ] Readiness fails closed; telemetry is structured and player-safe.
- [ ] Alerts and runbooks are exercised.
- [ ] Container, dependencies, build context, commands, and docs are current.
- [ ] Repair inventory is empty or every exception has an incident disposition.
- [ ] A separate successor audit confirms no release-blocking finding remains.
- [ ] Every ledger row is `Closed`.

Only after every final acceptance item is checked should the release block be
removed and this plan be archived.
