# Reworked reward pipeline on the phone, October 31, 2026

Two live Competitive Forest runs completed on dev APK 5. Verified gold painted
4.505 seconds after run end with a cold replay worker, then 2.356 seconds with
the same worker warm. Both runs received gold and XP atomically, applied the
grant once, and consumed the confirmed completion receipt without status polling
or another canonical-account fetch. Existing presentation was retained.

These are two diagnostic samples, not a p95 or a controlled performance
benchmark. Both captures are stopped. No build, navigation generation, deployment,
administrative reward mutation or artificial warming was performed for this
measurement.

## Identity and scope

- Dev project `rpg-runner-d7add`, region `europe-west1`.
- OnePlus CPH2465, Android 15/API 35, `com.example.rpg_runner.dev`, version
  `1.0.0-dev`, code **5**. On-device APK SHA-256 matched
  `2b8398299f706db3ba1f976da458e8ee7d84e722bc8e75091914b05e661ee10a`.
- Candidate `259786236b61a867c9edccbe1d74679c20c2459a`, source digest
  `64a27017431e8f8456c236e6ef2eba8f30f719c283cd27a36639470275137c8f`;
  see the [dev rollout record](reward-pipeline-dev-2026-10-31.md).
- Read-only live identity verification at 16:25:05 UTC matched all 35 ACTIVE
  Functions to the verified deployment. Worker `replay-validator-00064-nxw`
  served 100% of traffic from image
  `europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:549581d0ca927054c1c9f39544876c80d127dd1bd8654fb4d769f2d1fe7051a1`.
- Tuple `2026.10.21 / rules-v2 / score-v4 / ghost-v1`; Forest seed
  `1884823297`, 60 Hz. Both runs ended by falling into a gap.
- Selected setup: Competitive / Val Outpost / Éloïse / Build 1. App PID 25811
  and client monotonic clock `hnq9vfh5qb` remained the same across captures.

| Sample | A: cold worker | B: same services warm |
| --- | --- | --- |
| Run ID | `run_228d0c158bff87837d29aed276780e96c9f2485c` | `run_48a04352cb68b5b6bee2d8db66e0d8b721d42293` |
| Recorded ticks | 1,899 | 1,034 |
| Validated score | 1,735 | 1,090 |
| Gold / XP awarded | 9 / 8 | 5 / 5 |
| Compressed replay bytes | 35,429 | 20,712 |
| Account revision | 18 → 19 | 19 → 20 |

## Run end to visible update

All values are cumulative seconds from client `run_end`, measured on that
client's monotonic clock. They must not be added together.

| Stage completed | A | B |
| --- | ---: | ---: |
| Replay encoded, compressed and saved | 0.063 | 0.023 |
| Durable local submission journal | 0.070 | 0.029 |
| Prepared upload grant reused | 0.089 | 0.044 |
| Replay upload completed | 0.452 | 0.339 |
| Finalize response received | 1.488 | 1.167 |
| Confirmed completion received | 4.486 | 2.335 |
| Canonical account applied | 4.489 | 2.339 |
| Local receipt acknowledged | 4.493 | 2.343 |
| Gold target painted | 4.505 | 2.356 |
| First XP frame for the new revision | 4.505 | 2.838 |
| XP final integer painted | 5.421 | 3.689 |

In A, gold and XP first painted in the hub. In B, gold first painted on Game
Over; XP first painted after returning to the hub. The additional 0.482 seconds
between B's gold and XP observations therefore spans different presentation
surfaces, not a second XP settlement. XP count-up from its first observed frame
to its final integer took 0.916 seconds in A and 0.850 seconds in B.

Gold, XP and account revision arrived together in each completion receipt.
Canonical application to first gold paint took 16–17 ms. Frame observations
require the foreground/current route and exact canonical revision/target; they
are Flutter post-paint evidence, not GPU timestamps or proof of human attention.

Upload permission was prepared during real run activity. The client call took
3,627.760 ms in A and 666.932 ms in B, completing approximately 76.122 and
18.774 seconds before the respective run ended. Neither grant call was on the
post-run path. Individual replay transfers took 360.125/292.213 ms and finalize
calls took 1,027.209/819.916 ms. Both traces contain zero `status_poll` and zero
`canonical_fetch` events.

## Backend work and instance reuse

| Stage, milliseconds | A | B |
| --- | ---: | ---: |
| Finalize handler | 907.742 | 724.369 |
| Finalize transaction acknowledgement | 152.302 | 133.311 |
| Validation enqueue RPC | 290.945 | 216.505 |
| Cloud Tasks creation log to first dispatch log | 8.516 | 6.566 |
| Validation lease acquisition | 252.440 | 361.126 |
| Replay download/decode parent span | 111.955 | 58.955 |
| Replay computation, including Core setup/scoring | 141.111 | 55.652 |
| Simulation loop, within computation | 79.191 | 23.331 |
| Archive account fence | 74.764 | 73.147 |
| Replay archive | 57.556 | 51.619 |
| Accepted-result handoff commit | 275.595 | 210.570 |
| Worker lease entry to handoff completion | 913.961 | 811.665 |
| Settlement transaction acknowledgement | 728.476 | 324.891 |
| Durable finalize commit to durable settlement commit | 3,426.944 | 1,469.424 |
| Durable handoff commit to durable settlement commit | 995.424 | 396.752 |

