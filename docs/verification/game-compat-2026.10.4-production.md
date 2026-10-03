# Production release `2026.10.4`

Deployed October 3, 2026 (Helsinki time) to
[production Hosting](https://rpg-runner-d7add.web.app), Firebase Functions,
and the `europe-west1` replay worker from frozen commit
`43e6c8410b1ba43ae2851fa5678d99e252a1ceb9`.
Source fingerprint:
`852d6127cc81d662a12c96f08d345f1d0424665aa018118d02ffd170f0a1e1c7`.
Client, Functions and worker agree on gameplay `2026.10.4`, `rules-v2`,
`score-v3`, and `ghost-v1`; replay and command formats remain 1.

This release includes equal Forest blessing regeneration rates, 37-HP allied
NPCs, the latest Forest layouts and nine-chunk hard finale, and the current
startup and ghost-loading improvements. It supersedes the
[preceding coordinated release](game-compat-2026.10.3-production.md) and
[ghost cache client publication](ghost-cache-client-2026-10-03.md).

## Repairs and validation

The requested source `e35ec73a` failed content readiness, generated freshness
and the current production dependency audit. The owner authorized repairing
the blockers and deploying. Commit `2c029b1e` pins `@fastify/busboy` to its
patched `3.2.1` release. Commit `43e6c841` restores the ground classification
at `forest_rocky_grove_hard_003`'s exit, adds one entrance foothold before
the enlarged rock in `forest_rocky_grove_hard_004`, and regenerates the runtime
content. The nine-chunk section, water gap, and enemy capabilities are preserved.

The new hard section exposed an unsupported final pursuit-target location.
The test harness now searches farther forward within its single continuation
chunk; the tested finish remains fixed. Clear and blocked finish controls and
focused rock/target regressions pass.

- Frozen `Prepare` passed client analysis and 945 tests, the release web build,
  212 Functions emulator tests and build, 797 Core tests, 81 content-pipeline
  tests, 186 validator tests and the compiled AOT protocol probe, and generated
  freshness. Matching protocol and terrain validation records were reused from
  the verified component cache. The fresh production audit found no known
  vulnerabilities.
- The focused pre-freeze generation checks passed all 34 tests. The traversal
  and harness suite passed 51 tests, including the 27 seeded enemy scenarios
  and three new regressions. Forest seeds 7, 42 and 2026 covered 81, 78 and
  80 chunks respectively; Field and New Level covered 32 chunks each.
  Grojib, Hashash and Unoco crossed the actual tested route boundaries with
  continuous state and unchanged catalog capabilities. Repeating tails beyond
  these horizons, combat, player control and device performance are excluded.
- Cloud Build `0ad6d621-b812-45f0-b475-225fb4897068` and its
  `benchmark-release-image` step succeeded. The exact final container passed
  the strict 36,000-tick benchmark with one CPU and 512 MiB.

## Artifacts and cutover

- Worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:22442e729293b5b9c135bb8fa01bab557f8da1062589f63b11ee454e45aafe1f`.
  Revision `replay-validator-00046-6rv` is Ready and serves 100% of traffic.
- Functions build digest:
  `19eb4321d31f0f8d147a7e2b8b8d89df149894258c5a1b8fd868080073151c0b`.
  Prepared web tree:
  `711cd60340023b02623917fb3e9637d94e2bb8b2d6bfdecdd649383da74e5383`.
  Live `main.dart.js` matched the prepared SHA-256:
  `b2772d053615d4e11d1abc66d6b024600f6f24459cbb850aa8b47c40030a5572`.
- Issuance paused at `2026-10-03T20:41:18.4526882Z`. The owner separately
  authorized cancelling exactly six reviewed, unsubmitted `2026.10.3` tickets
  if they remained unsubmitted. At `2026-10-03T20:41:47.362Z`, the guarded
  transaction rechecked the paused issuer, exact candidate set, update times,
  and absence of upload, validation or reward evidence, then terminalized those
  six records as cancelled. Records were retained; no rewards, validated runs
  or profiles were changed. The reviewed set digest was
  `a12bdefdf20136bacb2975a6c806bb6431ecde63d1a048046ba88ab85ede61b0`.
- The post-cancellation inventory showed zero active runs, all 180 grants
  settled, and no stale or quarantined settlement. The workflow deployed
  Functions except the issuer, READY indexes/rules, private invocation bindings,
  worker configuration, board maintenance, and Hosting. All six expected
  current/next boards existed before resuming queues and the issuer.
- Artifacts were deployed at `2026-10-03T20:49:33.7570014Z`; issuance resumed
  at `2026-10-03T20:54:19.9224196Z` (23:54 Helsinki time). Issuer revision
  `runsessioncreate-00035-5ql` is Ready, serves 100% of traffic and has no
  temporary compatibility override. The verified production baseline was saved.

The final read-only inventory at `2026-10-03T20:55:44.874Z` reported 26 ACTIVE
Functions, both queues RUNNING, all six required boards present, zero active
runs, 180 validated runs and settled grants, 21 expired sessions and 17 cancelled
sessions. No stale or quarantined settlement remained. The public site returned
HTTP 200 and its published JavaScript matched the prepared artifact.

## Remaining verification

Linked Play Games production smoke was not performed: fresh Practice/ranked
tickets, uploaded replay acceptance, once-only settlement, leaderboard totals,
generation-pinned ghost playback, and retired-version rejection remain in the
[release checklist](../building/rescue_release_operations.md). Automated tests,
the image benchmark and live infrastructure checks do not establish those
signed-in outcomes. No Android/iOS package was built or installed in this release.

Preparation, image and production checkpoints are retained under
`.tmp/release-checkouts/43e6c8410b1ba43ae2851fa5678d99e252a1ceb9/.tmp/releases/rpg-runner-d7add/852d6127cc81d662a12c96f08d345f1d0424665aa018118d02ffd170f0a1e1c7/`.
