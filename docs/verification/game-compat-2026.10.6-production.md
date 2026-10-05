# Production release `2026.10.6`

Deployed October 6, 2026 (Helsinki time) to
[production Hosting](https://rpg-runner-d7add.web.app), Firebase Functions,
and the `europe-west1` replay worker from frozen commit
`6802fa0eb8e10ac902693a183202646aeafb7e99`.
Source fingerprint:
`81a925773c17f3a54354b5a83c00700a700632195f6992f9f7a94aff1f7218ce`.
Client, Functions, worker, and boards agree on gameplay `2026.10.6`,
`rules-v2`, `score-v3`, and `ghost-v1`; replay and command formats remain 1.
This supersedes the [2026.10.4 release](game-compat-2026.10.4-production.md).

The release includes [combat pose alignment](combat-hitbox-alignment.md),
delayed visible Derf explosion damage, and deterministic pickup placement
that avoids authored non-collidable terrain. Debug overlays remain disabled
in release builds. The owner authorized deployment and cancellation of runs
if necessary. No run required cancellation; existing records were preserved.

## Preparation and build repair

The previous live web bundle failed its required App Check site-key guard.
Commit `6802fa0e` repairs the canonical web build to pass the tracked public
`web/production_defines.json`, using the existing domain-restricted Enterprise
key. Missing or empty keys now block preparation, and configuration changes
invalidate cached web builds. Credentials and debug tokens are excluded.
The fresh bundle contains the key; the startup guard remains intact.

- Frozen preparation passed client analysis and 1,062 tests, the release web
  build, 212 Functions emulator tests and build, 800 Core tests, 44 protocol
  tests, 81 content-pipeline tests, 25 terrain-material tests, 188 validator
  tests and the compiled AOT protocol probe, and generated-content freshness.
  The fresh production dependency audit found no known vulnerabilities.
- All three mocked release-tool suites passed under PowerShell 7 and Windows
  PowerShell 5.1: 30 helper, 25 integration, and 41 cache/scope/provenance
  checks per shell. These include key injection, configuration invalidation,
  and missing/empty-key rejection. They do not establish cloud readiness.
- Cloud Build `abe85d9c-570e-49c5-b3db-dc6fd3881e50` succeeded, including the
  strict exact-image 36,000-tick benchmark at one CPU and 512 MiB. All nine
  deterministic outcome and throughput gates passed.

The Core suite includes the seeded movement matrix and finite clear/blocked
finish controls: Grojib, Hashash, and Unoco at seeds 7, 42, and 2026; Forest's
finite authored route and 32-chunk Field/`new_level` horizons. Derf is
stationary. These checks do not establish full-run player, camera, spawn,
combat stress, or device performance coverage. The benchmark fixture has no
enemy stream. Separate container CI vulnerability/non-root gates were not
rerun as part of this deployment.

## Artifacts and cutover

- Worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:c55c484ac339979ebb82e23f509d9e06d75b80eabc5fafa2827aac5e3cc5fa5b`.
  Revision `replay-validator-00047-fmb` is Ready and serves 100% of traffic.
- Functions build digest:
  `a1e5b44819450a20ec448fbf1de076e1076ee679cec41cb9a50df537682db6e5`.
  Prepared web tree:
  `092485759918ccc9433c74dbc9e8e0909ffe9f21ccce7c87af3cc2ee6e348dff`.
  Live `main.dart.js` matches the prepared SHA-256:
  `0ddbfefedbfa95758da52b8d8d429f0e37d581c00969b0a8736d0da77d666ba1`.
- The prior issuer image was absent from the registry. The workflow rebuilt
  the prepared issuer with the explicit `release-paused` gate and restored
  local environment bytes. Its healthy serving revision established the
  pause at `2026-10-05T21:28:15.1452077Z`.
- The paused inventory had zero active runs, all 183 grants settled, and no
  stale or quarantined settlement. Functions except the issuer, READY indexes
  and rules, private invocation bindings, worker/queue configuration, board
  maintenance, and Hosting were deployed in that order.
- Artifacts were deployed at `2026-10-05T21:34:49.2610011Z`. All six expected
  current/next boards existed before queues and issuance resumed at
  `2026-10-05T21:39:03.9774890Z` (00:39 October 6 in Helsinki).
  Issuer `runsessioncreate-00038-n5p` is Ready, serves 100% of traffic, and has
  no temporary compatibility override. The verified production baseline was
  saved at `2026-10-05T21:39:15.7393288Z`.

Final read-only inventory at `2026-10-05T21:40:17.777Z` confirmed 26 ACTIVE
Functions, both queues RUNNING, all six boards present, zero active runs,
183 accepted validations and settled grants, 23 expired sessions, and
17 historical cancellations. No new cancellations or player-data resets
were performed.

## Browser checks and remaining verification

A live Enterprise App Check token exchange on the production origin succeeded.
An unauthenticated profile request with that token reached the auth guard and
returned HTTP 401; no token was printed and no smoke account was created.
Live JavaScript matched the prepared artifact. The browser initially retained
the preceding bundle under Hosting's default one-hour cache; verification
disabled its cache and loaded the current bundle.

Fresh browser bootstrap passes the missing-site-key guard but then fails with
`Unsupported operation: _Namespace` during service initialization. The UI
reports an unsupported platform. Browser gameplay is therefore unverified;
Play Games authentication remains Android-only. This release does not claim
successful web service bootstrap or signed-in browser play.

Linked Play Games production smoke remains outstanding: fresh Practice/ranked
tickets, replay acceptance, once-only settlement, leaderboard totals,
generation-pinned ghosts, and live retired-version rejection. Local tests and
the AOT probe passed compatibility rejection; they do not establish those
signed-in production outcomes. No Android/iOS package was built or installed.
See the [release checklist](../building/rescue_release_operations.md).

Stage manifests, component logs, build/benchmark output, live inventories,
and the sanitized App Check result remain under
`.tmp/release-checkouts/6802fa0eb8e10ac902693a183202646aeafb7e99/.tmp/releases/rpg-runner-d7add/81a925773c17f3a54354b5a83c00700a700632195f6992f9f7a94aff1f7218ce/`.
