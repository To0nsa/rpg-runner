# Game compatibility 2026.10.17 production release

Deployed October 17, 2026 UTC through the coordinated release workflow to
`rpg-runner-d7add` / `europe-west1`: Firebase Functions, Firestore rules and
indexes, Cloud Run replay validation, and web Hosting. Normal ticket issuance
and both replay queues are restored.

## Frozen source and preparation

The deployed source is detached release commit `21b60c70` with digest
`26395018595ba553763be94a7730ae9b99347056faca7a7bc8c18b356d490d1c`.
It includes regenerated runtime terrain and route fixtures, a longer Cloud
Build timeout, early resolution of the pinned runtime base image, and a Field
replay benchmark patrol before the first authored gap. Compatibility is
`2026.10.17` / `rules-v2` / `score-v4` / `ghost-v1`; replay and command formats
remain version 1. The release snapshot predates the later XP and UI commits on
`master`.

`Prepare` completed at 21:24:10 UTC. It passed or reused verified results for
all ten required components: Functions tests/build, client analysis and 1,479
successful Flutter test events, web build, Core analysis/tests, protocol,
content, terrain, validator analysis/tests/AOT, generated-content freshness,
and the production dependency audit. The owner accepted 15 specific Forest
enemy-traversal failures. Only the detached release recipe excluded those 15
cases; the repository test source and authored chunks were not changed to make
them pass. These exclusions are a coverage limit, not passing test evidence.

## Image and benchmark

An initial Cloud Build exceeded the old 3,600-second timeout during navigation
generation. A later build reached image assembly but failed fetching the
distroless runtime base after about 70 minutes. The Dockerfile now fetches that
pinned base first. The next exact-image benchmark exposed a Field fixture fall
at tick 226 in the authored gap. Its moving patrol was adjusted and locally
probed for all 36,000 ticks without changing gameplay or the authored terrain.

Final Cloud Build `59ccbd5f-2a83-4cbe-8b99-c446e2f519d0` ran from
21:25:22 to 22:40:46 UTC. It prepared 9,500 windows and 93,840 navigation
graphs, built the final image, and passed all six strict benchmark gates at one
CPU and 512 MiB. Field replayed 36,000 ticks in 1.254 seconds and Forest in
1.956 seconds; both outcomes were deterministic. The immutable image is
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:be02d13a6679db4caf5d91881d976b39ad31961ca60e58c679b59a4478676c82`.
The no-enemy benchmark establishes replay throughput and deterministic outcome
for its fixtures; it does not establish full route traversal.

## Drain and cutover

Pre-cutover inspection found 423 run sessions: 313 validated, 59 expired, 45
cancelled, and six issued `2026.10.16` tickets expiring October 18. All 330
accepted validations had settled grants, with no stale pending or quarantined
settlement. `PauseIssuance` verified a healthy serving revision with the
explicit release gate while both queues continued draining.

The paused-state inspection still found exactly those six issued tickets. A
fresh review verified no upload lease, replay object, validated run, or reward
grant for any of them. Under the owner's authorization, a conditional atomic
write changed only those six session records to `cancelled` at 22:44:26 UTC.
The exact ticket-set SHA-256 was
`3994117cc95e0653cd26d385eb3333f52b66bcf7512355b0caec3d9aba9e2e3b`.
No ticket record or settled data was deleted. The next inventory had zero
active sessions, 330 accepted validations, 330 settled grants, and no pending
or quarantined settlement.

The workflow deployed the 25 non-issuer Functions plus Firestore rules and
indexes, worker revision `replay-validator-00056-qnw`, six current/next
boards, and Hosting. It then verified the live worker image and web bytes,
resumed both queues, and restored ticket issuance with healthy issuer revision
`runsessioncreate-00065-xww`.

Final inspection at 22:58:40 UTC found all 26 Functions ACTIVE, both queues
RUNNING, all six expected boards present, zero active sessions, and no stale
pending or quarantined settlement. The 423 session records comprise 313
validated, 59 expired, and 51 cancelled. All 330 accepted validations and
330 settled grants remain intact. The worker and issuer revisions each serve
100% of traffic; the issuer has no temporary pause override. The live
`main.dart.js` SHA-256 equals the prepared artifact:
`fa97fc89d042e105ab2aa50b7f4f374ff375032fb9a47fbae28f102e01836597`.

Release manifests, component logs, Cloud Build result, cancellation receipt,
inventories, and live web bytes are under the frozen checkout's
`.tmp/releases/rpg-runner-d7add/26395018595ba553763be94a7730ae9b99347056faca7a7bc8c18b356d490d1c/`.

## Remaining verification

Controlled signed-in Play Games issuance, accepted replay, once-only
settlement, wallet catch-up, leaderboard and ghost playback, live retired-version
rejection, and target-device performance remain unverified. No controlled
accepted replay or native package was produced after cutover. The
[release checklist](../building/rescue_release_operations.md) retains those
checks.
