# Dev release, November 9, 2026 (Helsinki)

Status: dev backend, worker and web deployed; queues and normal issuance restored.
The saved-build reset and final live inspection passed. Android APK 6 is built
and verified. Signed-in device acceptance remains open.
The owner requested all current code on dev backend, web and an Android build,
and separately authorized account-data reset and ticket cancellation if needed.
Staging, production and Play publication are outside this release.

## Source and scope

- Project `rpg-runner-d7add`, region `europe-west1`, Coordinated scope.
- Frozen source `3540bfed617dc8eb6811ed8fb8fbead61fd9c9f3` in
  `.tmp/release-checkouts/3540bfed617dc8eb6811ed8fb8fbead61fd9c9f3/`.
- Source digest:
  `2b1f598cbaba34241b1952d01b0aa849a5f96511985be23ba3eee38078598730`.
- Compatibility: `2026.11.8.6 / rules-v2 / score-v4 / ghost-v1`.
- Includes the owner's uncommitted build-name button change and its two
  documentation edits. Those edits remain in the main worktree.
- Release corrections: inventory authorization receives confirmed progression
  (`e899dd0f`); stale charge-timing assertions and the Training Field Core import
  allowlist are corrected (`ebd71b44`); explicit ranked windows cover
  November/December and ISO weeks 45/46 (`033abaa6`). Field/Forest geometry,
  Practice seeds and navigation algorithm revision are unchanged.

The first candidate's full client suite exposed four stale assertions. All 26
targeted tests passed after correction, followed by the complete successful
suite below. Superseded snapshots were never deployed. The current source is
clean; preparation was not bypassed or relabelled.

## Local preparation

Canonical `tools/release/release.ps1 -Environment dev -Action Prepare` ran from
the frozen checkout. It completed at **2026-11-08T23:01:02.4798105Z**.
Logs and `release.json` are under that checkout's
`.tmp/releases/rpg-runner-d7add/2b1f598cbaba34241b1952d01b0aa849a5f96511985be23ba3eee38078598730/`.

| Gate | Result |
| --- | --- |
| Production dependency audit | No known vulnerabilities |
| Functions emulator tests | 362 passed |
| Production build and offline inventory tests | Build passed; 5 tests passed |
| Client analysis and tests | Clean; 1,485 passed, one existing skip |
| Release web and Chrome artifact smoke | Passed hub, Options, readiness, start and game-over; no browser exceptions or backend requests |
| Core analysis and tests | Clean; 2,634 passed |
| Run protocol analysis and tests | Clean; 133 passed |
| Content pipeline analysis and tests | Clean; 103 passed |
| Terrain material analysis and tests | Clean; 25 passed |
| Navigation/generated content freshness | Passed; 88 chunks and three level definitions validated |
| Validator analysis, 367 tests and compiled AOT probe | Verified matching component reused from `ce77c185` |

Toolchain: Flutter 3.47.1 / Dart 3.13.1; Node 24.22.1 / pnpm 11.22.0.
Windows preparation used the real-artifact Chrome gate; it does not claim Linux
widget-browser execution or device integration coverage. The existing skipped
fresh-install Developer Practice widget test remains a skip.

Functions tree digest:
`78555cf5c966f0ff71375a8519ffe13bef2e97330929848b9514948970e27a30`.
Web tree digest:
`b21148595f6dcd56605a7b4abe85aa0b96707c0f13fc193ce6d96a3e38a2fac9`.

## Navigation and worker image

The client was seeded from the verified October 31 pack. The current producer
reused **3,170** graphs and built **470** missing ranked-route graphs: **3,640**
graphs, 28,821,333 bytes. Manifest SHA-256:
`f3b55da6bf4ea9ddbfa6c715bae13fe8ff4cef795e6ced8632918e3c5e0d15bf`.
Android subsequently reused all 3,640 graphs with zero rebuilt.

