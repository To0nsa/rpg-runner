# Dev phone reward latency — October 30, 2026

Two live Competitive Forest runs were accepted on the connected OnePlus CPH2465
(Android 15/API 35), using dev APK version code 2 from source
`285ef4f491f9eef6c2ea605a7ee7d709f534a69e`. Installed APK SHA-256 was
`db378bc84ea5a6fc94ae13e56af36899826027c44ad9908eb1c9cb8f4b822f33`, matching
[the previous installation](dev-app-2026-10-29.md). Worker revision was
`replay-validator-00061-cl6`; gameplay tuple `2026.10.21 / rules-v2 / score-v4`.
This is baseline evidence before the new timing instrumentation.

The read-only capture used app-scoped logcat, approximately one screenshot per
second, Cloud Logging request/application/startup logs, and Firestore REST reads
of the two run sessions, validated runs, grants and the corresponding account.
Screen recording could not open an output file on this device, so no video was
captured. Raw local evidence is ignored under `.tmp/reward-latency-20261030/`:
`screen-events.jsonl`, `frames/`, `app-logcat.txt`, `backend-events.json`,
`backend-requests.json`, `backend-startups.json`, `backend-documents.json`.
The capture was stopped after completion. No reward/account data was modified.

| Measurement | Run A | Run B |
| --- | ---: | ---: |
| Run ID | `run_fce4386f329d85aebb8180690e5f7b005a25a60f` | `run_197e5b07bf8e9fa35463332acd8bfeb5ab102164` |
| Run ticks at 60 Hz | 358 | 2,147 |
| Replay bytes | 7,784 | 43,104 |
| Gold / XP awarded | 0 / 1 | 13 / 10 |
| Upload grant HTTP duration | 3.700 s | 0.443 s |
| Finalize HTTP duration | 4.941 s | 0.717 s |
| Durable finalize → validation lease marker | 2.775 s | 0.469 s |
| Lease marker → replay result marker | 0.317 s | 0.331 s |
| Replay result → durable accepted handoff | 0.418 s | 0.349 s |
| Durable handoff → settlement commit | 0.722 s | 0.627 s |
| Durable finalize → settlement commit | 4.232 s | 1.776 s |

Server commit boundaries use Firestore document create/update timestamps, not
the application's pre-commit `finalizedAtMs` or `settledAtMs`. The lease-to-result
interval includes lease acquisition, download/decode/checks and simulation;
pure simulation cannot be isolated from this capture. The listed intervals are
server-clock observations, not direct device/server clock subtraction.

Run A encountered correlated instance startups: grant 2.593 s, finalize 3.418 s,
validator 2.288 s, and status callable 2.597 s, measured from startup log to
successful startup probe. These explain substantial serial delay. The immediate
settlement endpoint also cold-started, but Eventarc had already committed the
payout; waiting for that endpoint was not the player's payout boundary. Parallel
leaderboard/projection startup must not be added to reward latency.

Run B's settlement committed at 16:13:59.007039 UTC. A status request completed
just before that, and the next poll led to canonical refresh completing around
16:14:01.794 UTC: approximately 2.787 s after settlement. The first screenshot
with gold 3,149 was frame 500 (host capture 16:14:01.561–02.074); XP reached
32/124 at level 2 in frame 501 (02.563–03.159). Before both runs the hub showed
3,136 gold and 21/124 XP. Total change was exactly +13 gold and +11 XP, and each
run appeared once in applied grants. No level-up threshold was crossed.

Run B's Game Over appeared in frame 494, with the previous live frame 493.
Visual Game Over → updated gold was approximately six seconds, and → completed
XP display approximately seven seconds. Conservative screenshot interval bounds
are 4.420–7.506 s and 5.413–8.591 s respectively. Phone time was about 0.95 s behind
the host; subsecond host/server alignment is not established. Screenshot and
capture overhead was not measured. Run A immediately restarted into Run B, so
there is no independent visible-completion measurement for A.

Both runs settled on their first validation attempt, with immediate/Eventarc
duplicate delivery converging correctly. Two short, different-length runs are
not p95 evidence, exhaustive cold/warm coverage or representative long-run
performance. Local saving, upload, pure queue wait and pure simulation remain
unseparated. The [active workstream](../building/reward_verification_latency.md)
adds explicit stage timing before the next controlled phone capture.