Parent spans include children; summing them would double-count work. Queue
figures use Cloud Tasks log timestamps and exclude enqueue RPC, startup and
application entry. Durable intervals use Firestore document commit timestamps,
not the application's `finalizedAtMs` or `settledAtMs` markers. Client/server UTC
clocks are never subtracted to estimate end-to-end latency.

Platform logs establish the following:

- A's `runSubmission` instance started during grant preparation: 1,632.081 ms
  from the new-instance log to the successful probe. The finalize request used
  that same instance. This startup occurred before run end.
- A's replay worker started after task dispatch: 1,145.609 ms to the successful
  startup probe. This was on the post-run path. A is not a completely cold
  backend: the Eventarc settlement instance was already running.
- B reused the exact same submission, replay and Eventarc settlement instance
  IDs as A. No startup appears in B's bounded platform window.
- Both validation tasks dispatched once, returned success, and accepted on
  attempt 1. Eventarc settled both runs in one transaction attempt. No immediate
  HTTP settlement request occurred; the worker's very short disabled-dispatch
  bookkeeping span is not an HTTP latency measurement.
- Leaderboard and projection startup occurred in A, but those operations did
  not gate the reward receipt. B's projection was also separate from settlement.

The [earlier APK 4 samples](reward-latency-phone-2026-10-31.md) painted their first
account update at 12.569/4.382 seconds. The new traces demonstrate grant reuse,
shared submission instances and direct receipt consumption. They do not isolate
the speedup of each change: replay lengths, visible surfaces and cold services
differ. In particular, the old first sample had cold serial callables and a warm
worker; new A had its submission startup during play and a cold worker afterward.

## Correctness and recovery scheduling

Read-only document checks verified accepted validation, settled grants, one
applied grant ID per run, exactly one revision/accepted-run increment, and these
account totals:

| Check | Before | After A | After B |
| --- | ---: | ---: | ---: |
| Gold | 3,160 | 3,169 | 3,174 |
| Total XP | 143 | 151 | 156 |
| Accepted runs | 11 | 12 | 13 |
| Account revision | 18 | 19 | 20 |

For each run, receipt creation/update, grant update and account update share the
same Firestore commit timestamp: A `16:28:32.972111Z`, B `16:35:12.385583Z` on
October 31. Receipt schema 1 contains validated status and the matching full
canonical revision/gold/XP. This verifies the atomic result for these samples;
it does not replace deliberate duplicate-delivery or response-loss tests.

The intended delayed recovery task for each run was found by recomputing its
deterministic ID from `[work, "initial"]`. Both target private `runPendingWork`
with the run-control service account and a 120-second dispatch deadline,
scheduled at `16:43:29.738Z` and `16:50:11.009Z`. Enqueue is verified; delivery
and repair of an intentionally interrupted run were not exercised in this capture.

The first final-hub screenshot independently showed gold 3,169 and level 2 XP
51/124. The phone disconnected before the second final screenshot could be
captured. B's complete timing events and server records were already saved.
Later background/network warnings in B's app log occur after terminal paint;
they are not a pending-submission recovery test.

## Reproduction and remaining acceptance

Working directory: `C:\dev\rpg_runner`. Local raw evidence is ignored under
`.tmp/reward-pipeline-phone-20261031/`; B uses its `warm-run/` subdirectory.
Capture A ran 16:24:12–16:28:58 UTC; B ran 16:32:55–16:36:42 UTC.

- Existing finite `capture.py` and `report.py` were reused. Capture uses
  `adb -s 8ce90820 logcat --pid=25811 -v epoch -T 1`, with process-change
  handling, a 720-second bound and an explicit stop file. No continuous video
  or screenshots were recorded.
- `gcloud logging read --project=rpg-runner-d7add --order=asc --limit=500
  --format=json` read exact-run events and bounded platform/task windows into
  `backend-events.json` and `backend-platform.json` for each sample.
- `node <capture-dir>/observe-with-receipt.mjs <run-id>` made read-only
  Firestore reads for that run, grant, validation, receipt and ownership profile.
  Its output is `backend-documents.json`; the preceding account snapshot is
  `baseline-documents.json`. Credentials were used only in memory.
- `python <capture-dir>/report.py <capture-dir>/app-logcat.txt
  <capture-dir>/backend-events.json` produced each combined `report.json`.
  Each contains 80 correlated events (31 client, 49 backend), zero conflicting
  identities and zero unpaired spans. `python <capture-dir>/analyze-current.py`
  passed atomicity, grant, revision, task-attempt and clock assertions and
  produced `analysis.json`. Same-instance comparisons are in `comparison.json`.
- `gcloud tasks list --queue=runPendingWork --location=europe-west1
  --project=rpg-runner-d7add --limit=20` read only the whitelisted task metadata
  saved in `pending-work-tasks.json`; both expected deterministic IDs matched.

Normal live submission and reward delivery are established for these two runs.
Fresh Play Games sign-in, offline/response-loss/process-restart recovery, account
switching, deliberate delivery faults and representative long-run/cold-service
coverage remain separate acceptance checks in the
[existing workstream](../building/reward_verification_latency.md). No p95 or
general cost reduction is claimed. Reserved-instance minimums remain zero in
the verified deployment; naturally warm instance reuse required no keepalive or
billing configuration change.
