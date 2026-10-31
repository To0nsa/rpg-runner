# Reward latency on the connected phone, October 31, 2026

Two live Competitive Forest runs completed on dev. The first account update
painted 12.569 seconds after run end; the second painted after 4.382 seconds.
Three serial callable cold starts dominate the first result. Queue dispatch and
replay computation were short in both samples. Gold and XP share verification,
settlement and canonical refresh; XP then adds its count-up animation.

This is a two-run diagnosis, not a p95 result or a controlled cold/warm benchmark.
The capture is stopped. No build, deployment, navigation generation, account
reset or administrative reward mutation was performed for this measurement.

## Measured identity and scope

- Dev only: `rpg-runner-d7add`, `europe-west1`.
- OnePlus CPH2465, Android 15/API 35; `com.example.rpg_runner.dev`, version
  `1.0.0-dev`, code **4**. On-device APK SHA-256 matched
  `aec3ccd3a4bd89eba5733109d4b92661b95c8d0700b5cd9d85d8d805fa9e19a0`.
- APK/Functions candidate: `8a094efb67a9f8e988940206c73b830765142248`, source
  digest `d74764d48e162314e48072d2a91474eb54776ab29f427b14c4556d1e13c878ba`.
  This is the [achievements release](achievements-dev-2026-10-30.md), which
  includes the diagnostics; it supersedes diagnostic APK 3 for this capture.
- All 32 Functions were ACTIVE. The saved live inventory's release identity
  `fa4c9545e12c7079f63a4b002cc6e37445217ec90e030fb1c2b743901cb52d8c`
  matches that release's verified baseline. Latest update: October 30,
  20:35:53.891737871 UTC.
