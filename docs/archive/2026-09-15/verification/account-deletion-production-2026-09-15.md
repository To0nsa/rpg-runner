# Account Deletion Production Deployment and Verification — September 15, 2026

## Scope and source

The repository owner authorized production deployment and verification in
`rpg-runner-d7add`. Release code came from committed snapshot `3652e0003b697564e75ae8d96e742ef5f27c9583`;
uncommitted level-authoring assets were excluded. The monitoring attempt budget
was subsequently adjusted in `c690e40b` using observed production traversal.

This pass deployed the account-delete callable, account-deletion repair worker,
Firestore indexes, replay validator, and Flutter web Hosting release. Native
store distribution and a native Play Games/device-cleanup canary were not part
of this pass.

## Deployed resources

| Resource | Verified revision or value |
| --- | --- |
| `accountDelete` | `accountdelete-00018-puw`, ACTIVE, Node 24 |
| `accountDeletionRepair` | `accountdeletionrepair-00010-poz`, ACTIVE, Node 24 |
| Repair scheduler | every minute, `Etc/UTC`, enabled after index readiness |
| Validator | `replay-validator-00037-dtg`, 100% traffic |
| Immutable image | `sha256:92d0e20548f8f03f9bb3024001de9535830cd1afae016441ad0044f8e5c64cad` |
| Cloud Build | `09ae9dcd-d42d-41d3-aa09-fb7e5e46d564`, SUCCESS |
| Cloud Run limits | 1 CPU, 512 MiB, concurrency 1, 240-second timeout, 10 instances maximum |
| Validation lease | 600,000 ms |
| Active-request index | `state` + `requestedAtMs`, READY |
| Completed-expiry index | `state` + `expiresAtMs`, READY |
| Hosting | `https://rpg-runner-d7add.web.app`, HTTP 200 |
| Live/local `main.dart.js` SHA-256 | `9618a4a1d8641792e0f32a553524fc04d41d78c6616e494f5bf9516152e5ab62` |

Authenticated `/ready` and `/live` returned 200. The accepted validator digest
was tagged `production`; the checked-in queue and cloud-artifact retention
policies were applied. The validator service account now has
`roles/storage.objectUser` conditional on the
`replay-submissions/validated/` object prefix, enabling compensation deletion.

## Deployment observations and corrections

The first Functions attempt stopped at the CLI's ten-second source-discovery
timeout before updating functions. Retrying with
`FUNCTIONS_DISCOVERY_TIMEOUT=120` completed successfully.

A combined Functions/index deployment returned before index backfill finished.
The new repair revision logged two index-building failures at 16:57 and 16:58
UTC. Repair was briefly paused, then resumed after the expiry index became
READY. Successful zero-work heartbeats appeared at 16:58:56 and 16:59:05 UTC.
Future deployments must deploy indexes separately and wait for READY before
updating dependent Functions.

The production baseline contained 56 boards. Three private board fixtures were
added during erasure, forcing an extra ordinary reconciliation pass. The
healthy canary reached 432 successful stages before its final pass, exceeding
the former 400-attempt alert. The source-controlled and deployed attempt budget
is now 720, matching twelve hours of one-minute ticks and accommodating ordinary
retained-board traversal. The twelve-hour age alert remains in place. These
values are operator budgets, not a production completion SLA.

## Controlled verification

The acceptance canary used UID hash `5033e1abd84a9212`. Firebase Auth issued its
ID token after an administrator linked a unique synthetic Play Games provider
identity through the [Identity Platform administrative account-update API](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/update).
This fixture exercises token/identity gating; it does not establish native SDK
sign-in correctness.

Verified before the final pass:

- unauthenticated and unlinked requests reject without creating a tombstone;
- a UID mismatch rejects;
- actual profile/ownership/run callables create the disposable account state;
- a signed practice replay validates through the new deployed worker;
- `accountDelete` returns an explicit accepted status and matching UID receipt;
- the tombstone blocks the previously issued ID token's profile access;
- queued synthetic validator work is acknowledged as deletion-owned;
- a live leased run is preserved, and a late uncommitted archive is seeded for
  normal erasure recovery after lease expiry;
- private orphaned and owned leaderboard views are removed, while an unrelated
  private view retains the same content hash.

