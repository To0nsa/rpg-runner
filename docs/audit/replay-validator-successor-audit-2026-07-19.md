# Replay Validator Successor Audit

**Audit date:** 2026-07-19  
**Evidence baseline:** [Replay Validator Full Audit — July 18, 2026](replay-validator-full-audit-2026-07-18.md)  
**Baseline Git blob hash:** `4b075d4b1b571d3c947d79f9b0bbb22c519aca20`  
**Source snapshot:** commit `d924895cf32f25abd6fdc4f3317fbfbc9936dcc9`
plus the current uncommitted replay-validator remediation working tree  
**Overall result:** **Release remains blocked**

## Executive summary

The remediation working tree addresses the source defects behind all three
Critical and all nine High findings from the July 18 audit. Fresh analysis,
unit/emulator tests, AOT probes, container scans, an isolated exact-image
deployment, and live configuration inspection provide substantially stronger
evidence than the baseline audit had.

This audit does not close the production release gate. The source and local
evidence has not yet been committed and exercised by GitHub Actions, there is
no staging environment for the required destructive/fault-injection matrix,
validator/projection monitoring is incomplete, and production exposed an
unhandled Firestore precondition-conflict classification during this audit.
That conflict recovered through Cloud Tasks retry without inconsistent state,
but it proves the production REST response does not match the status codes used
by the current classifier and unit fixture.

Successor findings:

- **0 Critical**
- **0 High**
- **2 Medium**
- **1 Low**

No original Critical or High source defect was found unchanged. All original
Critical and High rows remain `Implemented; verification pending`, rather than
`Closed`, because their required staging, repair, and deployed failure evidence
is incomplete.

### Release recommendation

Keep replay-validator release expansion blocked. Commit the remediation and CI
gate, correct and test the production precondition-conflict classifier, deploy
the non-reserved health routes through a controlled rollout, add the missing
validator/projection alerts, and complete the staging fault matrix before
closing any original Critical or High finding.

## Audit method

This successor audit covered:

- a finding-by-finding source comparison against all 18 baseline findings;
- replay-validator, shared-protocol, deterministic-Core, Functions emulator,
  Flutter, AOT, dependency, and container checks;
- final-image process identity, health behavior, malformed-task behavior, and
  Critical/High vulnerability scanning;
- an isolated private Cloud Run deployment by the exact locally scanned image
  digest;
- production Cloud Run, Cloud Tasks, IAM, Firestore indexes, Functions,
  Scheduler, Monitoring, logs, and aggregate persisted-state inventory;
- verification that the July 18 evidence file remained byte-for-byte
  unchanged.

The audit did not mutate production Firestore data, enqueue destructive test
traffic, switch production Cloud Run traffic, or perform fault injection in
production.

## Scope and evidence identity

The repository remains on `master` at
`d924895cf32f25abd6fdc4f3317fbfbc9936dcc9`. The remediation is a dirty working
tree and therefore does not yet have a reviewable commit identity.

The final successor-audit container evidence is:

| Item | Evidence |
|---|---|
| Local image | `replay-validator:deployed-smoke-candidate` |
| Local image ID | `sha256:24425cc992a595812d1165cb7a3aa292c09a329bdeb34429a6bc0e12f778a217` |
| Artifact Registry tag | `successor-audit-20260719-115700` |
| Pushed manifest digest | `sha256:24425cc992a595812d1165cb7a3aa292c09a329bdeb34429a6bc0e12f778a217` |
| Temporary service | `replay-validator-audit-smoke` |
| Temporary revision | `replay-validator-audit-smoke-00001-f2x` |
| Temporary service disposition | Deleted after smoke; production traffic unchanged |

The pushed manifest digest exactly matched the scanned local image ID.

## Original finding reassessment

