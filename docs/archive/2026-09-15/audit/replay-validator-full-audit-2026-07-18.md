# Replay Validator Full Audit

**Audit date:** 2026-07-18  
**Scope:** `services/replay_validator/**` plus the protocol, Firebase Functions,
Core, client, and Google Cloud boundaries that determine replay-validation
correctness  
**Source snapshot:** commit `d924895cf32f25abd6fdc4f3317fbfbc9936dcc9`
with the working tree's current replay-validator and settlement/projection
changes included  
**Overall result:** **Release blocked**

## Executive summary

The replay validator has a sound high-level architecture: it reconstructs runs
in the deterministic Core, does not trust the client's claimed score, uses a
private Cloud Run deployment model, and performs the accepted validation
handoff with Firestore preconditions. Static analysis, the current unit suite,
the AOT compile, shared-protocol tests, Core tests, and adjacent Functions tests
all pass.

The implementation is not yet safe to release as the authoritative validation
and projection path. This audit found:

- **3 Critical** findings
- **9 High** findings
- **3 Medium** findings
- **3 Low** findings

The primary blockers are:

1. A worker crash after lease acquisition can strand a run in `validating`
   forever, while the next Cloud Tasks delivery is acknowledged successfully.
2. The persisted start of the internal-error grace period is discarded by the
   production Firestore repository, so the grace period can restart on every
   attempt and never expire.
3. Compressed replay size, decompressed size, and simulated tick count are not
   bounded, allowing an authenticated user to create unbounded memory and CPU
   work.

The projection path also has correctness gaps under ordinary retries and
concurrency. A partial leaderboard write can become permanently inconsistent,
concurrent writes can replace a better result with a worse result, and ghost
promotion copies the latest mutable storage object rather than the exact object
generation that was validated.

### Release recommendation

Do not enable production reward settlement, leaderboard projection, or ghost
publication through this revision until all Critical findings and
`RV-H01` through `RV-H08` are resolved. `RV-H09` should also be closed before
the first board can accumulate more than 100 ghost manifests.

## Audit method and limits

The audit covered:

- HTTP routing, result-to-status mapping, health behavior, and configuration
- validation lease acquisition and terminal state transitions
- replay download, decoding, contract checks, deterministic simulation, and
  result comparison
- transient/internal error policy and retry behavior
- accepted-run handoff and reward-settlement dispatch
- leaderboard projection, tie-breaking, top-10 materialization, and ghost
  lifecycle
- Firestore and Cloud Storage REST usage
- shared protocol invariants and Core integration
- Firebase Functions upload/finalization and settlement boundaries
- Docker/Cloud Run and Cloud Tasks deployment instructions
- unit tests, coverage, AOT compilation, dependency freshness, and
  documentation consistency

This is a source and local-build audit. It did **not** inspect a live Google
Cloud project's IAM bindings, deployed Cloud Run revision, queue settings,
Firestore indexes/rules, logs, alerts, budgets, or stored production data.
Those should be checked as a separate deployment-readiness review.

## Findings overview

| ID | Severity | Area | Finding |
|---|---|---|---|
| RV-C01 | Critical | Lease lifecycle | A crash can strand `validating` sessions and the retry is acknowledged |
| RV-C02 | Critical | Retry policy | The internal-error grace timestamp is dropped by the production repository |
| RV-C03 | Critical | Resource safety | Replay decompression and simulation work are unbounded |
| RV-H01 | High | Cloud Tasks | The validator's documented retry schedule is not enforced |
| RV-H02 | High | Ghost integrity | Projection does not copy the exact storage generation that was validated |
| RV-H03 | High | Idempotency | A retry after partial leaderboard projection skips top-10 repair |
| RV-H04 | High | Concurrency | Player-best and top-10 updates are vulnerable to lost updates |
| RV-H05 | High | Configuration | A misconfigured projection worker returns success and drops tasks |
| RV-H06 | High | Protocol safety | Production protocol bounds and version checks rely on ignored assertions or are absent |
| RV-H07 | High | Compatibility | Ticket identity, compatibility versions, and board manifest bindings are not enforced |
| RV-H08 | High | Atomicity | Rejection/internal-error finalization can partially commit or mutate an invalid reward grant |
| RV-H09 | High | Ghost lifecycle | Manifest reconciliation is capped at 100 records and has no independent cleanup |
| RV-M01 | Medium | Test assurance | Overall line coverage is 39.9%, with production adapters almost untested |
| RV-M02 | Medium | Cross-layer consistency | Canonical run duration is rounded differently in validator and client |
| RV-M03 | Medium | Operations | Readiness, structured error telemetry, and client-safe error handling are incomplete |
| RV-L01 | Low | Container hardening | The runtime runs as root and build-context exclusions are absent |
| RV-L02 | Low | Documentation | Validation commands, links, region examples, and implementation descriptions have drifted |
| RV-L03 | Low | Maintenance | Direct Google API dependencies are behind available versions |

