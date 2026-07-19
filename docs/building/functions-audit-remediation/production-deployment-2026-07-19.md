# Functions Audit Remediation Production Deployment — July 19, 2026

## Authorization and scope

The repository owner authorized direct deployment to
`rpg-runner-d7add` because there is no staging project and the game is not
live. Production was treated as an empty-user canary.

Deployment scope:

- Firestore Security Rules and composite indexes;
- the complete Firebase Functions codebase;
- the replay-validator Cloud Run service;
- replay-validation and replay-projection queue policy.

Firebase Hosting and native Flutter releases were not part of the initial
backend deployment. A follow-up App Check-capable web release was deployed
later the same day and is recorded below. Native releases were not deployed.
App Check remains in monitoring mode. Reviewed abuse quotas were subsequently
production-enforced as recorded below.

Post-deployment behavior, inventory, canary deletion, retention migration, and
monitoring evidence are recorded separately in the
[production verification record](production-verification-2026-07-19.md).

## Pre-deployment validation

- Functions TypeScript build: passed.
- Functions emulator suite: 167/167 passed.
- Production dependency audit: no known vulnerabilities.
- Repository Dart analysis: no issues.
- Flutter state suite: 118/118 passed.
- Shared protocol: analysis passed; 35/35 tests passed.
- Replay validator: analysis passed; 65/65 tests passed.
- Replay validator deployment executable compilation: passed.
- `git diff --check`: passed.

## Firestore deployment

Deployment began at approximately `2026-07-19T11:17:04Z`.

- Ruleset: `49614c26-f9f7-4bea-be06-8e9b0bb40800`.
- Rules release updated at `2026-07-19T11:17:12.378901Z`.
- Eight `run_sessions` composite indexes were created.
- All eight indexes reached `READY` before Functions deployment began.
- No native Firestore TTL policy was added. Quota and ownership-idempotency
  retention continue to use the source-controlled scheduled cleanup.

## Firebase Functions deployment

All 27 second-generation Functions are active in `europe-west1` on Node.js 24.
Every Function reports source hash:

`2115e29ed3b5871781e1fcc53f6d11305a8dc53f`

Deployed revisions:

| Function | Revision |
| --- | --- |
| `abuseQuotaRetentionCleanup` | `abusequotaretentioncleanup-00001-wuc` |
| `accountDelete` | `accountdelete-00007-zob` |
| `accountDeletionRepair` | `accountdeletionrepair-00001-piz` |
| `ghostLoadManifest` | `ghostloadmanifest-00007-lev` |
| `leaderboardBoardMaintenance` | `leaderboardboardmaintenance-00007-per` |
| `leaderboardLoadActiveBoardData` | `leaderboardloadactiveboarddata-00007-dif` |
| `leaderboardLoadBoard` | `leaderboardloadboard-00007-zac` |
| `leaderboardLoadMyRank` | `leaderboardloadmyrank-00007-ner` |
| `loadoutOwnershipExecuteCommand` | `loadoutownershipexecutecommand-00007-gac` |
| `loadoutOwnershipLoadCanonicalState` | `loadoutownershiploadcanonicalstate-00007-mev` |
| `ownershipIdempotencyRetentionCleanup` | `ownershipidempotencyretentioncleanup-00001-jem` |
| `playerProfileConsistencyRepair` | `playerprofileconsistencyrepair-00001-xer` |
| `playerProfileLoad` | `playerprofileload-00007-cuq` |
| `playerProfileUpdate` | `playerprofileupdate-00007-vos` |
| `runBoardsLoadActive` | `runboardsloadactive-00007-xef` |
| `runLegacyRewardGrantMigration` | `runlegacyrewardgrantmigration-00005-tuc` |
| `runProjectionOnAccepted` | `runprojectiononaccepted-00004-feg` |
| `runProjectionReconciliation` | `runprojectionreconciliation-00001-vad` |
| `runSessionCreate` | `runsessioncreate-00007-yux` |
| `runSessionCreateUploadGrant` | `runsessioncreateuploadgrant-00007-men` |
| `runSessionFinalizeUpload` | `runsessionfinalizeupload-00007-xeg` |
| `runSessionLoadStatus` | `runsessionloadstatus-00007-qox` |
| `runSettlementImmediate` | `runsettlementimmediate-00006-jez` |
| `runSettlementOnHandoff` | `runsettlementonhandoff-00006-tur` |
| `runSettlementRepair` | `runsettlementrepair-00006-vux` |
| `runSubmissionCleanup` | `runsubmissioncleanup-00007-rod` |
| `runValidationRepair` | `runvalidationrepair-00001-tav` |

Deployment configuration verification:

