# Production release: gameplay 2026.10.11.1

Deployed October 11, 2026 through `tools/release/release.ps1` to
`rpg-runner-d7add` / `europe-west1`: Firebase Functions, the replay worker and
[web Hosting](https://rpg-runner-d7add.web.app). The owner authorized deployment,
accepted the two traversal failures below, and authorized cancelling runs when
necessary. One unsubmitted old-version ticket was cancelled; its record was
retained. All 204 accepted runs and settled reward grants were preserved.

## Frozen source and preparation

Frozen commit: `6ac2a73a6b75c19d024392128645159833aace6e`.
Source digest: `9ec2be2a6fe89224fe8e387caf9443b98b2264aad43b916fb0a2519ba8765d54`.
Gameplay compatibility is `2026.10.11.1`, with `rules-v2`, `score-v4`,
`ghost-v1`, and replay/command formats 1.

Runtime source matches main commit `28a4a7f5`. The release includes prepared
navigation, curated Practice routes, app-owned reward completion and the current
Forest authoring. See [prepared navigation](../tdd/prepared_navigation.md) and
[reward settlement operations](../tdd/reward_settlement_operations.md).
The release repair keeps lifecycle recovery behind successful bootstrap, so
resuming a failed login cannot silently retry authentication. The foreground
reward test now uses a real clock for its real scheduler; explicit login Retry
and the existing failure assertions remain covered.

Canonical local preparation completed against the frozen source:

| Gate | Result |
| --- | --- |
| Client analysis/tests and release web build | 1,191 tests passed |
| Core analysis/tests | 2,187 passed; exactly two owner-accepted exclusions |
| Functions build/emulator tests | 215 passed |
| Validator analysis/tests and compiled AOT protocol-rejection probe | 262 passed; probe passed |
| Protocol analysis/tests | 44 passed |
| Content-pipeline analysis/tests | 98 passed |
| Terrain-material analysis/tests | 25 passed |
| Fresh production dependency audit | No known vulnerabilities |
| Generated-content freshness | 83 chunks, three levels, three parallax themes and three terrain materials |

The original commit's failed CI run `38163592199` was not imported as passing
release evidence. Preparation uses Flutter 3.47.1, Dart 3.13.1, Node 24.16.0 and
pnpm 11.22.0. The final client navigation pack contains 2,980 graphs and
17,912,751 bytes. Cloud Build generated 60,620 worker graphs across the declared
38 routes and 128-chunk horizon. These are artifact inventories, not exhaustive
player/combat traversal or cache-hit coverage claims; fallback remains enabled.

### Owner-accepted traversal exceptions

Only these exact test names were excluded in this detached release recipe:

- `forest traversal seed=2026 derf reaches every chunk exit`: Derf stalls at
  tick 9,400 in `forest_trainingcamp_hard_004` on the 76-chunk finite route.
- `hard ruin into grove gap preserves continuous grojib pursuit`: Grojib falls
  at tick 390 in `forest_rocky_grove_hard_002` on the four-chunk seed-42 fixture.

Both failures were independently reproduced with the pre-change navigation
implementation, as recorded in the [rollout investigation](../building/reward_verification_latency.md).
They remain unresolved, not passing tests. The detached commit records the
exception and changes the preparation recipe hash; its filtered Core evidence
cannot satisfy the normal unfiltered recipe. Main's normal release recipe and
the tests themselves are unchanged. Do not merge or reuse the release-only
exception as a standing waiver.

Remaining pursuit coverage includes finite Forest assemblies and 32-chunk
Field/new_level prefixes, seeds 7/42/2026 and the four mobile enemies. Arena
bosses, authored spawn/combat behavior, full player traversal, rendering and
endless continuation require separate acceptance.

## Immutable artifacts and cutover

Cloud Build `225c09a6-836f-4ce4-8a2c-30182e1a9ddf` succeeded. The exact final
image passed all nine strict 36,000-tick gates at one CPU / 512 MiB.
This no-ambient-enemy fixture is throughput/determinism evidence; its Forest
actor remains near the opening and it does not establish full-run combat or
end-to-end reward latency.

Worker image:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:91807268d71b4097361889521c995d24eab4ac971c2bc91ce572a8649cc4589e`.
Healthy revision `replay-validator-00053-lm4` serves 100% of traffic.

Live `main.dart.js` SHA-256:
`c65f1affcfe5b3f428aebcfd5fea1567fb480ca386fe25e885de847ea57bb431`.
Downloaded production bytes exactly match the prepared web build.
Healthy issuer revision `runsessioncreate-00056-5b4` serves 100% of traffic;
its serving revision has no `RUN_SUPPORTED_GAME_COMPAT_VERSIONS` override.

| Stage | October 11 UTC |
| --- | --- |
| Preparation complete | 19:16:19 |
| Image build started / succeeded | 19:16:53 / 19:47:43 |
| Issuance paused | 19:49:13 |
| Paused inventory | 19:50:21 |
| One old unsubmitted ticket cancelled | 19:50:42 |
| Drained inventory | 19:51:14 |
| Functions deployed | 19:57:48 |
| Worker configuration complete | 20:00:39 |
| Hosting deployed | 20:01:22 |
| All six boards verified | 20:01:59 |
| Issuance restored | 20:05:59 |
| Production baseline saved | 20:06:11 |
| Serving issuer verified | 20:07:07 |
| Final inventory | 20:07:25 |

Cancellation rechecked the exact candidate set, session update time, upload and
validation leases, Storage replay object, validated run and reward grant inside
the guarded operation. One empty issued `2026.10.11` ticket was terminally
cancelled with its record retained. Profiles, rewards and validated runs were
not written. No data reset occurred.

The first Deploy attempt hit Firebase CLI's 10-second local source-discovery
timeout before Functions publication. Its log was retained. The same prepared
artifacts deployed successfully with the supported local
`FUNCTIONS_DISCOVERY_TIMEOUT=60` setting; see
[Firebase discovery-timeout guidance](https://firebase.google.com/docs/functions/tips#avoid_deployment_timeouts_during_initialization).
Issuance remained paused. The backend cutover excluded `runSessionCreate` until
ResumeIssuance, preserving the pause across redeployment.

Final live inspection found 26 ACTIVE Functions, both queues RUNNING, all six
expected current/next boards, zero active sessions and no pending or quarantined
settlement. The 254 session records remain: 204 validated, 26 cancelled and 24
expired. All 204 accepted validations and settled grants are retained.

Evidence is in the frozen checkout's
`.tmp/releases/rpg-runner-d7add/9ec2be2a6fe89224fe8e387caf9443b98b2264aad43b916fb0a2519ba8765d54/`:
preparation/component logs, exception-aware provenance, Cloud Build and benchmark
output, cancellation preflight/application receipts, before/paused/drained/final
inventories, live web bytes, issuer verification and browser outcomes.

## Remaining live acceptance

Fresh browser checks before and after publication both stop at the loader with
“This platform does not support the services required by the game.” The new
build reported no console errors but did not reach signed-in gameplay.
This pre-existing startup limitation remains open.

Controlled linked Play Games issuance, replay acceptance, once-only settlement,
background wallet catch-up, leaderboard/ghost playback, live retired-version
rejection, target-phone performance and cold/warm reward latency remain
unverified. No controlled accepted replay was produced after cutover, and no
native package was built or installed by this release. Infrastructure readiness
and local tests do not complete those checks. The [release checklist](../building/rescue_release_operations.md)
and [latency rollout plan](../building/reward_verification_latency.md) remain active.