| Audit ID | Successor status | Evidence gained | Remaining closure gap |
|---|---|---|---|
| `RV-C01` | Implemented; verification pending | Expiring token-fenced leases, stale reclaim, stale-writer rejection, scheduled bounded repair, and focused tests are present. Live retry recovered a transient conflict. | Kill/timeout and queue-exhaustion drills in staging; repair-backlog evidence. |
| `RV-C02` | Implemented; verification pending | `internalErrorFirstAtMs` survives the production repository codec and grace-window tests. Aggregate inventory found no legacy sessions. | Deployed grace-window fault drill and legacy migration evidence if legacy data appears. |
| `RV-C03` | Implemented; verification pending | Compressed/expanded bytes, JSON depth, frame/tick/duration, and simulation wall-time are bounded. Cloud Run has explicit CPU, memory, timeout, concurrency, and scale limits. | Deployed adversarial resource/load test and resource alerts. |
| `RV-H01` | Implemented; verification pending | Cloud Tasks policies and scheduled lost-task repair exist; production queues match checked-in policy. A live 500 retried and later completed. | Deliberate retry exhaustion and repair recovery in staging. |
| `RV-H02` | Implemented; verification pending | Storage generation and digest flow through finalization, exact-generation validation reads, projection, and generation-pinned copy/manifest paths. | Deployed overwrite/collision test and Storage integration coverage. |
| `RV-H03` | Implemented; verification pending | Duplicate projection resumes incomplete materialized-view work; regression tests pass. | Deployed partial-step failure injection. |
| `RV-H04` | Implemented; verification pending | Conditional player-best writes and version-preconditioned top-10 writes are reconciled independently. | Emulator/deployed concurrency load across a board. |
| `RV-H05` | Implemented; verification pending | Projection stubs fail closed; readiness fails without required configuration. Exact-image isolated deployment passed authenticated readiness. | Controlled production rollout of `/live` and `/ready`; misconfiguration drill. |
| `RV-H06` | Implemented; verification pending | Explicit decoder rejection covers versions, command bits, axes, relationships, and bounds. AOT rejection probe passes. | Same probe must run in committed CI and against the release artifact. |
| `RV-H07` | Implemented; verification pending | Ticket/session identity, canonical loadout digest, compatibility allowlists, and immutable ranked-board windows are enforced and tested. | Compatibility retirement policy and deployed fixture matrix. |
| `RV-H08` | Implemented; verification pending | Accepted, rejected, and exhausted internal-error handoffs use preconditioned atomic Firestore commits. Functions emulator suite passes. | Deployed fault injection and any legacy partial-state repair evidence. |
| `RV-H09` | Implemented; verification pending | Reconciliation handles empty boards and paginates active/demoted manifests; independent scheduling is deployed. | Deployed lifecycle drill with more than 100 manifests and interruption points. |
| `RV-M01` | In progress | Service coverage increased to 972/1,592 executable lines (61.1%) and production-shaped adapter tests were added. | A risk-based adapter/failure matrix and real Firestore/Storage integration remain incomplete. |
| `RV-M02` | Implemented; verification pending | Shared `canonicalRunDurationSeconds` is used and boundary tests pass across affected layers. | Repository-wide Flutter gate still has three unrelated asset-generation failures. |
| `RV-M03` | In progress | Separate fail-closed probes, stable public errors, and structured dispatch categories exist. | Only settlement alerts/metrics are deployed; validation lease/retry/resource, projection, ghost, and readiness alerts are absent. |
| `RV-L01` | Implemented; verification pending | Digest-pinned distroless runtime, UID/GID 65532, bounded contexts, local image scan, and a source CI gate exist. | Workflow is uncommitted and has not run in GitHub; production does not yet use this exact successor artifact. |
| `RV-L02` | Implemented; verification pending | Commands, service policy script, region, routes, and implementation docs are corrected in the working tree. | Production still uses the retired `z`-suffixed probe routes pending controlled rollout. |
| `RV-L03` | Implemented; verification pending | Direct Google API packages are current and production dependency audit is clean. | Authenticated release-artifact workflow smoke must run from committed CI. |

## New findings

### RV2-M01 — Release artifact provenance and CI enforcement are not active

**Severity:** Medium

The working tree contains a dedicated replay-validator GitHub Actions workflow
that analyzes and tests the service, runs the AOT protocol probe, builds and
smokes the final image as UID/GID 65532, and fails on Critical/High Trivy
findings. `actionlint` accepts the workflow.

The workflow and remediation are uncommitted, so no GitHub run can bind the
source revision, tests, scan result, and deployed digest. The current production
image was built by Cloud Build, but this audit cannot map it to a committed
remediation source snapshot. Local and isolated deployment evidence is useful
but is not a reviewable supply-chain gate.

**Impact**