## Critical findings

### RV-C01 — A crash can strand `validating` sessions and the retry is acknowledged

**Evidence**

- `services/replay_validator/lib/src/run_session_repository.dart:187-191`
  returns `alreadyValidating` whenever the stored state is `validating`.
  Although `validationStartedAtMs` is stored, it is not used to expire or
  reclaim a stale lease.
- `services/replay_validator/lib/src/validator_worker.dart:128-143` treats every
  non-acquired lease result, including `alreadyValidating`, as an accepted
  no-op.
- `services/replay_validator/lib/src/app.dart:133-139` maps that result to HTTP
  `202`.
- There is no repair job or callable that recovers stale `validating` sessions.

Cloud Tasks removes a task after a successful response; a non-2xx response or a
missed deadline is considered a failed attempt. Therefore the `202` response
deletes the only automatic recovery attempt. See the
[Cloud Tasks task-attempt behavior](https://docs.cloud.google.com/tasks/docs/reference/rest/v2/projects.locations.queues.tasks).

**Failure sequence**

1. Worker A changes `pending_validation` to `validating`.
2. Worker A crashes, times out, is terminated, or loses a write before a
   terminal state is committed.
3. Cloud Tasks invokes worker B.
4. Worker B sees `validating`, returns `accepted`, and the app responds `202`.
5. Cloud Tasks deletes the task and the session remains `validating`
   indefinitely.

There is also no lease token. Adding only a time-based reclaim would allow a
slow worker from an old lease to write over the result of a newer worker.

**Impact**

- Runs, rewards, and projections can remain unresolved permanently.
- Operational retry cannot repair the state.
- A slow/stale worker can become unsafe once lease reclamation is introduced.

**Required remediation**

- Store a unique lease/attempt token and lease expiry when acquiring a lease.
- Require that token, the expected state, and an update-time precondition on
  every lease-owned write.
- Reclaim expired leases transactionally.
- Return a retryable response for an active lease unless another durable task
  is guaranteed to revisit it.
- Add a scheduled repair path for existing stale `validating` documents.
- Test crash-after-lease, concurrent reclaim, stale-writer rejection, and
  Cloud Tasks redelivery.

### RV-C02 — The internal-error grace timestamp is dropped by the production repository

**Evidence**

- `services/replay_validator/lib/src/run_session_repository.dart:543-573`
  decodes `internalErrorFirstAtMs` from Firestore.
- `services/replay_validator/lib/src/run_session_repository.dart:256-264`
  constructs the acquired `RunSessionRecord` without carrying that field
  forward.
- `services/replay_validator/lib/src/validator_worker.dart:215-264` falls back
  to the current clock when the field is null, persists that new value, and
  uses it as the start of the grace period.
- Unit tests use an in-memory repository path that retains the timestamp; the
  production repository has only 2.1% line coverage.

**Impact**

Every new production lease can appear to be the first internal-error attempt.
The grace deadline can move forward indefinitely, so persistent infrastructure
or implementation errors may never reach the intended terminal/revocation
path. This can leave reward grants provisional and sessions retrying or pending
without a finite resolution.

**Required remediation**

- Preserve `internalErrorFirstAtMs` in the acquired record.
- Add a repository-level round-trip test using Firestore-shaped payloads.
- Add an end-to-end test that acquires, schedules an internal-error retry,
  reacquires, and proves that the original grace start remains unchanged.
- Backfill or repair affected sessions using the earliest available error or
  validation timestamp.

### RV-C03 — Replay decompression and simulation work are unbounded

**Evidence**

- Firebase Functions limits the uploaded compressed/raw object to 8 MiB in
  `functions/src/runs/submission_store.ts:22` and
  `functions/src/runs/submission_store.ts:226-249`.
- `services/replay_validator/lib/src/replay_loader.dart:52-64` downloads the
  object into memory.
- `services/replay_validator/lib/src/validator_worker.dart:418-430` calls
  `gzip.decode` without a decompressed-size limit.
- `packages/run_protocol/lib/replay_blob.dart:94-96` accepts `totalTicks` as
  an integer and has no production maximum.
- `services/replay_validator/lib/src/validator_worker.dart:602-609` verifies
  only that `totalTicks` is not before the final command.
- `services/replay_validator/lib/src/validator_worker.dart:641-652` simulates
  until the user-controlled `totalTicks` is reached.
- The deployment instructions do not set Cloud Run concurrency, memory, CPU,
  timeout, or instance limits.

An authenticated player can upload a small gzip object with a very large
expanded form, or a compact valid replay declaring an extremely large tick
count. Both operations happen before a bounded terminal decision.

This risk is amplified by Cloud Run defaults: request timeout defaults to five
minutes, memory defaults to 512 MiB, CPU defaults to one vCPU, and newly created
services may allow high per-instance concurrency. A timed-out request can
continue executing in the container. See the official documentation for
[request timeout](https://docs.cloud.google.com/run/docs/configuring/request-timeout),
[memory limits](https://docs.cloud.google.com/run/docs/configuring/services/memory-limits),
[CPU](https://docs.cloud.google.com/run/docs/configuring/services/cpu), and
[concurrency](https://docs.cloud.google.com/run/docs/about-concurrency).

**Impact**

- Memory exhaustion, CPU exhaustion, timeouts, elevated cost, and validator
  outage.
- Multiple malicious or accidental tasks can amplify the effect through
  instance concurrency.
- A timeout can combine with `RV-C01` to strand the session.

**Required remediation**

- Stream the object and decompression path with hard limits on compressed and
  expanded bytes.
- Define protocol limits for frame count, `totalTicks`, run duration, command
  density, and all collection sizes.
- Reject violations before creating or stepping `GameCore`.
- Add a monotonic execution deadline/cancellation check during simulation.
- Configure and document Cloud Run memory, CPU, timeout, concurrency, maximum
  instances, and Cloud Tasks dispatch limits based on load testing.
- Add gzip-bomb, extreme-tick, extreme-frame, and timeout tests.

## High findings

### RV-H01 — The validator's documented retry schedule is not enforced

**Evidence**

- `services/replay_validator/lib/src/validator_worker.dart:287-304` calculates
  `validationNextAttemptAtMs` and stores `pending_validation`.
- `services/replay_validator/lib/src/run_session_repository.dart:193-203`
  reacquires a `pending_validation` session without checking that timestamp.
- `services/replay_validator/lib/src/app.dart:133-139` returns `503`, leaving
  retry timing entirely to Cloud Tasks.
- `services/replay_validator/README.md` creates queues without explicit retry,
  dispatch-rate, or concurrency settings.
- No component schedules a replacement task at
  `validationNextAttemptAtMs`.

Cloud Tasks applies its queue-level exponential-backoff configuration to failed
attempts; the timestamp stored in Firestore does not influence that schedule.
See [Configure Cloud Tasks queues](https://docs.cloud.google.com/tasks/docs/configuring-queues).

**Impact**

- The stated 30-second/2-minute/etc. policy is metadata, not behavior.
- Default or pre-existing queue configuration can hot-loop, exhaust attempts
  early, or leave a pending session without a task.
- Incident grace behavior cannot be reasoned about from application state.

**Required remediation**

Choose one retry authority:

- Prefer Cloud Tasks as the authority: configure queues declaratively, align
  application attempt/grace accounting with actual task headers, and remove
  misleading scheduling state; or
- Create a replacement task with an explicit schedule time and acknowledge the
  current task only after durable enqueue, with idempotent task naming.

Whichever approach is selected, add a repair scanner for pending sessions whose
task was exhausted or lost.

### RV-H02 — Projection does not copy the exact storage generation that was validated

**Evidence**

- Upload finalization records `storageGeneration` in
  `functions/src/runs/submission_store.ts:67-74` and
  `functions/src/runs/submission_store.ts:292-299`.
- `UploadedReplayRef` in
  `services/replay_validator/lib/src/run_session_repository.dart:27-40` has no
  generation field, and its decoder at
  `services/replay_validator/lib/src/run_session_repository.dart:581-605`
  drops the finalized generation.
- `services/replay_validator/lib/src/replay_loader.dart:52-64` downloads the
  latest generation at the object path.
- `services/replay_validator/lib/src/ghost_publisher.dart:216-220` promotes a
  ghost by source path.
- `services/replay_validator/lib/src/ghost_publisher.dart:471-478` calls
  `objects.copy` without `sourceGeneration` or
  `ifSourceGenerationMatch`.
- The signed upload URL remains usable until its expiry.

Anyone possessing a signed URL can use it while it is active, and Cloud Storage
supports generation-pinned copy requests. See
[Cloud Storage signed URLs](https://docs.cloud.google.com/storage/docs/access-control/signed-urls)
and the
[Objects: copy API](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/copy).

**Failure sequence**

1. Replay generation A is finalized and validated.
2. Before or during projection, the same upload URL/path is overwritten with
   generation B.
3. Projection copies the latest object B but publishes metadata and score from
   validation of A.

**Impact**

- The leaderboard can advertise a ghost artifact different from the replay
  that earned the score.
- A corrupt or resource-heavy artifact can be promoted as trusted content.
- Auditability and deterministic evidence are broken.

**Required remediation**

- Propagate the finalized storage generation through `UploadedReplayRef`,
  `ValidatedRun`, projection input, and ghost manifest.
- Read and copy the exact generation with source-generation preconditions.
- Make upload finalization single-use with object-generation preconditions, or
  immediately promote the validated object to an immutable evidence location.
- Persist and verify a content digest for the promoted object.

### RV-H03 — A retry after partial leaderboard projection skips top-10 repair

**Evidence**

- `services/replay_validator/lib/src/leaderboard_projector.dart:128-135`
  returns early when an existing player-best entry is equal to or better than
  the candidate.
- The player-best upsert happens before `_refreshTop10View`.
- If the upsert succeeds but top-10 refresh fails, the task returns a retryable
  failure.
- On retry, the newly stored equal candidate triggers the early return, so
  top-10 refresh is never retried.

The same pattern can leave ghost-eligibility flags partially updated.

**Impact**

- Player-best and materialized top-10 state can disagree permanently.
- Ghost publication can run from a stale top-10 view.
- A transient Firestore error becomes durable ranking corruption.

**Required remediation**

- Treat “same run already stored” as an idempotent continuation, not completion.
- Track projection revision/state and reconcile every required side effect.
- Add injected-failure tests after player-best write and during each top-10 or
  ghost-eligibility update.

### RV-H04 — Player-best and top-10 updates are vulnerable to lost updates

**Evidence**

- `services/replay_validator/lib/src/leaderboard_projector.dart:128-135`
  performs read/compare/write without a transaction.
- `services/replay_validator/lib/src/leaderboard_projector.dart:320-327`
  patches player best without an update-time precondition.
- `services/replay_validator/lib/src/leaderboard_projector.dart:142-196`
  rebuilds top 10 from multiple independent reads and writes.
- `services/replay_validator/lib/src/leaderboard_projector.dart:405-420`
  updates the materialized view without a generation or revision precondition.

**Failure scenarios**

- Two tasks for the same player both read the old best; the worse candidate
  writes last and replaces the better one.
- Two different players update concurrently; a stale top-10 refresh writes
  after a newer refresh and removes a valid entry.

**Impact**

- Competitive rankings and tie-breaking can be wrong.
- Ghost eligibility can be assigned to the wrong runs.
- Retrying does not guarantee convergence.

**Required remediation**

- Make player-best comparison and replacement transactional or conditional on
  the observed update time.
- Serialize materialized-view generation per board, or use a monotonic board
  revision and reject stale writes.
- Add a scheduled reconciliation process that derives top 10 from player-best
  truth.
- Add deterministic concurrent-update tests for same-player and
  different-player cases.

### RV-H05 — A misconfigured projection worker returns success and drops tasks

**Evidence**

- `services/replay_validator/lib/src/app.dart:52-54` installs stub workers when
  required project/bucket configuration is absent.
- `services/replay_validator/lib/src/projection_worker.dart:82-90` makes
  `StubProjectionWorker` return `completed`.
- `services/replay_validator/lib/src/app.dart:160-168` maps `completed` to HTTP
  `200`.
- `/healthz` also returns `200` regardless of whether real workers were built.

**Impact**

A deployment with a missing or malformed environment variable can appear
healthy while every projection task is acknowledged and permanently discarded.
Accepted runs then lack leaderboard and ghost side effects.

**Required remediation**

- Fail startup in deployed/non-test environments when mandatory configuration
  is missing.
- Return a retryable response from any non-production stub.
- Separate liveness from readiness and report worker/configuration readiness.
- Add a deployment smoke test that submits a synthetic task and verifies a
  durable projection result.

### RV-H06 — Production protocol bounds and version checks rely on ignored assertions or are absent

**Evidence**

- `packages/run_protocol/lib/replay_blob.dart:17-26` uses `assert` for frame
  tick, paired aim axes, and nonnegative command-state constraints.
- `packages/run_protocol/lib/replay_blob.dart:94-96` uses `assert` for
  replay version, tick rate, and total ticks.
- `commandEncodingVersion` is decoded without an explicit supported-version
  check.
- `services/replay_validator/lib/src/validator_worker.dart:602-609` and
  `services/replay_validator/lib/src/validator_worker.dart:710-751` do not
  fully replace those checks; unknown command bits can be ignored.
- The Dockerfile compiles the server to an AOT executable.

Dart assertions are ignored in production unless explicitly enabled. See
[Dart assertion behavior](https://dart.dev/language/error-handling).

**Impact**

- Malformed or future-version replays can be interpreted as the current
  command encoding.
- Test/JIT behavior can differ from deployed AOT behavior.
- Negative or invalid values can reach simulation paths not designed for them.

**Required remediation**

- Replace protocol safety assertions with explicit decode/validation errors.
- Allowlist replay and command-encoding versions.
- Validate known command-bit masks, paired axes, frame counts, and numeric
  ranges.
- Keep asserts only for programmer invariants after external input has been
  validated.
- Test the production decoder with assertions disabled or through the AOT
  artifact.

### RV-H07 — Ticket identity, compatibility versions, and board manifest bindings are not enforced

**Evidence**

- `RunTicket` carries `uid`, `runSessionId`, `loadoutDigest`,
  `gameCompatVersion`, `rulesetVersion`, `scoreVersion`, and `ghostVersion`.
- `services/replay_validator/lib/src/validator_worker.dart:453-515` compares a
  subset of replay/session fields but does not:
  - bind ticket `uid` and `runSessionId` to the session;
  - recompute or verify `loadoutDigest`;
  - select Core behavior by `gameCompatVersion`;
  - enforce supported ruleset, score, or ghost versions.
- `services/replay_validator/lib/src/validator_worker.dart:362-383` checks only
  whether the board exists.
- The loaded board manifest content is not parsed and matched to the ticket.
- `services/replay_validator/lib/src/validator_worker.dart:628-635` always
  creates the current Core implementation.

**Impact**

- Compatibility/version fields are descriptive rather than authoritative.
- Deploying a changed Core can reinterpret old issued tickets.
- Corrupt or mismatched ticket/session data is not rejected reliably.
- Deleting a board can reject an otherwise valid issued run even though board
  content is not used for validation.

**Required remediation**

- Define a compatibility registry mapping ticket versions to the exact
  validation implementation and scoring rules.
- Validate ticket/session/player identity and recompute the loadout digest.
- Parse the board manifest and match board key, revision, ruleset, score, and
  ghost versions.
- Define whether issued tickets remain valid after board closure/deletion and
  preserve the immutable data required to honor that policy.
- Add fixtures for every supported and unsupported version combination.

### RV-H08 — Rejection/internal-error finalization can partially commit or mutate an invalid reward grant

**Evidence**

- `services/replay_validator/lib/src/validator_worker.dart:185-210` performs
  rejected-run persistence, reward mutation, and session terminalization as
  separate operations.
- `services/replay_validator/lib/src/validator_worker.dart:266-284` does the
  same for terminal internal errors.
- `services/replay_validator/lib/src/reward_settlement_writer.dart:45-70`
  patches a reward document without `currentDocument`, update-time, expected
  state, or player/session binding preconditions.
- The writer's `404` handling at
  `services/replay_validator/lib/src/reward_settlement_writer.dart:71-75`
  assumes a missing document fails, while Firestore REST patch is an
  update-or-insert operation unless a precondition is supplied. See
  [Firestore documents.patch](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/projects.databases.documents/patch).

The accepted validation handoff does better: it uses an atomic Firestore commit
with existence/update-time preconditions. The rejected and exhausted-error
paths do not provide equivalent guarantees.

**Impact**

- A grant can be revoked while the session remains nonterminal, or a session
  can terminalize while the grant remains provisional.
- A missing grant can be created as a malformed partial document.
- An unexpected grant state can be overwritten.
- Combined with `RV-C01`, a partial failure can become unrecoverable.

**Required remediation**

- Use one transactional/atomic commit for validated-run evidence, reward state,
  and session terminalization.
- Require document existence, expected grant state, uid/session binding,
  update-time, and lease-token preconditions.
- Specify and test the intentional behavior when a grant is missing.
- Add fault-injection tests at every write boundary.

### RV-H09 — Manifest reconciliation is capped at 100 records and has no independent cleanup

**Evidence**

- `services/replay_validator/lib/src/ghost_publisher.dart:326-345` lists at most
  100 manifests and does not follow a page token.
- `services/replay_validator/lib/src/ghost_publisher.dart:156-200` can demote or
  purge only manifests returned by that list.
- The publisher returns early when top 10 is empty, before reconciling prior
  active manifests.
- Purging happens only as a side effect of a later projection; no scheduled
  ghost-retention cleanup exists.

**Impact**

- Once a board has more than 100 historical manifests, stale active ghosts can
  remain exposed and expired demoted objects can remain stored indefinitely.
- An emptied or closed board does not reliably demote its previous top-10
  ghosts.
- Storage-retention and download-authorization expectations are not enforced.

**Required remediation**

- Paginate all relevant manifests, or query active and expired-demoted states
  separately.
- Reconcile even when the current top 10 is empty.
- Add an independent scheduled cleanup/reconciliation job.
- Add tests with more than 100 manifests, tied ranks, empty top 10, and boards
  with no future projections.

## Medium findings

### RV-M01 — Overall line coverage is 39.9%, with production adapters almost untested

Coverage was collected with:

```text
dart test --coverage=../../.tmp/replay_validator_coverage test
```

The result was **491 / 1,230 executable library lines (39.9%)**.

| File | Covered / executable | Coverage |
|---|---:|---:|
| `board_repository.dart` | 0 / 13 | 0.0% |
| `firestore_value_codec.dart` | 0 / 60 | 0.0% |
| `google_api_helpers.dart` | 0 / 15 | 0.0% |
| `reward_settlement_writer.dart` | 0 / 14 | 0.0% |
| `run_session_repository.dart` | 5 / 239 | 2.1% |
| `replay_loader.dart` | 1 / 16 | 6.2% |
| `leaderboard_projector.dart` | 53 / 160 | 33.1% |
| `ghost_publisher.dart` | 66 / 181 | 36.5% |
| `settlement_dispatcher.dart` | 25 / 41 | 61.0% |
| `metrics.dart` | 8 / 13 | 61.5% |
| `validator_worker.dart` | 237 / 354 | 66.9% |
| `app.dart` | 77 / 103 | 74.8% |
| `projection_worker.dart` | 19 / 21 | 90.5% |

The suite has good business-path coverage through fakes, but the lowest-covered
files are exactly where production Firestore/Storage serialization,
preconditions, and error interpretation live. `RV-C02` and `RV-H08` are
examples of defects that fake repositories do not expose.

**Recommendation**

- Add emulator-backed Firestore and Storage integration tests.
- Add contract tests for every repository codec and REST precondition.
- Add concurrency, partial-failure, redelivery, malformed-input, and
  generation-pinning suites.
- Establish per-file critical-adapter coverage gates rather than relying only
  on an aggregate percentage.

### RV-M02 — Canonical run duration is rounded differently in validator and client

**Evidence**

- `services/replay_validator/lib/src/validator_worker.dart:685` uses
  `(tick / tickHz).round()`.
- `lib/ui/leaderboard/run_result.dart:94-95` uses integer division, which
  floors the value.

**Impact**

A run with a fractional final second can differ by one second between the
player-visible provisional result and the authoritative projected result.
Duration-based tie-breaking can also disagree.

**Recommendation**

Define one shared tick-to-duration function and use it in Core/protocol-aware
code on both sides. Add boundary tests immediately below, at, and above the
half-second mark.

### RV-M03 — Readiness, structured error telemetry, and client-safe error handling are incomplete

**Evidence**

- `/healthz` reports success even when only stubs are installed.
- Invalid/missing environment values are silently defaulted in
  `services/replay_validator/lib/src/app.dart:221-245`.
- `services/replay_validator/lib/src/metrics.dart:29-44` accepts a message but
  does not emit it, while error class and stack are often absent.
- `services/replay_validator/lib/src/validator_worker.dart:211-214` and
  `services/replay_validator/lib/src/validator_worker.dart:289-303` can persist
  raw exception strings into run-session fields that are potentially surfaced
  to clients.

**Impact**

- Misconfigured revisions can receive traffic.
- Operations lacks actionable error class/stack/correlation information.
- Backend implementation details can leak to clients.

**Recommendation**

- Add separate liveness and readiness endpoints with configuration and
  dependency checks.
- Emit structured fields for run/session/task/attempt, error class, safe
  category, latency, and stack trace.
- Persist only stable public error codes/messages; keep raw exceptions in
  restricted logs.
- Add alerts for stale leases, retry exhaustion, settlement lag, projection
  lag, and reconciliation drift.

## Low findings

### RV-L01 — The runtime runs as root and build-context exclusions are absent

`services/replay_validator/Dockerfile` does not create/switch to a non-root
user. Neither repository nor service-level `.dockerignore`/`.gcloudignore`
files were found, so local build/deploy context can be unnecessarily broad.

**Recommendation**

- Run the final image as an unprivileged user.
- Add explicit build-context exclusions for VCS metadata, local artifacts,
  coverage, editor files, unrelated generated outputs, and secrets.
- Pin base images by digest through the repository's dependency-update process.

### RV-L02 — Validation commands, links, region examples, and implementation descriptions have drifted

- The repository-level command
  `dart test services/replay_validator/test` fails because package resolution
  starts from the root package, which does not depend on `package:test`.
  Running `dart test test` from `services/replay_validator` succeeds.
- `services/replay_validator/README.md` still describes portions of the service
  as a scaffold/stub despite their implementation.
- The related ghost-flow link names
  `ghost_run_flow_what_how_why.md`, but the repository contains
  `ghost_run_flow.md`.
- A Functions log example uses `us-central1`, while the repository's backend
  region default is `europe-west1`.
- Queue creation examples do not capture retry or dispatch policy.

**Recommendation**

Make all commands independent of caller location, correct links and regions,
describe implemented behavior, and move queue/service configuration into
reviewable declarative files.

### RV-L03 — Direct Google API dependencies are behind available versions

`dart pub outdated --no-dev-dependencies` reported:

- `googleapis` 14.0.0 installed; 16.0.0 resolvable/latest
- `googleapis_auth` 2.2.0 installed; 2.3.3 upgradable

This audit did not identify a vulnerability from those versions. The gap is a
maintenance and future-compatibility concern.

**Recommendation**

Upgrade in a dedicated change, review major-version release notes, rerun the
full service/adapter suite, build the image, and smoke-test authenticated
Firestore, Storage, and service-to-service calls.

## Positive controls observed

The following implementation choices should be retained:

- The authoritative score and result are reconstructed through deterministic
  Core simulation; the client's summary is not trusted as authority.
- Replay digest, ticket/session fields, monotonic ticks, axis encoding, and
  held/pressed command relationships receive explicit validation in the worker.
- Accepted-run finalization uses an atomic Firestore commit with
  existence/update-time preconditions.
- Settlement dispatch occurs after durable accepted handoff, so an immediate
  dispatch failure can safely produce a retryable response.
- Settlement and leaderboard/ghost projection are separated into explicit
  workers.
- Deployment instructions use private Cloud Run access and authenticated
  service-to-service invocation.
- The service compiles successfully to an AOT executable.

## Validation results

| Check | Result | Notes |
|---|---|---|
| `dart analyze services/replay_validator` | Pass | No issues |
| `dart analyze` from service directory | Pass | No issues |
| `dart test services/replay_validator/test --reporter expanded` from root | Fail | Command/package-resolution defect; `package:test` not found |
| `dart test test --reporter expanded` from service directory | Pass | 24 tests |
| Service coverage run | Pass | 39.9% library-line coverage |
| AOT compile of `bin/server.dart` | Pass | Executable produced in ignored `.tmp` |
| `dart analyze packages/run_protocol` | Pass | No issues |
| `dart test test` in `packages/run_protocol` | Pass | 28 tests |
| `dart analyze` in `packages/runner_core` | Pass | No issues |
| Relevant runner-core tests | Pass | 5 tests |
| `corepack pnpm --dir functions build` | Pass | Local Node 24 differs from declared Node 20 engine |
| `corepack pnpm --dir functions test` | Pass | Emulator suite passed; environment emitted Node/project warnings |
| Docker image build | Not run | Docker Desktop daemon was unavailable |

The passing unit suite confirms the currently modeled behavior. It does not
clear the release blockers because the most consequential defects occur in
production repositories, retry/redelivery, concurrency, unbounded input, and
partial-failure behavior that the suite does not model.

## Prioritized remediation plan

### P0 — Authority and availability

1. Implement expiring, fenced validation leases and a stale-session repair job
   (`RV-C01`).
2. Preserve the original internal-error grace timestamp and repair affected
   sessions (`RV-C02`).
3. Bound compressed/expanded bytes, frames, commands, ticks, duration, and
   execution time; configure conservative Cloud Run/Tasks resource limits
   (`RV-C03`).
4. Make the retry authority explicit and durable (`RV-H01`).
5. Pin every validation and ghost operation to an immutable storage generation
   (`RV-H02`).

### P1 — Correctness under retries and concurrency

1. Make projection resumable after every partial write (`RV-H03`).
2. Add transactional/conditional player-best updates and versioned top-10
   reconciliation (`RV-H04`).
3. Fail closed on missing production configuration (`RV-H05`).
4. Enforce all protocol bounds, encoding versions, ticket identities, and
   compatibility/board bindings (`RV-H06`, `RV-H07`).
5. Make rejection and exhausted-error finalization atomic and preconditioned
   (`RV-H08`).

### P2 — Lifecycle, assurance, and operations

1. Paginate ghost reconciliation and add scheduled retention cleanup
   (`RV-H09`).
2. Add emulator, concurrency, redelivery, generation, and fault-injection
   coverage (`RV-M01`).
3. Unify duration conversion (`RV-M02`).
4. Add readiness, safe structured errors, dashboards, and alerts (`RV-M03`).
5. Complete container, documentation, and dependency maintenance
   (`RV-L01` through `RV-L03`).

## Suggested exit criteria

The release block can be lifted when:

- all Critical and High findings have regression tests and are closed;
- stale leases and pending validations are demonstrably recoverable;
- malicious-boundary tests complete within fixed memory and time budgets;
- projection converges after injected failure and concurrent delivery;
- the promoted ghost's generation and digest match the validated object;
- all terminal transitions are atomic or safely resumable;
- queue/service resource and retry policies are checked into the repository;
- service, protocol, Core, Functions, emulator integration, AOT, and container
  checks pass in CI;
- live deployment readiness verifies IAM, authenticated task audiences, queue
  policy, alerts, and rollback behavior.
