# Replay Validator Closure Audit — July 21, 2026

Date: July 21, 2026
Scope: `services/replay_validator` and its replay-validation, settlement,
projection, ghost, queue, monitoring, and cleanup integrations
Decision: No remaining release-blocking replay-validator finding

## Evidence policy

This is a new immutable audit. It does not replace or amend:

- `replay-validator-full-audit-2026-07-18.md`, Git blob
  `4b075d4b1b571d3c947d79f9b0bbb22c519aca20`;
- `replay-validator-successor-audit-2026-07-19.md`, Git blob
  `f966a89f8b60c3b7c60dcfa1482d8e5ddbf6534b`.

Active implementation detail and commands are recorded separately in
`docs/building/replayValidation/release-closure-verification-2026-07-21.md`.

## Executive conclusion

Every Critical and High finding from the July 18 audit is closed. Every Medium
and Low finding from that audit and every successor finding from July 19 is
also closed.

The final verification found one additional High resource defect: buffering a
near-limit expanded replay with a growable integer list could exceed the
deployed 512 MiB container. The implementation was corrected, rebuilt from a
clean commit, scanned, repeated at the deployed resource limit, and deployed.
The corrected case completed with the stable expanded-size rejection, the
container remained healthy, and no memory-limit event recurred.

Production now serves revision `replay-validator-00025-wfv` at 100% on manifest
digest
`sha256:92adcfe4bfc57647b0be5c11105aee9f466f555e786b51084f0a00fd5351fa22`.
Both task queues were empty at final observation, all temporary services and
the temporary service identity were removed, and both disposable accounts had
zero exact residual data.

## Method

The closure audit combined:

- source and test review at clean commit
  `0861f98baa25affc5356accbcfb383ff9c2b7649`;
- published workflow evidence at containing commit
  `9eea5cfd6b3a5b7ce2e90b928215446ae90c1b85`;
- replay-validator analysis, 75-test suite, and AOT compilation;
- shared-protocol, deterministic-Core, Functions, and root-package checks;
- an exact container build, non-root smoke, and High/Critical package scan;
- real Firestore adapter atomicity coverage;
- deployed resource, compatibility, grace-lifecycle, and board-projection
  verification;
- production revision, queue, probe, log, metric, inventory, and cleanup
  observation;
- byte-for-byte Git blob checks of both earlier audits.

## New finding

### RV3-H01 — Expanded replay buffering exceeded the deployed memory budget

Severity: High
Status: Closed

The deployed 32 MiB expanded-size case completed its rejection but the process
later exceeded the 512 MiB Cloud Run limit because `collectReplayBytes` used a
growable `List<int>` and repeated `addAll`. The next request observed the
container restart.

Commit `0861f98b` uses `BytesBuilder(copy: false)`, tracks observed bytes
without relying on allocated capacity, and returns a compact `Uint8List`.
Regression evidence includes the replay-loader type assertion, 75 passing
service tests, AOT compilation, a clean image build, zero High/Critical package
findings, all five deployed resource-limit cases, the 1 ms simulation deadline
case, no new memory-limit log, and healthy production probes.

## Original finding disposition

| ID | Final status | Closure evidence |
|---|---|---|
| `RV-C01` | Closed | Expiring fenced leases, duplicate delivery, task exhaustion, and scheduled repair converged in production verification. |
| `RV-C02` | Closed | Attempts 1–8 preserved pending state and one immutable grace start; attempt 9 after restart terminalized `internal_error` and revoked the grant. |
| `RV-C03` | Closed | Five deployed resource boundaries plus the simulation deadline passed at 1 CPU/512 MiB after `RV3-H01` was corrected. |
| `RV-H01` | Closed | Cloud Tasks remains the ordinary retry owner and the scheduled repair recovered exhausted work. |
| `RV-H02` | Closed | Validation, retained replay lineage, projection, and ghost promotion use the exact finalized generation and digest. |
| `RV-H03` | Closed | Duplicate and partial projection state converged through run and board reconciliation. |
| `RV-H04` | Closed | 250-player, 273-run, 321-delivery load preserved one best per player and the exact top 10 across three pages. |
| `RV-H05` | Closed | Missing configuration fails readiness; `/ready` and `/live` are healthy on revision `00025`. |
| `RV-H06` | Closed | Production/AOT decoders explicitly reject unsupported versions, bits, masks, axes, and ranges. |
| `RV-H07` | Closed | The nine-case deployed compatibility/identity/loadout/board matrix produced only the expected accepted or stable rejected outcomes. |
| `RV-H08` | Closed | The 23-case real Firestore matrix covered accepted, rejected, and internal-error commits, conflicts, response loss, connection loss, stale tokens, and lease expiry with zero residue. |
| `RV-H09` | Closed | Empty and paginated reconciliation, 105-manifest cleanup, scheduled maintenance, and the final board-wide run converged. |
| `RV-M01` | Closed | Direct Firestore/Storage adapters, the 23-case atomic matrix, live generation checks, and deployed load supply risk-based integration coverage. |
| `RV-M02` | Closed | Canonical duration conversion is shared and its protocol/UI/validator checks pass; the unrelated Windows CRLF golden does not exercise this contract. |
| `RV-M03` | Closed | Fail-closed readiness, structured stable outcomes, deployed metrics/policies, verified notification delivery, and live queue/probe observation are present. |
| `RV-L01` | Closed | Digest-pinned distroless image runs as `65532:65532`, uses a bounded context, and has zero High/Critical package findings. |
| `RV-L02` | Closed | Commands, URLs, probes, queue policy, region, and deployed service configuration are current. |
| `RV-L03` | Closed | Reviewed Google client versions, adapter checks, published workflows, exact build, and production verification pass. |

