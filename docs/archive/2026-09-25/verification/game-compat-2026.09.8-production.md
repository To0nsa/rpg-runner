# NPC rescue release `2026.09.8`

Deployed September 25, 2026, from commit `bc207a3f`. The worker, Functions and
web client were built from an isolated archive of that commit. Benchmark
experiments were excluded from the release and removed from the working tree.

## Delivered behavior

- Allied health is Warrior 20 HP, Huntress 13 HP and Huntress 2 9 HP: twelve
  points below the preceding 32/25/21 values.
- The generated registry includes the current authored Forest changes and the
  complete Field rescue encounter: 54 chunks across three compiled levels.
- Encounter targeting, chunk confinement, animations, authoring and rescue
  scoring ship together with the earlier navigation and Poison Darts changes.
- Client/Functions/worker use gameplay `2026.09.8`, ranked `rules-v2`/`score-v2`,
  ghost `ghost-v1`, and replay/command format 1.

## Deployment evidence

- Cloud Build `c481cf7c-2cf5-4c5a-92a2-b7cc34cfe749` succeeded.
- Immutable worker image:
  `sha256:9407b3ad1e711c33a356ed90094e969cc4172b57928ec55a605ce5be92e8a7c6`.
- Cloud Run `replay-validator-00041-dmj` is Ready with 100% traffic. Authenticated
  `/live` and `/ready` returned HTTP 200. The `production` tag points to the
  deployed digest; the checked-in service, queue, IAM and retention policy ran.
- All 26 Functions updated. `runSessionCreate` is ACTIVE at revision
  `runsessioncreate-00020-xav`, updated `2026-09-25T00:33:10.993651299Z`.
  The first CLI attempt exceeded its ten-second local discovery timeout;
  the retry used `FUNCTIONS_DISCOVERY_TIMEOUT=120` and completed successfully.
- Hosting version `e491fc8a0a995378` was released at
  `2026-09-25T00:31:06.773Z` to <https://rpg-runner-d7add.web.app>.
  The build uses the existing production App Check site key.
- Fetched live `main.dart.js` byte-matched the build, contained `2026.09.8`, and
  had SHA-256 `96F3E6A3270A869BB815B52D92AE81C8F21A0A08E5C67CE2D1BF108410ECCA3C`.
- Firestore rules/indexes were unchanged. Both Eventarc endpoints retain only
  the run-control service account as invoker; immediate settlement retains only
  the replay-validator account.

## Cutover and retained data

Ticket issuance and both replay queues were paused during the switch. Preflight,
cutover and final inventories found no active sessions or pending settlements.
The owner also authorized cancellation if needed; no cancellation or data reset
was necessary. All 106 historical sessions and 86 settled grants were retained.

Board maintenance provisioned all six expected current/next `2026.09.8` boards.
Public invocation for authenticated run creation was restored. Both queues are
RUNNING. The worker error query from `00:28:00Z` through final verification
returned zero entries. No stale supported-version environment override was found.

## Validation and explicit limits

The final health/content change passed 127 encounter and seeded traversal tests
and four real rescue/replay fixtures: seeds 7, 42 and 2026 at 60 Hz, plus 2026 at
30 Hz. All three allies survive those player-assisted scenarios and award 750
points. Validator analysis is clean, generated compilation succeeded, and the
worker, Functions and production web builds succeeded.

Earlier milestone validation included 694 Core, 152 worker, 81 content-pipeline,
44 protocol and 212 Functions tests. Broad Flutter and editor runs identified six
failures each; the affected targets passed after fixture/content corrections.
Those full aggregate suites were not repeated after the final health reduction;
the final targeted checks above cover that change. NPC and editor visual reviews
were completed during their implementation milestones.

The owner explicitly requested stopping benchmarks and proceeding with deployment.
The final 36,000-tick performance gate and exact-image container benchmark were
therefore not completed. No final performance sign-off is claimed.

The additional live Practice/ranked smoke attempt stopped at the existing linked
Google Play Games identity requirement, before any ticket or gameplay state was
created. The unused anonymous Auth account was deleted. Live rescue submission,
fresh-ticket compatibility rejection, settlement and ghost playback still need
a linked Play Games account; local replay/compatibility tests cover these paths.
The authentication gate was preserved.

This deployment includes the web client and backend services. No Android/iOS
binary was distributed; native installations need a matching rebuilt client.