- Worker `replay-validator-00063-thr`, Ready, 100% traffic, immutable image
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:45d6d0a00fe563464c9ca9ab89748bad7befad18ee8f53d073013a8fbf23908e`.
  The release reused the previously benchmarked image and navigation artifacts.
- Tuple: `2026.10.21 / rules-v2 / score-v4 / ghost-v1`. Both runs used Forest
  seed `1884823297`, 60 Hz, and ended by falling into a gap.

| Sample | A: cold callables | B: same callable instances warm |
| --- | --- | --- |
| Run ID | `run_20bb500088910ee54425242963845f99a116f28b` | `run_9f1318c8fb5de4b5f62956fccc9b03638b60ad38` |
| Recorded ticks | 353 | 2,099 |
| Validated score | 245 | 2,165 |
| Gold / XP awarded | 0 / 1 | 11 / 10 |
| Compressed replay bytes | 7,737 | 41,752 |
| Canonical revision applied | 17 | 18 |

The zero-gold first run confirms account revision/XP presentation, not receipt of
new gold. Its gold target observation paints the unchanged wallet value.

## Client timeline

All entries below are cumulative seconds from `run_end`, using the same client
monotonic clock, `hnpwqt4nlv`. Each run has a complete correlated stage chain.

| Stage completed | A | B |
| --- | ---: | ---: |
| Replay encoded, compressed and saved | 0.046 | 0.039 |
| Durable submission journal | 0.055 | 0.049 |
| Upload grant received | 3.698 | 1.419 |
| Replay upload completed | 4.016 | 1.848 |
| Finalize response received | 8.131 | 2.614 |
| Canonical account applied | 12.542 | 4.351 |
| Account revision painted; XP catch-up starts | 12.569 | 4.382 |
| XP final integer painted | 13.162 | 5.323 |

Individual client operation durations, milliseconds (do not add these to the
cumulative rows above):

| Operation | A | B |
| --- | ---: | ---: |
| Upload-grant call | 3,638.859 | 1,337.194 |
| Replay transfer | 304.953 | 420.324 |
| Finalize call | 4,099.146 | 753.707 |
| Finalize response to first status-call start | 1,024.361 | 1,033.396 |
| Status call | 3,016.496 | 373.476 |
| Canonical account fetch | 367.634 | 329.023 |
| First XP paint to final XP integer | 593.464 | 941.111 |

The roughly one-second status scheduling gap overlaps server validation and
settlement. Removing it would not necessarily save a full second. Canonical
application to first account paint took only 26–31 ms in the visible hub.

## Queue, validation and settlement

| Stage, milliseconds | A | B |
| --- | ---: | ---: |
| Finalize transaction acknowledgement span | 168.266 | 98.032 |
| Validation enqueue RPC | 289.680 | 221.426 |
| Cloud Tasks creation log to first dispatch log | 6.958 | 10.024 |
| Validation lease acquisition | 225.900 | 233.840 |
| Replay download/decode parent span | 63.886 | 73.455 |
| Replay computation, including Core setup/scoring | 148.817 | 168.228 |
| Simulation tick loop, within computation | 9.004 | 122.720 |
| Archive account fence | 89.657 | 51.557 |
| Replay archive | 59.043 | 55.878 |
| Accepted-result handoff commit | 282.563 | 230.946 |
| Worker lease entry to handoff completion | 870.568 | 814.404 |
| Winning settlement transaction | 587.798 | 338.365 |
| Durable finalize commit to durable settlement commit | 1,885.312 | 1,449.600 |

Durations inside processes are monotonic. Cloud Tasks rows use platform
timestamps and describe creation-to-dispatch only, excluding enqueue RPC and
worker entry. Finalize-to-settlement uses Firestore grant document
`createTime`/`updateTime`, not application `finalizedAtMs`/`settledAtMs` markers.
Parent spans include children and must not be summed with them.

Both validation tasks dispatched once, succeeded, and accepted on attempt 1.
The same validation worker instance served both runs; no worker startup appears
in the capture window. Sample A must not be labelled a cold-worker benchmark.

Eventarc won settlement in both cases, at 08:30:52.750735 and 08:31:41.670671 UTC
(Firestore commit timestamps). The immediate endpoint returned `already_settled`
afterward. Its worker request spans were 3,031.619 and 1,283.742 ms; these are
not the time until rewards first existed. The second immediate transaction
needed two attempts, then observed the existing grant. It did not pay again.

## Why sample A was slower

Cloud Run system and request logs associate new instances with the first
upload-grant, finalize and status calls. Each startup window runs from the
`Starting new instance` event to the successful startup probe:

| Callable | A startup window, ms | A client call, ms | B client call, ms |
| --- | ---: | ---: | ---: |
| `runSessionCreateUploadGrant` | 2,268.590 | 3,638.859 | 1,337.194 |
| `runSessionFinalizeUpload` | 2,357.570 | 4,099.146 | 753.707 |
| `runSessionLoadStatus` | 2,265.748 | 3,016.496 | 373.476 |

The three sequential startup windows total 6.892 seconds. Sample B requests
use the exact same instance IDs with no intervening startup. Application
handler spans exclude startup: grant 994/1,227 ms, finalize 1,406/628 ms, and
status 453/276 ms. Network, platform/auth entry and response overhead also
contribute to client-call durations; they must not all be called startup.

The immediate settlement service also started cold (2,350.011 ms) for A, but
Eventarc had already settled the account before it entered the transaction.
Adding this startup to the three client-call windows would overstate the
player's critical path. Projection tasks are separate from reward settlement.

For these samples, reducing serial callable startup and account-refresh latency
is the next performance investigation. Replay computation is already below
0.17 seconds. A seamless pending-reward presentation is a separate UX decision;
these measurements do not authorize provisional spendable gold or XP.

## Correctness, reproduction and limits

Read-only account observations and hub screenshots agree: gold 3,149 → 3,160;
total XP 132 → 143; level 2 progress 32/124 → 43/124; accepted runs 9 → 11;
revision 16 → 18. XP awards match `floor(validatedScore / 200)`. Both grant IDs
occur exactly once in canonical applied grants. Both grants are
`validated_settled`; no client failure or unpaired diagnostic span was found.

Capture ran 08:28:21.686–08:32:35.163 UTC, with the app process unchanged at PID
1913. It used finite app-only logcat, no continuous screenshots or video, and
before/after hub screenshots. Five clock probes put the phone roughly 1.16 s
behind the host, with 80–109 ms round trips. Client/server UTC subtraction is
therefore unsuitable for precise end-to-end durations. Server cross-process
ordering uses wall-clock correlation; client end-to-end results use one clock.
Paint events are Flutter post-paint callbacks, not GPU/human-attention timestamps.

Local evidence: `.tmp/reward-latency-live-20261031/`. `app-logcat.txt` supplies 68
client events; `backend-events-both.json` supplies 92 backend events.
`backend-platform.json` contains the bounded platform request/startup/task
lookup. `baseline-documents.json` and `backend-documents.json` retain whitelisted
read-only observations. `ready-screen.png` and `final-hub.png` show account totals.
`analysis.json` records computed values and SHA-256 hashes of evidence/helpers.

Commands run from the repository root:

```powershell
python .tmp/reward-latency-live-20261031/report.py .tmp/reward-latency-live-20261031/app-logcat.txt .tmp/reward-latency-live-20261031/backend-events-both.json
python .tmp/reward-latency-live-20261031/analyze.py
```

Both passed: 80 unique events per run, zero duplicate-identity conflicts, all
spans complete, and matching once-only account deltas. The Cloud Logging read
used explicit `timestamp >= 2026-10-31T08:30:00Z` and
`timestamp < 2026-10-31T08:33:00Z`, ascending order, dev project, both exact run
IDs and `jsonPayload.event="run_reward_timing"`. A separate read in that window
selected Cloud Run requests/system logs and Cloud Tasks logs. These are live
observations; the report analysis is local, not a new replay or synthetic test.

Only two short runs on one route/device/network were observed. No full-run,
boss, level-up, offline/retry, app-background recovery or achievement-claim
acceptance is established. No p95 or before/after optimization claim is made.
Broader acceptance remains in the
[active latency checklist](../building/reward_verification_latency.md).