A future deployment could bypass or differ from the locally validated source
without a failed required check. Finding closure would then depend on manual
operator evidence.

**Required remediation**

- commit the remediation and workflow intentionally;
- run the workflow on the exact review commit;
- publish/deploy only an image tied to that successful workflow or an
  equivalently attestable build;
- make the replay-validator check required for affected pull requests.

### RV2-M02 — Production Firestore precondition conflicts bypass the conflict classifier

**Severity:** Medium

`isApiConflict` accepts only HTTP 409 and 412. Unit tests model Firestore
precondition failure as 412. During this audit, the production Firestore REST
`currentDocument.updateTime` path returned a `DetailedApiRequestError` with HTTP
400 and the safe diagnostic that the stored version did not match the required
base version.

The error escaped the task handler as HTTP 500. Cloud Tasks retried 30 seconds
later; the next validation delivery returned 202, a later validation returned
200, and projection returned 200. The precondition prevented a lost update and
the durable retry path recovered, so no inconsistent write was observed.

**Impact**

Ordinary contention consumes an avoidable task attempt, emits an unclassified
handler failure, and bypasses the intended stale-lease/conflict metric path.
Repeated contention could increase retry pressure and obscure the operational
cause of failures.

**Required remediation**

- classify the actual structured Firestore `FAILED_PRECONDITION` response used
  by both patch and commit operations, without treating arbitrary HTTP 400
  input errors as concurrency conflicts;
- add fixtures matching the production response for lease acquisition and
  every atomic handoff;
- assert the intended retry/stale-lease result and structured metric;
- repeat the contention drill in staging.

### RV2-L01 — Current production probe paths collide with Cloud Run reserved routing

**Severity:** Low

Current production uses `/readyz` and `/healthz`. Internal Cloud Run startup and
liveness probes succeed, but an authenticated external `/healthz` request
returns the platform's 404. Cloud Run documents reserved paths and recommends
avoiding paths ending in `z`.

The working tree replaces these endpoints with `/ready` and `/live`, removes
legacy aliases, and updates service docs, tests, policy script, and CI. The exact
successor image returned 200 for both new endpoints in the isolated private
deployment, while the retired endpoints returned 404 locally.

**Impact**

The current liveness configuration works inside Cloud Run, but operators cannot
reliably smoke the same path externally and the route is exposed to platform
behavior.

**Required remediation**