The synthetic leased-run fixture used a 90-second expiry to exercise the
unexpired/expired boundary. The deployment's actual lease policy remains ten
minutes. The signed-upload quiet period and final stage sequence were not
shortened.

The final inventory passed at 2026-09-15T17:22:52.790Z; absence of all three
disposable Auth users was rechecked at 17:23:01 UTC:

- the acceptance canary completed four passes in 16.47 minutes, including
  the full fifteen-minute quiet period and final zero-change pass;
- its three run-session fixtures, validated/reward evidence, profile, name claim,
  ownership, and live replay objects were absent, including the late archive;
- all three disposable Auth users were absent (including the setup canaries);
- the recovered setup account also reached complete through the normal worker;
- both completed checkpoints contain exactly four fields and a thirty-day expiry;
- active/retryable backlog, malformed completion evidence, and expired evidence
  were all zero;
- private board fixtures were removed and all baseline collection counts matched;
- the enabled one-minute scheduler reported success and a zero-work heartbeat;
- no ERROR entry was found on the new validator revision during verification.

The main canary loop issued 607 ordinary bounded repair invocations;
scheduled/probe invocations also occurred. The last
observed pre-completion attempt count was 623. This accelerated measurement does
not predict the duration of a full account processed only once per minute.

| Primary collection | Before / after count |
| --- | --- |
| Profiles / name claims / ownership | 1 / 1 each |
| Boards | 56 / 56 |
| Run sessions | 50 / 50 |
| Validated runs / reward grants | 33 / 33 each |
| Completed deletion checkpoints | 0 / 2 |

Live-record absence is the verified erasure scope. The unversioned replay bucket
has a seven-day soft-delete recovery policy, so deleted replay/ghost objects
remain recoverable by the provider during that window. Firestore point-in-time
recovery was disabled and no backup schedules were configured. Provider
recovery copies and audit-log retention are not purged by this worker and were
not represented as immediately physically erased.

## Storage generation and completed-expiry checks

The actual validator archiver was executed against disposable production
Storage objects using the authenticated deployment user. Copy succeeded,
compensation preserved a replacement generation, exact-generation deletion
succeeded, and repeating discard on a missing object succeeded. Test objects
were removed. Runtime IAM was verified separately; service-account impersonation
was unavailable (403), and no impersonation permission was added.

Eleven compact completed-record fixtures with artificial historical timestamps
and no Auth users/gameplay records exercised production expiry. Repair logged
ten deletes with `expiredCompletionPageSaturated: true` at 17:09:50 UTC, then
one delete with saturation false at 17:09:55 UTC. All eleven fixtures were
removed. This tests expiry evaluation and bounded draining, not thirty days of
elapsed production retention or a strict physical-removal deadline.

## Monitoring and limits

All four source-controlled account-deletion policies were applied to the enabled,
API-VERIFIED production email channel. The deployed attempt filter was checked
as `maxAttemptCount >= 720`, alongside the twelve-hour age condition. Runtime,
retryable-failure, and expired-backlog policies remain enabled. Fresh email
receipt was not confirmed in this pass; earlier recipient confirmation remains
historical evidence.

The web bundle was built with the existing production App Check site key, and
its live JavaScript hash matches the release build. Browser automation was not
available, so a rendered web interaction was not verified. Native device
cleanup, fresh native authentication, scheduler-outage recovery, and every
crash boundary remain bounded by the local/emulator tests rather than a
production fault-injection campaign.

Local checks from the implementation pass: 208 backend tests, 126 validator
tests, and 101 relevant Flutter tests passed; validator analysis and executable
compilation passed. Root analysis reported one existing unused import in an
untouched playtest file.

## Recovery and evidence handling

One pre-data canary (`7ddac42711dff734`) encountered a quota-project header setup
error and was erased directly from Auth with absence verified. A second setup
canary (`9c77630cd8a34f39`) created a profile before encountering an incorrect
harness callable name. Its initial deletion checkpoint was seeded with an
exists-false precondition; the normal production worker owns its complete
stage sequence. It is not counted as callable-acceptance evidence.

Exact disposable identifiers and recovery files are retained only under ignored
`.tmp/`. Final records contain aggregates and short UID hashes. Authentication
tokens are not included in this record.
