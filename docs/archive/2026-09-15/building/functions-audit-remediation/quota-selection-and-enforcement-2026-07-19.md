# Quota Selection and Enforcement Evidence — July 19, 2026

## Scope and authorization

The repository owner authorized direct production rollout because no staging
project exists and the game is not live. This record covers per-UID callable
quota selection, isolated emulator load validation, monitor-mode production
canarying, and production enforcement. App Check remained in `monitor` mode.

The policy is source-controlled in `functions/src/abuse/quota.ts`; production
uses `ABUSE_CONTROL_MODE=enforce`. Route-specific environment variables remain
available as reviewed overrides. Invalid overrides fail closed in enforcement
mode and fall back to the reviewed default with an error log in monitor mode.

## Measurement baseline

Before selecting limits, seven days of available production telemetry contained
only controlled synthetic traffic:

| Route | Decisions | Synthetic identities | Maximum burst | Maximum sustained | Maximum single units |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ownership_command` | 2 | 2 | 1 | 1 | 1 request |
| `run_create` | 9 | 3 | 3 | 3 | 1 request |
| `upload_grant` | 5 | 3 | 2 | 2 | 1 request |
| `finalize_replay_bytes` | 5 | 3 | 27,880 bytes | 27,880 bytes | 27,880 bytes |
| `leaderboard_read` | 5 | 3 | 2 | 2 | 1 request |
| `ghost_url` | 2 | 2 | 1 | 1 | 1 request |

Five active-session observations had a maximum existing count of one. Five
active-upload-grant observations had a maximum existing count of zero. These
are controlled-client measurements, not an organic player distribution.
Limits therefore also use protocol and retry bounds, with deliberately large
margins over the observed client.

## Selected production policy

Windows remain fixed at one minute and 24 hours:

| Route | One-minute burst | 24-hour sustained | Rationale |
| --- | ---: | ---: | --- |
| `ownership_command` | 120 requests | 5,000 requests | Allows rapid UI edits and offline-outbox retries while bounding idempotency and transaction growth. |
| `run_create` | 20 requests | 300 requests | Allows prefetch/idempotent retries and intensive play while bounding ticket and board work. |
| `upload_grant` | 20 requests | 300 requests | Allows grant retries for every permitted run without unbounded signed-URL creation. |
| `finalize_replay_bytes` | 32 MiB | 1 GiB | Allows four 8 MiB maximum-size finalize attempts per minute and 128 maximum-size attempts per day. |
| `leaderboard_read` | 120 requests | 5,000 requests | Allows refreshes and combined board/rank UI reads while bounding projected-view reads. |
| `ghost_url` | 30 requests | 1,000 requests | Allows repeated ghost selection while bounding signed download URLs. |

Active resources are limited to:

- 32 non-terminal run sessions per UID;
- eight unexpired upload grants per UID.

Run tickets last 24 hours, so the active-session limit is intentionally above
normal prefetch and abandoned-run measurements. Upload grants are shorter
lived, so eight permits retries and parallel recovery without exposing the
128-document scan cap.

No looser anonymous-account policy was added. The release authentication
contract requires Play Games, while anonymous Auth is used only by controlled
canaries. Anonymous identities receive the same per-UID limits. Account churn
can evade any per-UID limit, so App Check enforcement and project-level Google
Cloud safeguards remain necessary defense layers rather than reasons to make
anonymous traffic privileged.

## Isolated validation

- Functions TypeScript build: passed.
- Complete Firestore emulator suite: 170/170 passed.
- A 40-attempt run-create boundary executed in five-request concurrent waves:
  exactly 20 accepted and 20 returned `resource-exhausted`.
- Four 8 MiB replay finalizations were accepted in one minute; the fifth
  returned `resource-exhausted`.
- Explicit active-session and active-upload-grant atomic enforcement tests
  passed.
- Malformed enforcement overrides returned `failed-precondition`.

An initial intentionally harsh shape launched all 40 same-UID transactions at
once. The Firestore emulator produced transaction lock timeouts before every
request could reach a clean quota decision, and that first suite run failed.
The realistic five-request waves passed. This establishes normal-client and
moderate contention behavior; it does not claim that an abusive 40-way same-UID
fan-in receives only `resource-exhausted`. Such fan-in may also receive
Firestore contention errors and should be covered by operational error alerts.

## Production rollout

The nine quota-bearing callables were first deployed with source-controlled
limits and `monitor` mode. Source hash:

`168b0ecf764c429161465e17551f2030a2071754`

A complete authenticated canary then emitted 11 decisions across all six
routes. All were accepted in monitor mode and none had `wouldReject: true`.
The canary completed valid and invalid replay paths and requested deletion.

The same nine Functions were then redeployed with
`ABUSE_CONTROL_MODE=enforce`. Final source/configuration hash:

`47bfddc5836917610b6d27ac2802dbbed8c42aa1`

| Function | Enforced revision |
| --- | --- |
| `loadoutOwnershipExecuteCommand` | `loadoutownershipexecutecommand-00009-qur` |
| `runBoardsLoadActive` | `runboardsloadactive-00009-vos` |
| `runSessionCreate` | `runsessioncreate-00009-woy` |
| `runSessionCreateUploadGrant` | `runsessioncreateuploadgrant-00009-tah` |
| `runSessionFinalizeUpload` | `runsessionfinalizeupload-00009-mit` |
| `leaderboardLoadBoard` | `leaderboardloadboard-00009-tiq` |
| `leaderboardLoadMyRank` | `leaderboardloadmyrank-00009-bet` |
| `leaderboardLoadActiveBoardData` | `leaderboardloadactiveboarddata-00009-vek` |
| `ghostLoadManifest` | `ghostloadmanifest-00009-hed` |

All nine reported `ACTIVE`, 100% latest-revision traffic, and
`ABUSE_CONTROL_MODE=enforce`.

The enforcement canary emitted 11 decisions:

- all 11 had mode `enforce`;
- all 11 were accepted;
- zero had `wouldReject: true`;
- all six quota routes were represented;
- valid replay, invalid replay, exactly-once reward, leaderboard, ghost, and
  account-deletion request behavior passed.

The controlled enforcement canary used synthetic UID hash
`fb00f59b1754133a`. Its exact UID and tokens were not recorded here.

## Later source coverage

This July 19 evidence covers only the six routes in the tables above. Later
source changes added quota routes for canonical-state reads, profile reads and
writes, account-deletion requests, and run-status polling. Those routes must
be deployed in monitor mode, observed with a complete authenticated canary,
and then redeployed with enforcement before this historical production record
can be extended to cover them.

The account-deletion route is deliberately counted even after its deletion
tombstone exists. This preserves idempotent status recovery for a recently
authenticated caller while retaining a small per-UID limit.

## Rollback and remaining operations

The safe rollback is to change `ABUSE_CONTROL_MODE` to `monitor` in the
project-specific Functions environment and redeploy the nine callables. This
retains counting and `wouldReject` telemetry while removing quota rejection.
It does not weaken Auth, UID authorization, request bounds, active deletion
guards, or App Check monitoring.

Enforcement is production-verified for controlled normal-client traffic.
Alerting on actual quota rejection and Firestore transaction errors remains the
next operational item. Organic player distributions should be reviewed after
launch; a future limit change requires new measurements, source/documentation
updates, the emulator boundary suite, and a monitor-mode canary before
enforcement.