- `APP_CHECK_*` environment key count on `runSessionCreate`: zero;
- `ABUSE_*` environment key count on `runSessionCreate`: zero;
- source defaults therefore keep both controls in monitoring mode;
- quota limits remain unset;
- `runSettlementImmediate` has no public invoker and grants
  `roles/run.invoker` only to the replay-validator service account;
- all ten scheduler jobs are enabled except the intentionally paused
  `runLegacyRewardGrantMigration`.

The first `accountDeletionRepair` scheduler attempt received 403 during IAM
propagation at `2026-07-19T11:25:08Z`. The next attempt at
`2026-07-19T11:26:08Z` and every observed attempt through 11:32 returned 200.
Its scheduler OIDC identity matches the service's sole invoker binding.

## Replay-validator deployment

- Cloud Build:
  `bce6cbc9-ee1c-46e0-819c-02e7aa3ab290`.
- Image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator:audit-remediation-20260719-112556`.
- Image digest:
  `sha256:2702ae532949d041d3cf4b6351cd0378abce7c9ebd9b4939e721d98fd2a27240`.
- Cloud Run revision: `replay-validator-00021-lqc`.
- Traffic: 100%.
- Runtime identity: replay-validator service account.
- Concurrency: 1.
- Request timeout: 240 seconds.
- Startup `/readyz` and liveness `/healthz` probes: configured and passing.
- Authenticated `/readyz`: HTTP 200 with `status: ready`.
- Direct external authenticated `/healthz` returned a Google frontend 404, but
  the container's liveness probe and application request logs repeatedly show
  HTTP 200 for `/healthz`. The revision remains ready and healthy.

Queue policy after deployment:

| Queue | Rate | Concurrency | Attempts | Retry duration | Target |
| --- | ---: | ---: | ---: | --- | --- |
| `replay-validation` | 5/sec | 5 | 8 | 24 hours | `/tasks/validate` |
| `replay-projection` | 5/sec | 5 | 100 | 7 days | `/tasks/project` |

Both queues are running, use the task-dispatch service identity with OIDC, and
target the deployed validator URL.

### Follow-up conflict-classification revision

The authenticated canary exposed a structured Firestore
`FAILED_PRECONDITION` response that the validator initially allowed to escape
as HTTP 500 before Cloud Tasks recovered. The classifier was corrected and
redeployed later on July 19:

- Cloud Build:
  `cee682f7-57d0-4f72-b6e0-8be327d19b6e`;
- image digest:
  `sha256:b75a241d53eb8ff5936c815867f3497e539f6d9a178c63c293d10a130e48c70c`;
- Cloud Run revision: `replay-validator-00022-sb6`;
- traffic: 100%;
- startup probe: `/ready`, HTTP 200;
- liveness probe: `/live`, HTTP 200;
- retired `/readyz` and `/healthz`: HTTP 404;
- validator analysis passed, 73 tests passed, and the deployment executable
  compiled successfully.

The new classifier accepts HTTP 400 only when the structured Google error
status is exactly `FAILED_PRECONDITION`; arbitrary HTTP 400 errors remain
unclassified input failures. Lease and atomic-handoff conflicts now return
structured retry results for Cloud Tasks instead of an unclassified 500.

## Production smoke evidence

- `loadoutOwnershipLoadCanonicalState` without Firebase Auth: HTTP 401
  `UNAUTHENTICATED`.
- `runSessionCreate` without Firebase Auth: HTTP 401 `UNAUTHENTICATED`.
- Both smokes emitted `callable_app_check` with rollout mode `monitor` and
  token status `missing_or_invalid`.
- `runSettlementImmediate` without its authorized identity: HTTP 403.
- Validator `/readyz`: HTTP 200.
- Validator startup and liveness probes: HTTP 200.
- No Cloud Run error entries were observed after the completed rollout.
- The only scheduler error was the initial IAM-propagation 403 described
  above; subsequent attempts succeeded.

No synthetic authenticated account, run session, replay, reward, deletion, or
profile mutation was created during these smoke checks.

## Remaining verification

The production inventory, authenticated valid/invalid replay canary, controlled
account deletion, profile/index consistency check, idempotency migration, and
initial monitoring verification are now complete. During that work, a missing
collection-group index for ownership-idempotency expiry was found, added to
`firestore.indexes.json`, deployed, and verified `READY`.

Remaining work includes:

- native-platform App Check release measurements or explicit platform
  exclusions;
- the App Check enforcement readiness decision;
- publication of the reviewed compact deletion-retention disclosure and
  lawful-basis documentation;
- a longer observation window covering settlement latency, repair, deletion,
  idempotency, and resource cost;
- intentionally injected failure/quarantine coverage in an emulator or future
  isolated test project.

No audit finding is marked closed solely because this deployment succeeded.

## Follow-up Firebase Hosting App Check release

At `2026-07-19T15:08:10.236Z`, the App Check-capable Flutter web release was
deployed to the live Hosting channel:

- Hosting version:
  `projects/964001571974/sites/rpg-runner-d7add/versions/4a5f6b9928bdc2ea`;
- live release:
  `projects/964001571974/sites/rpg-runner-d7add/channels/live/releases/1784473690236000`;
- URL: `https://rpg-runner-d7add.web.app`;
- live/local `main.dart.js` SHA-256 match: yes;
- SHA-256:
  `6588584c24a96b1fda182c7fd74901926c33b7a704fe97172652bbdb8ba96b95`.

