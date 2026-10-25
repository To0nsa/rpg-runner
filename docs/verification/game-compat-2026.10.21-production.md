# Gameplay 2026.10.21 release

Status: deployed October 25, 2026 UTC to `rpg-runner-d7add` / `europe-west1`.
Normal ticket issuance and both replay queues are restored. The immutable
worker image and both Android APKs are verified. The owner requested the latest game, levels
and shared backend for Android Dev and Android release, and will install the
APKs personally. No phone installation is part of this operation.

## Frozen source

The release source is `a4f99b89842042c5e90cd434cfb65e7774737efe`, with source
digest `ee1e4e4c8a060043f679b0f9f678997046767f321da7d0512a1efa9b8568cf64`.
It includes the latest committed game and level content, the body-parser
security fix in `e5c502e2`, and refreshed prepared weekly Field routes for
2026-W43 and 2026-W44. Commit `a4f99b89` keeps the benchmark's read-only terrain
lookahead inside Core's playtest boundary. Uncommitted Android beta planning
documents are excluded.

The matching client, Functions and worker gameplay version is `2026.10.21`,
with `rules-v2`, `score-v4`, `ghost-v1`, and replay/command formats 1.
The configured project is `rpg-runner-d7add`, region `europe-west1`.

## Preparation

The initial preparation stopped at the production dependency audit for
[GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828).
Workspace and Functions npm overrides now pin body-parser 1.x to 1.20.9 and
2.x to 2.4.0. The workspace production audit and an isolated production npm
resolution/audit both report zero known vulnerabilities. The focused Functions
validation passed all 242 tests and the build; the refreshed routes passed
their production-seed checks before freezing the source.

Candidate `4a4d857b` passed all 242 Functions tests/build and 293 validator
tests/analysis with the AOT protocol probe, but its full Flutter run failed the
generated-terrain import policy: the new service benchmark helper imported the
generated catalog directly. That run had 1,326 passing tests, one skipped test
and one failure. The helper was moved without changing its logic into Core's
playtest area; the policy test still restricts direct generated imports to Core.
All ten focused terrain policy tests and 19 benchmark tests passed after the
repair, and the navigation algorithm fingerprint remains fresh.

Final coordinated preparation passed all ten components at
`2026-10-25T20:55:41Z`: Functions tests/build, client analysis/tests/build,
Core, protocol, content-pipeline and terrain-material checks, validator checks
with the AOT protocol probe, and generated-content freshness. The unchanged
Functions results are verified cache hits. Counts are 242 Functions tests,
1,327 Flutter tests, 2,290 Core tests, 55 protocol tests, 99 content-pipeline
tests, 25 terrain-material tests, and 293 validator tests. The default Flutter
run retains one existing skip, `launch flag reaches the hub on a fresh install
without Firebase`. No historical test waiver applies.

The declared pursuit matrix covers seeds 7, 42 and 2026: Forest's complete
authored assembly before its repeating final section for Grojib, Hashash, Derf
and Unoco, and Field's first 32 production-selected chunks for Unoco. Field
ground-enemy pursuit remains excluded. These checks do not establish exhaustive
endless-route, player, camera, spawn or device performance coverage.

The client navigation pack contains 3,750 graphs across 38 declared routes at
an eight-chunk horizon. The optimized web build passed the real-artifact
Chrome smoke for the local Practice hub, Options, run readiness and launch,
with no browser exceptions or backend requests.

Cloud Build `006a39b2-cd58-40eb-9975-6e511ca35cbc` ran from
`2026-10-25T20:56:29.976Z` to `2026-10-25T22:21:02Z`, preparing 9,500 windows
and 93,910 worker navigation graphs across all 38 routes at the 128-chunk
horizon. All eight strict exact-image 36,000-tick gates passed at one CPU and
512 MiB: throughput, execution budget, deterministic outcome and sustained
forward progress for each level. This is a generated-terrain fixture without
combat objectives; it does not establish device or full-combat performance.

