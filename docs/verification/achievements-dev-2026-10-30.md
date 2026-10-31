# Hall of Honour dev deployment

Release requested on 2026-10-30. Status: dev deployment and live infrastructure
verification complete; issuance and both replay queues restored. October 31
follow-up verified installed APK 4 and two natural runs; achievement-menu/claim
acceptance remains pending. Follow the
[release checklist](../building/achievements_dev_release.md).

## Source and scope

- Candidate: `8a094efb67a9f8e988940206c73b830765142248`, containing achievements
  commits `8aae7711` and `fa9c4000` and the preceding verified release tooling.
- Project `rpg-runner-d7add`, region `europe-west1`, environment `dev` only.
- Unchanged tuple: `2026.10.21 / rules-v2 / score-v4 / ghost-v1`.
- Source digest: `d74764d48e162314e48072d2a91474eb54776ab29f427b14c4556d1e13c878ba`.
- Canonical commands run from
  `.tmp/release-checkouts/8a094efb67a9f8e988940206c73b830765142248` using
  `tools/release/release.ps1 -Environment dev`. Evidence is under that checkout's
  `.tmp/releases/rpg-runner-d7add/<sourceDigest>/` directory.

The initial main-checkout Plan encountered CRLF/LF byte differences against the
previous baseline. Canonical Checkout produced the clean LF candidate; Plan
then passed with coordinated scope and unchanged deterministic inputs. No
compatibility override or source change was used to bypass the gate.

## Reuse and preparation

Prepare reused six complete matching components: Core, protocol, content,
terrain, validator and generated-content freshness. Client and Functions inputs
changed, so their complete checks/builds run afresh. The current production
dependency audit found no known vulnerabilities. All 295 Functions tests passed
against the local Firestore emulator; the Functions build and four inventory
tests also passed. Client analysis found no issues in `lib`, `test`, or
`test_driver`; all 1,379 client tests passed, with zero failures (881 seconds).
The optimized web build passed (543.7 seconds), including its Wasm dry run.
Chrome smoke passed hub startup, Practice-only Options, local run readiness,
start and game over without browser exceptions or backend requests. Preparation
was recorded successful at 20:01:33 UTC. Android config-only initialization
completed and left the frozen checkout clean.

Client navigation was seeded from the verified dev version-3 APK's source
checkout, `1d4799e7866ab3f1ca7cb2dd8be13a8929dbe47b`. The APK hash was rechecked as
`368c6a01540f1c7d05c2110463053af664b07fd2ffde92216b0727ae66ca2610`.
Its recorded navigation manifest hash matched the source pack:
`6f65c41f501cc9618ecefd8ae3349d037656aacb567935ab81268f8639a812bd`.
All 3,750 graph byte lengths and SHA-256 hashes matched the manifest before
copying; Core, `packages/run_protocol` and route sources are unchanged. The
current producer validated exact graph keys: 3,750 reused and zero built across
38 routes in 53.357 seconds. Seed proof is retained in
`.tmp/client-navigation-reuse.json` in the frozen checkout.

Worker input digest matches the previous deployment exactly:
`14cc6bdbf27b6c3dd5be4d16c2fb4af9a8cf64f475c5d27a408fd069479e70bb`.
BuildImage confirmed existing build `f1413136-2e1b-4359-8619-dc3800608b22` is
SUCCESS and contains the successful strict final-image benchmark (one CPU,
512 MiB, 36,000 ticks). It reused
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:45d6d0a00fe563464c9ca9ab89748bad7befad18ee8f53d073013a8fbf23908e`.
No new worker Cloud Build, worker source upload or worker navigation generation
was performed. Functions deployment still built its changed backend source.
The reused image includes the previously verified 93,910-graph worker pack;
its original build/benchmark provenance is retained in the release manifest.

## Android artifact

BuildAndroid with `-AndroidVersionCode 4` passed at 20:17:19 UTC. Dev package
`com.example.rpg_runner.dev`, version `1.0.0-dev`, code 4, min SDK 24 and target
SDK 36 were verified from the APK. Packaged Firebase and Play Games resources
match dev. All three ABIs and nine native libraries passed inspection with
16-KiB ELF/page alignment. All 3,750 packaged navigation graphs match the
prepared manifest; the Android producer reused all of them, building zero,
in 17.352 seconds. The Gradle build took 782.3 seconds.

- APK: `android/dev/4/app-dev-release.apk` beneath the release evidence directory.
- SHA-256: `aec3ccd3a4bd89eba5733109d4b92661b95c8d0700b5cd9d85d8d805fa9e19a0`.
- Size: 184,356,642 bytes.
- Signing certificate SHA-256:
  `001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.

