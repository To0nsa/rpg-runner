# Production release `2026.10.3`

Deployed October 3, 2026 (Helsinki time) to `rpg-runner-d7add` in
`europe-west1` from frozen commit `b5835b8e4a8bd3c0e1f077b28affc8d1dc1a87a0`.
Source fingerprint:
`fbec2a2cbb11fa95430e16c10f28943cdb3620781b903791d07be6e23d5ef03b`.
The client, Functions, and replay worker agree on gameplay `2026.10.3`,
`rules-v2`, `score-v3`, and `ghost-v1`; replay and command formats remain 1.

Compared with the [preceding release](game-compat-2026.10.1-production.md),
this coordinated cutover includes Huntress ranged/stab/slash combat and
per-enemy stab history, furthest-progress distance scoring at 25 world units
per metre, and top-contact regeneration shrines. The new gameplay and score
partitions do not reuse historical replay authority or leaderboard results.

## Preparation and artifacts

- The exact frozen source passed local `Prepare`: Functions tests and build,
  client analysis, 874 client tests and web build, Core/protocol/content/terrain
  checks, validator analysis/tests and AOT probe, generated-content freshness,
  and a fresh production dependency audit with no known vulnerabilities. The
  preceding CI run failed one stale terrain-boundary allowlist assertion; commit
  `b5835b8e` corrected that test and the full local gate passed.
- Cloud Build `8a1e8dbe-ff88-4dc1-8742-efc17865609f` succeeded, including
  its `benchmark-release-image` step for the exact image with 36,000 ticks and
  the configured one-CPU/512-MiB limit. This does not establish signed-in
  gameplay or crowded-combat performance.
- Immutable worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:623b70d08d69ae65ea6018839504fb31ab63efe5b057d9c476018d643119b082`.
  Revision `replay-validator-00045-8jz` was Ready and serving 100% of traffic
  in the final live inspection.
- Functions build digest:
  `ba35dd9d07957412fb3144f1638b35e81e92e17ac0fb8ebb1b376801b29a8033`.
  Prepared web artifact digest:
  `31bdd38508d2a58f2a0a7898784dbfc11474e894f44fca2fc16bd189a7c3a249`.
  The fetched live `main.dart.js` matched the prepared publication at SHA-256
  `FBB98234A754C19500D59FF12C73CFC7FA4E583DF1CD542A05FD0D9CB7E6C234`.

## Drain and cutover

Normal ticket issuance was paused while both replay queues continued running.
The inventory found two issued `2026.10.1` sessions, unchanged since issuance,
with no upload state, validated replay, or reward grant. The owner authorized
cancelling them if necessary. An atomic Firestore commit at
`2026-10-02T21:45:54.041759Z` changed only those two records to `cancelled`,
using update-time preconditions and an explicit `2026.10.3` cutover message.
Their records were retained; no rewards, replay artifacts, or other player
data were reset. The next read-only inventory showed zero active sessions,
all 177 reward grants settled, and no stale or quarantined settlements.

The workflow deployed all exported Functions except `runSessionCreate`,
Firestore rules and READY indexes, private invocation permissions, the worker,
queue routing, board maintenance, and Hosting. All six expected current/next
`2026.10.3` boards existed before queues and issuance resumed. Both queues
were RUNNING in the final inspection. The issuer revision
`runsessioncreate-00032-zpm` was Ready with 100% traffic and no temporary
supported-version override. Issuance resumed at
`2026-10-02T21:57:17.512843Z`.

The final read-only inventory at `2026-10-02T21:58:05.856Z` retained 209
sessions: 177 validated, 21 expired, and 11 cancelled. It reported no active
runs, missing current/next boards, stale pending settlement, or quarantined
settlement. The live worker and web identity matched the prepared release.

## Remaining verification

Linked Play Games production smoke remains outstanding: fresh Practice and
ranked tickets, uploaded replay acceptance, once-only settlement, leaderboard
totals, generation-pinned ghost playback, and retired-version rejection. The
anonymous canary is rejected by the identity gate and cannot stand in for a
linked account. Native Android/iOS distribution was outside this web release.

Local preparation, Cloud Build, and production checkpoints are retained under
`.tmp/release-archives/b5835b8e4a8bd3c0e1f077b28affc8d1dc1a87a0/releases/rpg-runner-d7add/fbec2a2cbb11fa95430e16c10f28943cdb3620781b903791d07be6e23d5ef03b/`.
