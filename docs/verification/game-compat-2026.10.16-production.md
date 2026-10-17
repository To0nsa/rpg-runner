# Game compatibility 2026.10.16 production release

Deployed October 17, 2026 UTC through the canonical coordinated workflow to
`rpg-runner-d7add` / `europe-west1`: Firebase Functions, Cloud Run replay
validation, and [web Hosting](https://rpg-runner-d7add.web.app). Normal ticket
issuance and both queues are restored.

## Frozen source and preparation

The release source is commit `709c9d42` (digest
`201846d42ab88a9e1472e432fc7e03da137bf0b5e67161fb5c5e2da4dabf19e7`).
It includes the authored Field and Forest content committed in `bef5150f`, a
shared gameplay compatibility version of `2026.10.16`, refreshed ranked route
seeds, and matching client/validator fixtures. Rules, score, ghost and replay
formats remain `rules-v2`, `score-v4`, `ghost-v1` and format 1.

The canonical `Prepare` recipe passed at 22:58:33 UTC in the frozen checkout.
It verified Functions tests and build, 1,474 Flutter tests and the production
web build, 2,241 Core tests, protocol/content/terrain package checks, validator
checks and AOT probe, the production dependency audit, and generated-content
freshness. Verified cache entries were reused only for unchanged component
inputs. The source generator validated 86 chunk JSON files, three level
definitions, three parallax themes and three terrain material definitions.

## Pre-cutover production state

Read-only inspection at 22:59:22 UTC found 411 run sessions: 307 validated,
59 expired, 30 cancelled and 15 issued tickets on `2026.10.12`. All 318
accepted validation documents had settled reward grants. There was no stale
pending or quarantined settlement. The 15 issued tickets had no upload lease or
replay object in a separate review; their earliest expiry was
2026-10-17 04:46:39 UTC. Existing current/next `2026.10.12` boards were present.

## Image and cutover

Cloud Build `017dd2a8-c129-4e3b-be56-d4b78db81b67` ran from 23:00:32 to
23:55:07 UTC. It compiled all 38 prepared routes (93,050 navigation graphs),
passed the strict final-image benchmark, and produced immutable worker image
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:9a93e44516f527f2cb85bdf73a2bbf66912c233f867ffaeb9357155271460c64`.

The previous issuer image had been removed by managed cleanup. `PauseIssuance`
used the workflow's prepared-issuer rebuild with the explicit pause gate and
verified the healthy serving revision at 00:01:09 UTC. Both queues stayed
running during the drain review.

The paused-state inspection at 00:01:44 UTC still showed 15 issued
`2026.10.12` tickets, zero pending/quarantined settlement and 318 accepted
validations with 318 settled grants. A guarded transaction rechecked the exact
ticket set (`sha256:eace7889b7c247ca8c0f4a64eea503025f3d703b087d4a24b6aea1b41b5019f8`),
healthy paused issuer, unchanged issued state, absent upload/validation leases,
absent replay objects, and absent validation/reward documents. Under the
owner's authorization, it changed only those 15 unsubmitted session records
to `cancelled` at 00:02:44 UTC. It did not write profiles, rewards or
validated-run documents. The next inspection found zero active sessions and
the same 318 accepted validations and settled grants. No data reset occurred.

Functions (excluding the pause-gated issuer), Firestore rules and indexes
completed at 00:07:14 UTC. Cloud Run revision `replay-validator-00055-795`
was deployed at 00:10:10 UTC. Hosting was published at 00:10:48 UTC. All six
expected current/next boards were ready before `ResumeIssuance` restored both
queues and deployed the final issuer at 00:15:01 UTC.

Final live inspection at 00:15:47 UTC found all 26 Functions ACTIVE, both
queues RUNNING, all six expected boards present, zero active runs and no stale
pending or quarantined settlement. The 411 session records comprise 307
validated, 59 expired and 45 cancelled. All 318 accepted validations and 318
settled grants remain intact. Worker revision `replay-validator-00055-795`
serves 100% of traffic with the exact image digest above. Healthy issuer
revision `runsessioncreate-00062-wbd` serves 100% of traffic without the
temporary pause override. The live `main.dart.js` SHA-256 matches the
prepared artifact:
`b1aa3bda00acca28daa39e8e7007aed7c5d6badc8bf6e97115664937a4471b80`.

Evidence is under the frozen checkout's
`.tmp/releases/rpg-runner-d7add/201846d42ab88a9e1472e432fc7e03da137bf0b5e67161fb5c5e2da4dabf19e7/`:
component/freshness logs, Cloud Build result, exact-image benchmark, paused
ticket review and cancellation receipt, drained/deployed/final inventories,
live web bytes, and final worker and issuer checks. The verified production
baseline is in the shared release cache.

## Coverage limits

The owner requested removing traversal assertions tied to the authored Field
and Forest gaps, as well as obsolete streaming and terrain-order tests, rather
than changing authored chunks to satisfy those tests. The remaining traversal
matrix passed in Core, but it does not establish that every Field enemy can
cross the excluded gap or that the removed rendering and culling scenarios
still hold. Controlled signed-in Play Games issuance, replay acceptance,
once-only settlement, wallet catch-up, leaderboard/ghost playback, live
retired-version rejection and target-device performance remain unverified. No
controlled accepted replay was produced after cutover and no native package
was built or installed. The
[release checklist](../building/rescue_release_operations.md) retains these
live acceptance checks.