The immutable worker image is
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:0e9b11deb01bab3adf96687ba2936eb05079c758da6e0262b696ecb83a5cdfbf`.

Release manifests and component logs are under the frozen checkout's
`.tmp/releases/rpg-runner-d7add/ee1e4e4c8a060043f679b0f9f678997046767f321da7d0512a1efa9b8568cf64/`.

## Live inventory before cutover

Read-only inspection at `2026-10-25T19:54:00.432Z` found zero active sessions,
469 accepted validations and 469 settled reward grants, with no pending or
quarantined settlement. Worker revision `replay-validator-00057-7jb` was healthy
and serving 100% of traffic. These observations precede the release and do not
establish deployment success.

The canonical inspection at `2026-10-25T20:58:32.173Z` again found zero active
sessions, the same 469 accepted validations and settled grants, and no pending
or quarantined settlement. All six expected `2026.10.21` boards are still
missing before deployment, as expected for the unpublished compatibility.

Fresh pre-pause inspection at `2026-10-25T22:22:40.533Z` found the same settled
inventory. The prior issuer image had been removed by managed cleanup, so
PauseIssuance rebuilt the prepared issuer with the explicit `release-paused`
gate and restored the local environment bytes afterward. The healthy serving
revision was verified paused at `2026-10-25T22:27:44Z`, while both queues
continued running. Inspection at `2026-10-25T22:28:07.143Z` found only terminal
session states, zero active sessions, the same 469 accepted validations and
settled grants, and no pending or quarantined settlement. No run was cancelled
and no data was reset.

## Deployment and live verification

The workflow deployed 29 non-issuer Functions plus Firestore rules/indexes at
`2026-10-25T22:33:28Z`. It stopped at the expected asynchronous index-readiness
gate; all 12 indexes were READY on recheck, and retry reused the successful
Functions checkpoint. Private invocation bindings were verified before the
remaining stages continued.

Worker revision `replay-validator-00058-94k` was deployed at
`2026-10-25T22:39:37Z`, followed by Hosting at `2026-10-25T22:40:26Z`. All six
expected current/next boards were present before resuming. The live
`main.dart.js` bytes match the prepared artifact, SHA-256
`c0a0ee2eb64974dc176f8bb49e27ac2c3a7bc704b6ac1080a7008b5ab3ae14ab`.

Both queues were resumed and the issuer was redeployed under the matching
compatibility. Normal issuance was restored at `2026-10-25T22:46:32Z`; the
verified production baseline was saved at `2026-10-25T22:46:44.6549847Z`.

Final inspection at `2026-10-25T22:48:18.436Z` confirmed all 30 Functions ACTIVE,
both queues RUNNING, all six expected boards present, and zero active sessions
or pending/quarantined settlement. All 469 accepted validations and settled
grants were preserved. The worker serves 100% on `replay-validator-00058-94k`
with the immutable image above. Issuer revision `runsessioncreate-00071-wx8`
serves 100%, with no supported-version environment override or pause gate.

## Android artifacts

Both universal APKs were built from the clean frozen source and copied to
`build/releases/2026.10.21-a4f99b89/` in the main workspace. The adjacent
`release-manifest.json` records hashes, package/Firebase identities, signatures
and prepared navigation. Both contain arm64-v8a, armeabi-v7a and x86_64, target
API 36, retain version code 1, and use the existing workstation signing
certificate with SHA-256
`001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.

| Artifact | Package | Firebase Android app | SHA-256 |
| --- | --- | --- | --- |
| `rpg-runner-dev.apk` | `com.example.rpg_runner.dev` | `1:964001571974:android:1a4b98db937af313d81d07` | `d7a93e5754d90ccbf548e26deae0330727994768b114d0375dbcca9edd4cce36` |
| `rpg-runner-release.apk` | `com.example.rpg_runner` | `1:964001571974:android:d48582bc9cde8cf2d81d07` | `fd808f28cbecc0c3a091cc47989bdba5580a795bb164622e773c2700f95d8144` |

`apksigner verify` passed for both. Release is not debuggable; Dev retains its
debug flag and launcher name. Both APKs contain the byte-matching prepared
navigation manifest
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.

The first release build with `--no-pub` retained the debug-mode integration-test
registration and failed Java compilation. The standard release command
regenerated the mode-specific registration, excluded that development plugin,
and built successfully. Tracked source stayed clean. Failed and successful
build logs are retained separately. Neither APK was installed or launched on a
phone; the owner will perform installation and device checks.

## Outstanding work

- Owner installs both APKs and performs signed-in Play Games, replay acceptance,
  once-only settlement, wallet, leaderboard, ghost and device performance checks.