## Successor finding disposition

| ID | Final status | Closure evidence |
|---|---|---|
| `RV2-M01` | Closed | Published Functions run 5 and Replay Validator run 4 succeeded at `9eea5cfd`; the release image is traceable to clean fix commit `0861f98b`. |
| `RV2-M02` | Closed | Exact Firestore precondition classification, live contention, and the 23-case atomic matrix return bounded retry behavior rather than an unclassified handler failure. |
| `RV2-L01` | Closed | Production uses `/ready` and `/live`; both returned healthy responses on revision `00025`. |

## Production and data evidence

- Production revision: `replay-validator-00025-wfv`, 100% traffic.
- Resources: 1 CPU, 512 MiB, 240-second timeout, concurrency 1, maximum 10.
- Validation and projection queues: running and zero tasks after deployment.
- Three pre-existing monthly-board reconciliation retries completed after the
  verified image was deployed.
- Temporary Cloud Run services with the `rv-audit-` prefix: zero.
- Temporary service role binding and service identity: removed.
- Board-load cleanup: 525 scoped documents removed; residual count zero.
- Disposable account hashes `6ba37a21b05b1702` and `a71d88ce511614dd`:
  deletion state complete and exact residual count zero.
- Final inventory: one non-synthetic profile/ownership pair remained
  untouched; no active deletion, stale settlement, terminal/evidence,
  identity, grant, or projection-source discrepancy was reported.

## Validation evidence

| Check | Result |
|---|---|
| Replay validator analysis | Pass |
| Replay validator tests | 75/75 pass in working and detached clean checkouts |
| AOT server compilation | Pass |
| Shared protocol analysis/tests | Pass |
| Deterministic Core analysis/tests | Pass, 39/39 |
| Functions locked install/build/tests | Pass |
| Root `flutter analyze lib test` | Pass |
| Root broad test run | 480 pass before one Windows CRLF/LF generated-file comparison; unrelated to validator behavior |
| GitHub Functions run 5 | Success |
| GitHub Replay Validator run 4 | Success |
| Local container smoke | Non-root; `/live` 200, unconfigured `/ready` 503 |
| Trivy 0.67.2 High/Critical scan | Zero findings |
| Compatibility | 9/9 expected outcomes |
| Resource boundaries | 5/5 expected outcomes |
| Simulation deadline | Expected stable terminal result |
| Grace lifecycle | 9/9 attempt sequence and terminal state |
| Atomic handoff matrix | 23/23, zero residue |
| Board-wide projection | 250 bests, exact top 10, zero residue |

## Limitations

The root Windows checkout converts tracked generated files to CRLF while the
generator returns LF. One broad Flutter golden comparison therefore stops the
Windows run after 480 passes. The root scoped analyzer passes, the involved
Core package suite passes, and the Linux replay-validator and Functions
workflows pass. This environment-only comparison is not a replay-validator
release blocker and no unrelated generated file was changed to suppress it.

## Final decision

No Critical or High replay-validator finding remains open, no Medium or Low
row remains unresolved, and the production/data cleanup gates are satisfied.
The replay-validator-specific release block established by the July 18 audit
is removed.

Future changes to validator input buffering, compatibility allowlists,
terminal handoffs, projection ordering, resource policy, or queue ownership
must start a new dated building plan and, when audited, a new dated audit. This
document must not be edited to record later work.
