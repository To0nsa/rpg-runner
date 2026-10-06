# Production release `2026.10.7`

Deployed October 7, 2026 (Helsinki time) to
[production Hosting](https://rpg-runner-d7add.web.app), Firebase Functions,
and the `europe-west1` replay worker from frozen commit
`ffd6475feb2004bc6f18de4884a9e1adaeaedeaa`.
Source fingerprint:
`3e6ca5116deb95dcf3ebc3da80297e034d8eb1cb3bfc13ff53840fcb39ea6c68`.
Client, Functions, worker, and boards use gameplay `2026.10.7`, `rules-v2`,
`score-v3`, and `ghost-v1`; replay and command formats remain 1.
This supersedes the [2026.10.6 release](game-compat-2026.10.6-production.md).

The release includes [Derf transformation](../tdd/derf_transformation.md),
the finalized [Forest authoring](../gdd/level_composition.md), expanded hard
assembly, an easy boss-themed terrain chunk, collision and placement repairs,
and matching generated runtime content. The boss-themed chunk adds terrain,
not a boss actor. Authoring and traversal repairs were committed as `39b9eab1`;
subsequent release fixes are included in the frozen commit above. The owner
explicitly authorized repair, commit, deployment and cancellation if necessary.

## Preparation and validation

Frozen preparation completed at `2026-10-06T21:21:08.8901389Z`:

- Client analysis, 1,102 tests and the release web build passed, including the
  WASM dry run. Functions build and all 212 emulator tests passed.
- Core analysis and 928 tests, protocol analysis and 44 tests, content-pipeline
  analysis and 81 tests, and terrain-material analysis and 25 tests passed.
- Validator analysis, 188 tests and the compiled AOT protocol-rejection probe
  passed in an earlier preparation with identical component inputs. The final
  preparation reused that verified component evidence, alongside matching
  client, backend, Core and protocol evidence; it did not rerun those unchanged
  checks. Final content, terrain and freshness gates ran against frozen source.
- Generated-content freshness passed for 80 chunks and three registered levels
  (two selectable playable levels).
- The production pnpm audit reported no known vulnerabilities. An isolated
  cloud-style npm production resolution also reported zero known vulnerabilities.
  The uploaded Functions manifest pins the tested direct SDK versions and
  mirrors workspace security overrides, including `proxy-addr` 2.0.8 and
  `@fastify/busboy` 3.2.2; see
  [dependency ownership](../tdd/firebase_cloud_functions_overview.md).

The 85 traversal/control cases retain 21 new regressions. Seeds 7, 42 and 2026
cover all four enemies, including transformed Derf. Forest traverses its complete
finite routes of 108, 108 and 104 chunks; Field and `new_level` use declared
32-chunk prefixes. Continuous enemy state, actual catalog capabilities, route
boundary crossing and clear/blocked controls are retained. These pursuit checks
exclude authored spawn, combat, player, camera, rendering and full-run acceptance.

Release preparation exposed stale accepted-request compatibility fixtures and
two Windows compiler deadlines. Valid backend fixtures now use the exported
current version while explicitly rejecting retired `2026.10.6`. Real isolated
worker trap fixtures retain all assertions and allow 15 minutes on Windows
(five elsewhere); the encounter fixture allows six minutes (two elsewhere).
The content-pipeline regression now accepts supported grounded Derf placement
and still rejects the complete group when its body extends outside the chunk.
No gameplay capability or final-image throughput gate was widened.

Cloud Build `5c21cd07-d460-402c-9063-459b22a9e1d6` succeeded at
`2026-10-06T21:25:52.486411Z`. The strict exact-image 36,000-tick benchmark,
at one CPU and 512 MiB, passed all nine deterministic outcome and throughput
gates. Its fixture has no enemy stream and does not establish device or full-run
performance. Separate container CI vulnerability/non-root gates and unchanged
mocked release-tool suites were not rerun for this deployment.

## Artifacts and authorized cutover

- Immutable worker image:
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:706a31f061f4709bd5347ee253895746ce237ca8c84474db2427f3b7f5485cf7`.
  Ready revision `replay-validator-00048-p5z` serves 100% of traffic.
- Functions build digest:
  `6d1b65b818d18b3800622ba30b2e9074c9fe7d482ed20db6d95d3ec456e0bf2b`.
  Prepared web tree digest:
  `ea4dde34adfa7d707758edb9eeb06917c9f0f43685ff1ca3abb045e833e506f0`.
  Live `main.dart.js` matches prepared SHA-256:
  `3f15ab3252d4ef6338f0b56d9b6ab641ee44b312e17d93f5ff7852daced9b144`.
- Issuance was paused on the healthy pinned issuer at
  `2026-10-06T21:28:11.2210049Z`; the old worker and queues remained available
  while validation and settlement drained.
- Exactly three unsubmitted `2026.10.6` tickets were cancelled at
  `2026-10-06T21:29:48.231Z`, under the owner's explicit authorization. None had
  replay/upload/lease evidence, a validated run or a reward grant. An atomic
  transaction rechecked the reviewed set and document update times before
  terminal writes. Set digest:
  `04e6bce924bef2f542d4df36d8f5ecabc47c75b2c56a58da9c7433ae334d4266`.
  Records were retained; zero profiles, rewards or validated runs were touched.
- The drain inventory at `2026-10-06T21:30:29.715Z` had zero active sessions,
  187 accepted validations and settled grants, 23 expired sessions and 20
  cancellations (17 historical plus these three). No pending or quarantined
  settlement was reported. No data reset was performed.
- The first Deploy attempt stopped at local Firebase function discovery's
  ten-second deadline, before deployment checkpoints. Retrying the same frozen
  artifacts with process `FUNCTIONS_DISCOVERY_TIMEOUT=60` succeeded; issuance
  and queues remained paused during the retry.
- Matching Functions except `runSessionCreate`, READY indexes/rules and private
  invocation bindings deployed at `2026-10-06T21:39:18.2925801Z`; worker
  configuration completed at `2026-10-06T21:45:00.1864603Z`; Hosting completed
  at `2026-10-06T21:46:57.6570259Z`. Excluding the issuer preserved the pause.
- Live inventory at `2026-10-06T21:51:09.022Z` found all six expected current/next
  `2026.10.7` boards, no missing boards, zero active runs and all 187 grants
  settled. Historical boards and accepted artifacts were retained.
- ResumeIssuance verified the Ready worker, live web byte hash, board completion
  and fresh clean drain; restored both queues and the matching issuer; and
  removed the temporary pause override at `2026-10-06T22:02:10.2112656Z`
  (01:02 October 7 in Helsinki). The verified production baseline was saved at
  `2026-10-06T22:02:38.7071214Z`.

Final read-only inventory at `2026-10-06T22:21:32.642Z` confirmed 26 ACTIVE
Functions, both queues RUNNING and all six expected boards present. Issuer
`runsessioncreate-00041-7mz` is Ready, serves 100% of traffic and has no
temporary supported-version override. Production traffic created three new
`2026.10.7` sessions after resumption: two additional validations were accepted
and their rewards settled, bringing both totals to 189; one new-version ticket
remained issued. No old-version active session, terminal evidence mismatch,
pending or quarantined settlement was reported. That new ticket is ordinary
post-release traffic and was retained. These passive observations are live
evidence, not a controlled signed-in gameplay/ghost smoke.

## Remaining verification

Controlled signed-in linked Play Games production smoke remains outstanding:
fresh Practice/ranked tickets, replay acceptance, once-only settlement, leaderboard
totals, generation-pinned ghosts and live retired-version rejection. Local
compatibility tests and the AOT probe passed; they do not establish those live
signed-in outcomes. No Android/iOS package was built or installed in this release.

The preceding release documented browser bootstrap failing on unsupported file
I/O (`Unsupported operation: _Namespace`). That path was unchanged and browser
interaction was not repeated here. Live Hosting byte identity was verified;
successful browser service bootstrap or gameplay is not claimed. See the
[release checklist](../building/rescue_release_operations.md).

Stage manifests, component logs, Cloud Build output, inventories and artifacts
remain under
`.tmp/release-checkouts/ffd6475feb2004bc6f18de4884a9e1adaeaedeaa/.tmp/releases/rpg-runner-d7add/3e6ca5116deb95dcf3ebc3da80297e034d8eb1cb3bfc13ff53840fcb39ea6c68/`.
Sanitized cancellation receipts, full benchmark output and cutover logs are
retained in the repository's `.tmp/v7-*` files. The verified baseline is
`.tmp/release-cache/deployments/rpg-runner-d7add/europe-west1.json`.