The existing Firebase plugins emit a future Kotlin Gradle Plugin migration
warning; the pinned toolchain build succeeds. No dependency migration is part
of this release. `adb devices -l` found no connected phone, so no installation
or physical-device acceptance is claimed.

## Live inventory before cutover

Canonical Inspect at 19:36:12 UTC passed. All 32 Functions are ACTIVE; both
replay queues are RUNNING. Worker revision `replay-validator-00062-hml` serves
100% of traffic. Three expected boards are active. All 21 sessions are terminal:
nine validated, eleven previously cancelled and one expired. All nine grants
are settled; no pending/quarantined settlement or identity/evidence mismatch
was found. Canonical gold is 3,149. The separate ownership and player profile
collections each contain one profile. Saved as `inventory-before.json`.

No cancellation, player-data reset, staging or production deployment is
authorized by this release. Physical-device and live replay-to-claim acceptance
remain unverified while the phone is disconnected.

## Cutover

PauseIssuance completed at 20:22:55 UTC after verifying the serving issuer's
healthy paused revision. Deploy's fresh inventory at 20:24:07 UTC again found
all 21 sessions terminal, all nine grants settled, zero quarantined settlement
and unchanged canonical gold of 3,149. Functions deployment then started with
`runSessionCreate` excluded, preserving the pause through cutover.

Deploy completed successfully: Functions at 20:28:05 UTC, worker configuration
at 20:30:29 UTC and Hosting at 20:31:06 UTC. Worker revision
`replay-validator-00063-thr` serves 100% of traffic with the reused image.
Hosting published 4,487 files. ResumeIssuance verified the live worker digest,
Ready status and 100% traffic, downloaded and matched Hosting bytes, checked
current boards and drained settlement, resumed both queues and restored the
issuer at 20:36:11 UTC. The verified dev baseline was saved at 20:36:24 UTC.
The source-bound cutover record and mutation locks were released normally.

Deployed `main.dart.js` SHA-256:
`50a32174005ef784a457b26c7cfb7c59e802eaf86e5a970a9d59d0b72c2b5dcc`.

Direct issuer readback at 20:37:34 UTC confirmed healthy revision
`runsessioncreate-00086-gsr`, 100% traffic, and no temporary compatibility
override. Canonical Inspect at 20:37:58 UTC confirmed all 32 Functions ACTIVE,
both replay queues RUNNING and all three expected boards active. The worker
retains the exact verified image on ready revision `replay-validator-00063-thr`
with 100% traffic. All 21 session states, nine accepted runs/settled grants,
124 gold in run grants and 3,149 canonical gold match the saved pre-cutover
inventory. There is no pending or quarantined settlement. This comparison
establishes preserved inventory totals, not a byte-for-byte snapshot of every
player document. Evidence: `inventory-{before,after}.json`, `issuer-final.json`
and `final-summary.json` in the release evidence directory.

No tickets were cancelled and no player data was reset by this deployment.
Staging/prod were not changed. The final device check still found no connected
phone. APK version 4 is ready, but installation, a newly verified natural run,
Hall of Honour completion-date display, live gold claim and once-only payment
acceptance remain open in the linked checklist. Local/emulator tests cover
those behaviors; they are not a substitute for a live device claim.

October 31 follow-up: the [reward timing capture](reward-latency-phone-2026-10-31.md)
found APK 4 already installed and matched its on-device hash to the artifact
above. Two natural Competitive Forest runs validated and settled exactly once;
gold and XP changes matched the hub. No installation was repeated. Achievement
completion-date display, live claim and duplicate-claim protection were not
exercised and remain open.
