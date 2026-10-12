# Release verification: gameplay 2026.10.12

Deployed October 12, 2026 UTC (October 13 in Helsinki) through the canonical
release workflow to `rpg-runner-d7add` / `europe-west1`: Firebase Functions,
Cloud Run replay validation and [web Hosting](https://rpg-runner-d7add.web.app).
Normal issuance and both queues are restored. The owner authorized deployment,
requested focused validation, accepted traversal failures and approved cancelling
exactly four reviewed unsubmitted old-version tickets. Their records were retained;
all 226 accepted runs and settled rewards were preserved.

## Frozen source and authored changes

Frozen commit: `77525d318ca96c87ce2f4fe356d6b00bfa091baf`.
Source digest: `eac5b845203b2841c288bad61b13354bb655c56e86ee78d66e8c512c1489f2e4`.
Runtime and fixture changes match main `bca13b47`. The detached release adds
only its validation recipe and explicit exception record; main retains the normal
release recipe.

Field's eight active chunks and ground reference use Y=224. Its authored assembly
loops one early chunk and seven distinct easy chunks, with the first three chunks
suppressing enemies/encounters. The current rescue in `field_default_easy_004`
contains Huntress2 and Warrior. Forest retains all nine distinct hard Rocky Grove
chunks after Goddess, with the repaired `forest_rocky_grove_hard_003` exit landing.
Generated content admits 87 chunks, three levels, three parallax themes and three
terrain materials. See [level composition](../gdd/level_composition.md).

Client, Functions and worker share gameplay compatibility `2026.10.12`, with
`rules-v2`, `score-v4`, `ghost-v1` and replay/command formats 1 unchanged.

## Local preparation

Canonical preparation completed at 2026-10-12 21:16:57 UTC.

| Gate | Result |
| --- | --- |
| Focused client analysis/tests and release web build | 16 passed; build passed |
| Focused Core assembly and traversal-harness controls | 50 passed |
| Focused Functions compatibility, retirement and route-seed tests; build | 7 passed |
| Focused validator/replay/artifact tests and compiled AOT protocol probe | 102 passed; probe passed |
| Protocol analysis/tests | 44 passed |
| Content-pipeline analysis/tests | 98 passed |
| Terrain-material analysis/tests | 25 passed |
| Production dependency audit | No known vulnerabilities |
| Generated-content and navigation revision freshness | Passed |

The full client, Core, Functions and validator suites were omitted under the
owner's requested scope. Main's normal release recipe is unchanged. The detached
recipe hash prevents this focused evidence from satisfying the normal recipe.
Earlier preparation attempts failed on obsolete Field fixture assumptions and
were not recorded as passing releases. The fixtures now check the authored loop,
use a current flat chunk, and replay actual jump input over rocks. Rescue cases
at seeds 15/250 and 30/60 Hz require both current NPCs to survive and produce the
same server-authoritative 500 rescue points, rewards and score; client-supplied
inflated summaries remain ignored.

The broad generator fixture suite was stopped after its decoration, encounter
and compiled-trap probes passed; it was omitted from the final focused recipe.
Current-source generator dry-run freshness remained a required gate.

Client navigation: 3,720 graphs, 25,179,855 bytes, 38 declared routes and an
8-chunk horizon. This is an artifact inventory, not exhaustive route coverage.

Prepared and downloaded live `main.dart.js` SHA-256:
`9098548edfb43d6d717d44f96c96859619a1db2d2c4548d881676437c8e46665`.

### Separately recorded traversal diagnostics

At seed 42, Forest Grojib crossed the complete 85-chunk finite assembly, and
Field Unoco crossed its declared 32-chunk horizon. Field Grojib, Hashash and Derf
failed on chunk 8, `field_default_easy_007`, with no forward progress for 600
ticks. Their local X positions were 101.44, 109.94 and 113.44; failure ticks were
1414, 1418 and 1419 respectively. These are unresolved, owner-waived failures.
No movement capability, tolerance or runtime geometry was weakened to pass them.
The other seeds and full matrix were omitted. Pursuit diagnostics do not establish
player, spawn/combat, arena-boss, camera, rendering or performance acceptance.

## Immutable artifacts and cutover

Cloud Build `1068079f-4923-413b-95e2-c051aa7bf0b2` succeeded, running from
2026-10-12 21:18:10 to 22:10:14 UTC. It prepared 93,600 worker navigation graphs
across 38 declared routes and a 128-chunk horizon. All nine strict 36,000-tick
benchmark gates passed in the exact final image at one CPU / 512 MiB.
The no-ambient-enemy fixture proves throughput/determinism for its input script;
Forest ended near its opening and Field at 1,614.94 distance units. It does not
establish complete player/combat traversal or live reward latency.

Worker image:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:629a34a0e16f8cea6d3c8cc941c090f3a60410ece4e8de68b3eed017f46b7342`.
Healthy revision `replay-validator-00054-dvp` serves 100% of traffic.
Healthy issuer revision `runsessioncreate-00059-52x` serves 100% of traffic;
its serving revision has no `RUN_SUPPORTED_GAME_COMPAT_VERSIONS` override.
Downloaded Hosting JavaScript exactly matches the prepared hash above.

| Stage | October 12 UTC |
| --- | --- |
| Preparation complete | 21:16:57 |
| Image build started / succeeded | 21:18:10 / 22:10:14 |
| Issuance paused | 22:15:47 |
| Four approved tickets cancelled | 22:16:13 |
| Functions deployed | 22:21:27 |
| Worker configuration complete | 22:24:37 |
| Hosting deployed | 22:25:12 |
| Issuance restored | 22:31:29 |
| Production baseline verified | 22:31:40 |
| Serving issuer verified | 22:32:30 |
| Final live inventory | 22:32:36 |

The previous issuer image had been removed by managed cleanup. PauseIssuance
used its existing recovery path to rebuild the prepared issuer with the explicit
pause gate, then verified its healthy serving revision. The backend cutover
excluded `runSessionCreate`; normal issuance was restored only after matching
worker/web artifacts and all six boards were ready.

## Production state and data preservation

The pre-cutover inventory at 21:04:40 UTC contained 280 sessions: 226 validated,
26 cancelled, 24 expired and four issued old-version tickets. The owner-approved
candidate identity hash was
`eb4a98a74b1ed7dc58a276f6d45de2f98fe185441167f5ba0ab7b4910f4b9191`.
The guarded cancellation at 22:16:13 UTC rechecked healthy paused issuance, the
exact set, session update times, absent upload/validation leases, absent replay
objects, and absent reward/validation documents before its conditional transaction.
It retained all four session records and wrote no profile, reward or validated-run
document. No data reset occurred.

Final inspection at 22:32:36 UTC found 26 ACTIVE Functions, both queues RUNNING,
all six expected current/next boards, zero active sessions and no pending or
quarantined settlement. The 280 records now comprise 226 validated, 30 cancelled
and 24 expired. All 226 accepted validations and settled grants remain intact.

Evidence is in the frozen checkout's
`.tmp/releases/rpg-runner-d7add/eac5b845203b2841c288bad61b13354bb655c56e86ee78d66e8c512c1489f2e4/`:
component/freshness logs, separately waived traversal diagnostics, Cloud Build
and exact-image benchmark output, cancellation authorization/application receipts,
before/drained/deployed/final inventories, live web bytes, final issuer checks,
and the verified production baseline.

## Remaining live acceptance

Controlled signed-in Play Games issuance, replay acceptance, once-only settlement,
background wallet catch-up, leaderboard/ghost playback, live retired-version
rejection and target-device performance remain unverified by this release.
No controlled accepted replay was produced after cutover, and no native package
was built or installed. The previous web unsupported-services startup limitation
was not retested; historical browser observations are not current smoke evidence.
The [release checklist](../building/rescue_release_operations.md) remains active.