Canonical BuildImage verified the previous dev image's successful build and
strict benchmark before selecting it as the worker navigation seed:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:549581d0ca927054c1c9f39544876c80d127dd1bd8654fb4d769f2d1fe7051a1`.
The source build is `7df8cfb5-08bd-4988-8671-366e623f9955`.

New Cloud Build `77a6b229-0b43-43af-96e3-875286bbec81` ran from
2026-11-08T23:02:15Z to 23:21:39Z. Its navigation producer reused **79,290** graphs and built
**14,630**, for **93,920** total. Canonical ImageStatus verified SUCCESS and the
immutable image:
`europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:99b30cacbdb8f2867a0755278de90260347d2503af474f75b9b0f80a98afbaef`.
All eight strict final-image benchmark gates passed with one CPU and 512 MiB:
36,000 ticks per level, Forest 1.870610 seconds and Field 1.718107 seconds.
This bounded generated-terrain fixture does not establish device latency or
full-combat acceptance.

## Android artifact

Canonical BuildAndroid used explicit dev environment and version code 6 after
config-only initialization left the checkout clean. Inspection completed at
**2026-11-08T23:16:28.4989511Z**.

- Source-bound artifact: `android/dev/6/app-dev-release.apk`, 186,897,101 bytes.
- SHA-256: `4a68e73764fc17fbaa361a499ea734a038d7f5ae6c1f293429476609984dcc89`.
- Package `com.example.rpg_runner.dev`, version `1.0.0-dev` / 6; dev Firebase
  and Play Games resource identities verified.
- Signing certificate SHA-256:
  `001f8fe8d465d47b2aa1264fd8a00ac2221875aeef17ce1bfad5d1bf6d91f061`.
- Three ABIs, 12 native libraries and 16-KiB ELF64 alignment passed inspection.
- All packaged navigation graph bytes and the manifest match prepared source.
- Hash-verified delivery copy:
  `.tmp/dev-release-20261108/app-dev-release-v6.apk`.
- Existing Firebase-plugin Kotlin migration warnings remain; the build passed.
  Crashlytics symbols were not uploaded for this dev artifact.

This establishes packaging, not installation, signed-in gameplay or Play delivery.

## Live inventory and cutover

Read-only canonical Inspect at 2026-11-08T22:20:35.845Z found all 35 Functions
ACTIVE, worker `replay-validator-00065-9cx` Ready and serving 100% with the
verified previous image, all three queues RUNNING and ten schedulers ENABLED.
The source exports match the live 35-function set exactly.

There were 52 terminal sessions: 25 validated, 16 cancelled and 11 expired.
All 25 reward grants were settled; no active ticket, pending settlement or
quarantine required cancellation. The one ownership profile retained 3,284 gold
and selection schema 1. Three old-version boards were active; current candidate
boards had not yet been provisioned.

Canonical PauseIssuance found that the previous managed issuer image had been
removed. Its supported recovery rebuilt only `runSessionCreate` from prepared
source with the explicit pause gate, restored local environment bytes, and
verified the healthy paused revision serving all traffic. Fresh Inspect at
2026-11-08T23:29:45.760Z confirmed the same 52 terminal sessions and 25 settled
grants. No cancellation was needed. `inventory-paused.json` preserves that read.
Canonical `Deploy -CutoverReady` completed with the source-bound cutover record
intact and `runSessionCreate` excluded from the coordinated backend phase:
Functions at 23:34:27 UTC, worker at 23:38:56 UTC and Hosting at 23:39:52 UTC.
Hosting published 4,477 files, including 584 uploaded changes, at
<https://rpg-runner-d7add.web.app>.

The reviewed saved-build reset committed at **2026-11-08T23:42:04.138056Z** under
the dev mutation lock and matching source-bound cutover record. Issuance was
verified paused and runs drained. The exact backed-up document update time was
a write precondition. The single profile moved from revision 54 to 55 with
selection schema 2, default saved builds and missing starter ownership.
Readback verified every untouched profile field and the exact written fields;
3,284 gold, 400 XP, existing unlocks, 25 completed runs, all 25 settled grants
and reward idempotency evidence were preserved. Auth/profile identity and run
history were not reset. The plan hash is
`e78e4fb686e702b56e37e8a451713bdfaf2aa94f94740edf568182d07d0244db`;
backup, plan, receipt and readback are retained in `.tmp/dev-release-20261108/`.

Inspect at 23:42:45 UTC found zero invalid saved selections, no active sessions
or unsettled grants, all three expected `2026.11.8.6` boards active and the three
old-version boards disabled. `inventory-before-resume.json` preserves that
snapshot. Canonical `ResumeIssuance -CutoverReady` restored normal issuance at
**2026-11-08T23:47:40.4360647Z**, verified the live worker/Functions/web baseline,
cleared the source-bound cutover record and released its mutation lock.

Final canonical Inspect at **2026-11-08T23:48:41.887Z** confirmed:

- All 35 Functions ACTIVE.
- Worker `replay-validator-00066-jc6` Ready with 100% traffic on the immutable
  `sha256:99b30cacbdb8f2867a0755278de90260347d2503af474f75b9b0f80a98afbaef` image.
- Both replay queues and the existing `runPendingWork` queue RUNNING; all ten
  schedulers ENABLED.
- Three active current-version boards, three disabled old-version boards and
  zero missing expected current boards.
- The same 52 terminal sessions and 25 settled rewards; no pending/quarantined
  settlement, invalid selection or profile-consistency mismatch.
- The account still has 3,284 gold; the reset's field-by-field readback also
  proved the unchanged 400 XP and progression/history fields.

The baseline was verified at 23:47:55 UTC. Live `main.dart.js` SHA-256 matches
the prepared file:
`7f9ad8f7fe5075a60bc8e76ec2393d9baff1b60c31939294040c6db9ae6b5ff0`.
Final inventory is preserved as `inventory-final.json`; the frozen checkout
remains clean. No ticket was cancelled during this release.

## Acceptance limits

No phone installation or signed-in native gameplay, replay, settlement,
leaderboard or ghost smoke has been performed for this candidate. Historical
phone evidence is not acceptance for this source. The
[release checklist](../building/android_beta_release.md) retains broader
staging/production and Play acceptance work.
