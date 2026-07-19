# Functions Safety Monitoring Rollout — July 19, 2026

## Scope and result

The remaining technical monitoring gates for F-05 and F-06 were implemented
and deployed directly to `rpg-runner-d7add` under the approved no-staging,
pre-launch waiver.

This rollout added:

- structured account-deletion repair health and failure telemetry;
- three account-deletion policies;
- structured App Check, quota, active-session, upload-grant, and retention
  telemetry;
- four privacy-safe log-based metrics;
- twelve callable/resource/cost-pressure policies.

All 29 production policies are enabled and reference the previously verified
email channel:

`projects/rpg-runner-d7add/notificationChannels/12624621645792006468`

The original audit remains unchanged.

## F-05 account-deletion monitoring

The repair query now processes the oldest active requests first through the
source-controlled `state` plus `requestedAtMs` composite index:

`projects/rpg-runner-d7add/databases/(default)/collectionGroups/account_deletion_requests/indexes/CICAgNi4o4sK`

The index reached `READY` before the new worker revision was exposed.

Every one-minute repair heartbeat contains:

- bounded `scannedCount` and `activePageSaturated`;
- `processedCount`, `retryableCount`, and `retryableBacklogCount`;
- `oldestActiveAgeMs` and `oldestActiveStage`;
- `maxAttemptCount`;
- expired completion-record deletions.

The heartbeat contains no account identifier. A retryable stage failure logs a
16-character SHA-256 UID hash, stage, attempt count, and error class; raw UID is
not logged.

Deployed policies:

| Policy | Resource |
| --- | --- |
| Account deletion repair runtime error | `projects/rpg-runner-d7add/alertPolicies/9915250908376911832` |
| Account deletion retryable failure | `projects/rpg-runner-d7add/alertPolicies/7279932697223424047` |
| Account deletion stalled or excessive attempts | `projects/rpg-runner-d7add/alertPolicies/7279932697223422272` |

The stalled condition fires when the oldest incomplete request is at least six
hours old or the selected page contains an attempt count of at least 400. Six
hours intentionally exceeds the normal multi-board repeated-reconciliation
window.

Production heartbeat evidence from
`accountdeletionrepair-00007-quf` reported zero scanned, retryable, or
saturated work. A clearly synthetic event with test ID
`account-deletion-alert-20260719-183451` matched the exact deployed retryable
filter without creating or modifying Auth, Firestore, Storage, or deletion
state.

## F-06 callable and resource monitoring

### Metrics

The deployed log metrics define no extracted labels:

| Metric | Signal |
| --- | --- |
| `backend_app_check_gaps` | Firebase callable verification summary with App Check `MISSING` or `INVALID` |
| `backend_callable_requests` | Callable requests reaching the Firebase verification summary |
| `backend_replay_finalize_attempts` | Quota-charged replay finalize attempts; exact bytes remain in each decision log |
| `backend_signed_url_attempts` | Accepted upload-grant or ghost-download decisions proceeding toward signer work |

### Policies

| Policy | Resource |
| --- | --- |
| Active run resource saturation | `projects/rpg-runner-d7add/alertPolicies/14286588604515721084` |
| App Check missing or invalid burst | `projects/rpg-runner-d7add/alertPolicies/14916044669191410507` |
| Functions backend HTTP 5xx | `projects/rpg-runner-d7add/alertPolicies/1092412443040483675` |
| Abuse-control configuration invalid | `projects/rpg-runner-d7add/alertPolicies/11705784995281661340` |
| Callable request cost surge | `projects/rpg-runner-d7add/alertPolicies/6026479110518669348` |
| Enforced callable quota rejection | `projects/rpg-runner-d7add/alertPolicies/581142251056059646` |
| Quota retention cleanup page saturated | `projects/rpg-runner-d7add/alertPolicies/16349107987037390531` |
| Replay finalize attempt pressure | `projects/rpg-runner-d7add/alertPolicies/581142251056061976` |
| Signed URL request pressure | `projects/rpg-runner-d7add/alertPolicies/6939179286526940048` |
| Replay Storage API pressure | `projects/rpg-runner-d7add/alertPolicies/14916044669191410866` |
| Replay task attempt pressure | `projects/rpg-runner-d7add/alertPolicies/10665869516446735147` |
| Backend transaction contention | `projects/rpg-runner-d7add/alertPolicies/16019483062439044193` |

The principal pre-launch volume thresholds are:

- more than 20 missing/invalid App Check summaries in 15 minutes;
- more than 5,000 callable summaries in 15 minutes;
- more than 64 replay finalize attempts in 15 minutes;
- more than 500 accepted signed-URL attempts in 15 minutes;
- more than 1,000 replay-bucket API operations in 15 minutes;
- more than 1,000 Cloud Tasks attempts in 15 minutes.