The release uses a domain-restricted reCAPTCHA Enterprise App Check provider.
The public site key was injected at build time and was not committed. App Check
remained in monitoring mode. Full configuration, validation, and attestation
evidence are in the
[App Check client rollout record](app-check-client-rollout-2026-07-19.md).

## Follow-up quota enforcement deployment

The nine quota-bearing callables were deployed once with reviewed
source-controlled limits in monitor mode, then redeployed after a complete
zero-would-reject canary with `ABUSE_CONTROL_MODE=enforce`.

Final Functions source/configuration hash:

`47bfddc5836917610b6d27ac2802dbbed8c42aa1`

Final revisions:

| Function | Revision |
| --- | --- |
| `loadoutOwnershipExecuteCommand` | `loadoutownershipexecutecommand-00009-qur` |
| `runBoardsLoadActive` | `runboardsloadactive-00009-vos` |
| `runSessionCreate` | `runsessioncreate-00009-woy` |
| `runSessionCreateUploadGrant` | `runsessioncreateuploadgrant-00009-tah` |
| `runSessionFinalizeUpload` | `runsessionfinalizeupload-00009-mit` |
| `leaderboardLoadBoard` | `leaderboardloadboard-00009-tiq` |
| `leaderboardLoadMyRank` | `leaderboardloadmyrank-00009-bet` |
| `leaderboardLoadActiveBoardData` | `leaderboardloadactiveboarddata-00009-vek` |
| `ghostLoadManifest` | `ghostloadmanifest-00009-hed` |

All nine are active with enforcement configured. App Check remains in monitor
mode. Limits, isolated validation, canary measurements, and rollback are in the
[quota rollout record](quota-selection-and-enforcement-2026-07-19.md).

## Follow-up alert-channel confirmation

The production email notification channel was verified and exercised with an
exact-match temporary log alert. Cloud Monitoring opened the expected incident,
the recipient confirmed receipt of the matching email, and the temporary policy
was deleted. The channel remains enabled and `VERIFIED`; all 14 real enabled
policies still reference it. Exact non-secret evidence is in the
[alert-channel confirmation record](alert-channel-confirmation-2026-07-19.md).

## Follow-up deletion-retention minimization

The account-deletion completion path was changed to replace active workflow
state with exactly four fields: terminal status, request time, completion time,
and expiry time. The 30-day maximum remains.

Deployment:

- Functions source/configuration hash:
  `a968167e5da186d99a87a2f77a640485787c7222`;
- `accountDelete`: `accountdelete-00008-bet`;
- `accountDeletionRepair`: `accountdeletionrepair-00002-yet`.

Two existing completed synthetic tombstones were compacted from 16 fields to
four. The post-migration inventory found two compact completions, zero
non-minimal completions, zero missing expiries, and zero expired completion
records. Active synthetic workflows were left to the normal repair scheduler.
The privacy assessment and launch conditions are in the
[deletion-retention review](deletion-retention-privacy-review-2026-07-19.md).

## Follow-up destructive fault drills

All 23 account-deletion stages were exercised with an isolated crash after the
stage's side effects and before checkpoint commit. The complete Functions suite
passed 171/171, and the related validator fault matrix passed 48/48. No
destructive production fault was injected.

The inert test seam and full-document terminal compaction were deployed so the
validated and live deletion source match:

- Functions source/configuration hash:
  `5bab5424c9d8aee530f9bddf4ef536dfdadaf26c`;
- `accountDelete`: `accountdelete-00010-ted`;
- `accountDeletionRepair`: `accountdeletionrepair-00004-wiy`.

Both functions were `ACTIVE`, and the one-minute repair scheduler remained
`ENABLED`. The final inventory at `2026-07-19T17:13:27Z` found nine compact
completions, zero active or retryable workflows, zero non-minimal completions,
zero missing expiries, and zero expired completion records. The complete matrix
is in the
[isolated fault-drill record](isolated-destructive-fault-drills-2026-07-19.md).