Roll out the tested `/ready` and `/live` configuration through the normal
controlled deployment process. See the
[Cloud Run known issues](https://docs.cloud.google.com/run/docs/known-issues).

## Validation matrix

| Check | Result | Evidence |
|---|---|---|
| Replay validator analysis | Pass | No issues |
| Replay validator tests | Pass | 65/65 |
| Replay validator coverage | Pass with assurance gap | 972/1,592 executable lines, 61.1% |
| Server AOT compile | Pass | Native executable compiled |
| Protocol AOT rejection probe | Pass | Native probe exited 0 |
| Shared protocol analysis/tests | Pass | No issues; 35/35 |
| Deterministic Core analysis/tests | Pass | No issues; 5/5 |
| Functions build | Pass | TypeScript build completed |
| Functions emulator tests | Pass | 167/167 |
| Functions production dependency audit | Pass | No known vulnerabilities |
| Root Dart analysis | Pass | No issues |
| Focused canonical-gold UI tests | Pass | 18/18 |
| Full Flutter suite | Partial | 751 passed; 3 unrelated asset-generation/parallax tests failed |
| PowerShell deployment policy parse | Pass | Parser reported no errors |
| GitHub workflow lint | Pass locally | `actionlint` accepted the workflow |
| Final image runtime | Pass | 12,100,223 bytes; PID 1 and configured user are UID/GID 65532 |
| Final image vulnerability gate | Pass | Trivy 0.72: 0 Critical, 0 High; residual 4 Medium and 9 Low with no fix listed |
| Exact-image isolated Cloud Run smoke | Pass | Private authenticated `/live` 200, `/ready` 200, malformed task routes 400, unauthenticated request 403 |
| Baseline audit immutability | Pass | Git blob hash remained `4b075d4b1b571d3c947d79f9b0bbb22c519aca20` |

The three full-suite failures are:

- authored field-level assembly was not generated;
- static prefab sprite snapshots were empty;
- generated forest parallax data contained four layers while the test expected
  five.

They are outside the replay-validator and settlement/projection slice, but
remain a repository-wide green-build gap.

## Live environment review

### Cloud Run

Production remained on `replay-validator-00021-lqc` throughout the isolated
smoke. Its image resolves to digest
`sha256:2702ae532949d041d3cf4b6351cd0378abce7c9ebd9b4939e721d98fd2a27240`.
The service uses the validator service account, region `europe-west1`, 1 CPU,
512 MiB memory, 240-second timeout, concurrency 1, maximum scale 10, startup
`/readyz`, and liveness `/healthz`.

The isolated exact-image service used the same service identity and core
resource settings, with maximum scale 1 and the corrected `/ready` and `/live`
probes. It was deleted after successful smoke.

### Cloud Tasks and invocation

Both `replay-validation` and `replay-projection` are running in
`europe-west1`, target the private production service, and use
`sa-replay-task-dispatch` with the production service URL as OIDC audience.
Validation has 8 attempts and a one-day retry duration; projection has 100
attempts and a seven-day retry duration. Both are rate-limited to 5 dispatches
per second and 5 concurrent dispatches. Both queues were empty at the final
inventory.

The auditing user cannot mint a token as the task or validator service account,
so an independent synthetic request with the exact runtime identities was not
possible. Queue configuration, Cloud Run invoker policy, and observed real task
traffic support the binding, but the staging OIDC drill remains open.

### IAM and Storage

- Only `sa-replay-task-dispatch` has `run.invoker` on the validator service.
- Settlement/projection function invoker bindings use the validator and
  run-control identities as intended.
- The validator has project-level `datastore.user`.
- The replay bucket grants the validator object admin/viewer access needed by
  validation and ghost publication; run-control has object admin/user/viewer.
- Task dispatch has only service-account delegation from run-control and no
  project-wide data role.

The bucket roles contain redundant grants and are broader than path-scoped
least privilege, so IAM should be simplified when separate source/ghost buckets
or managed conditions make that practical. No direct public replay-service
principal was found.

### Firestore, Functions, and persisted state

Required composite indexes were `READY`. Validation repair, settlement repair,
settlement dispatch, projection, and reconciliation Functions were active, and
their Scheduler jobs were enabled.

At `2026-07-19T12:13:42.8610319Z`, read-only aggregate inventory found zero
documents in run sessions, reward grants, validated runs, leaderboard boards,
player bests, and ghost manifests. Consequently every queried stale-lease,
pending-retry, internal-error, terminal/reward mismatch, projection drift, and
ghost-drift count was zero. There was no production repair backlog to mutate,
but the empty snapshot cannot prove repair behavior.

### Monitoring and logs

Four enabled alert policies and three log metrics cover reward settlement:

- immediate settlement fallback above 5%;
- payout latency p99 above 15 seconds;
- reward pending over 15 minutes;
- settlement invariant violation.

No enabled alert/metric evidence was found for stale validation leases,
orphaned validation, retry exhaustion, validation resource limits, projection
drift/lag, ghost lifecycle, or readiness. `RV-M03` therefore remains open.

A 500-entry production log sample contained one request-level 500 for the
current revision, followed by the successful retry sequence described in
`RV2-M02`. The detailed exception remained in restricted server logs and no
raw exception was observed in player-visible state.

## Open release gates

1. Commit and review the remediation, run the source CI gate, and bind the
   deployed artifact to that successful source revision.
2. Correct `RV2-M02` and verify actual Firestore conflict behavior.
3. Provide a non-production staging environment for crash/timeout, retry
   exhaustion, decompression/resource, overwrite, partial-write, concurrency,
   and more-than-100-ghost drills.
4. Deploy and exercise validation, projection, ghost, and readiness monitoring
   plus runbook actions.
5. Perform controlled production rollout of the exact tested artifact and
   corrected health paths.
6. Repeat aggregate inventory and canary observation after rollout.
7. Reassess every original Critical/High row against the staging and production
   evidence before changing it to `Closed`.

## Verdict

The remediation is materially stronger and the original source-level release
defects appear implemented. It is not yet a production-closure package. The
remaining assurance gates and the newly observed production conflict-classifier
gap justify retaining the release block.