Any enforced quota rejection, invalid abuse configuration, active-resource
saturation, backend 5xx, or recognized transaction-contention error has
immediate policy coverage. A quota cleanup page of 200 also alerts.

Existing source-controlled replay-validator policies continue to cover
validation/projection queue backlog, retry activity, validator 5xx, resource
rejections, probes, and memory. The new task-attempt policy adds volume/cost
pressure rather than duplicating those latency and recovery policies.

These are operational resource/cost proxies, not a currency-denominated Cloud
Billing budget. Thresholds must be reviewed after at least seven days of
organic traffic.

## Production deployment

The final Functions source/configuration hash is:

`a0e9f8ecfd9afba9d89c8e1cfa7ce24a36f1c48b`

All targeted functions are `ACTIVE`:

| Function | Revision |
| --- | --- |
| `abuseQuotaRetentionCleanup` | `abusequotaretentioncleanup-00002-saw` |
| `accountDelete` | `accountdelete-00013-sov` |
| `accountDeletionRepair` | `accountdeletionrepair-00007-quf` |
| `ghostLoadManifest` | `ghostloadmanifest-00010-loy` |
| `leaderboardLoadActiveBoardData` | `leaderboardloadactiveboarddata-00010-tob` |
| `leaderboardLoadBoard` | `leaderboardloadboard-00010-bor` |
| `leaderboardLoadMyRank` | `leaderboardloadmyrank-00010-neg` |
| `loadoutOwnershipExecuteCommand` | `loadoutownershipexecutecommand-00010-qik` |
| `loadoutOwnershipLoadCanonicalState` | `loadoutownershiploadcanonicalstate-00008-rod` |
| `playerProfileLoad` | `playerprofileload-00008-veg` |
| `playerProfileUpdate` | `playerprofileupdate-00008-wuk` |
| `runBoardsLoadActive` | `runboardsloadactive-00010-vil` |
| `runSessionCreate` | `runsessioncreate-00010-mog` |
| `runSessionCreateUploadGrant` | `runsessioncreateuploadgrant-00010-xeh` |
| `runSessionFinalizeUpload` | `runsessionfinalizeupload-00010-lim` |
| `runSessionLoadStatus` | `runsessionloadstatus-00008-paf` |

`ABUSE_CONTROL_MODE=enforce` remains live. No explicit
`APP_CHECK_ROLLOUT_MODE` environment value is set, so the reviewed source
default remains `monitor`.

A harmless unauthenticated call to the new
`loadoutownershiploadcanonicalstate-00008-rod` revision returned the expected
HTTP 401 and emitted structured evidence:

- SDK verification: App Check `MISSING`, Auth `MISSING`;
- application observation: rollout `monitor`, token status
  `missing_or_invalid`.

The quota-retention worker emitted a structured zero-scan heartbeat, and the
deletion-repair worker emitted a structured zero-work heartbeat. No
error-severity Cloud Run entry was found after the rollout.

Cloud Monitoring then exposed one point from the harmless probe in both
`backend_app_check_gaps` and `backend_callable_requests`, proving metric
ingestion as well as log shape.

A synthetic event with test ID `quota-alert-20260719-185201` matched the exact
deployed enforced-rejection condition without consuming quota or touching user
state.

The two real-policy synthetic events prove Logging acceptance and exact filter
selection. End-to-end email delivery for this same channel was already
confirmed by the isolated exact-ID test in the
[alert-channel record](alert-channel-confirmation-2026-07-19.md); this document
does not claim a second human receipt confirmation.

## Validation

- `corepack pnpm --dir functions build`: passed.
- Focused deletion/abuse emulator suites: 21/21 passed.
- `corepack pnpm --dir functions test`: 172/172 passed.
- All four log metrics were created and list with `DELTA`/`INT64`
  descriptors.
- App Check gap and callable request metrics each ingested the expected single
  production probe.
- All fifteen new policies list as enabled on the verified channel.
- All 16 targeted functions deployed successfully with zero deployment errors.

## Remaining launch gates

This rollout closes the technical deletion-alert and
rejection/storage/task/cost-alert tasks. It does not close:

- public disclosure of compact deletion evidence and its 30-day maximum;
- owner/legal selection and documentation of the applicable lawful basis;
- release attestation measurements for Android, iOS, macOS, and any other
  in-scope Firebase platform, or explicit release exclusion;
- global App Check enforcement after those platform gates pass;
- a longer organic latency, backlog, rejection, and resource-cost observation
  window;
- a billing-account-owned currency budget, if the owner wants a monetary
  threshold in addition to these project resource proxies.
