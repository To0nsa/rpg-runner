# Functions Remediation Live Configuration Baseline — July 18, 2026

## Scope and handling

This is a read-only, non-secret deployment record for the Firebase Functions
audit remediation plan. It records resource identity and security-relevant
configuration without copying environment values, IAM member identities,
credentials, logs, or user data into the repository.

Project inspected: `rpg-runner-d7add`.

No deployment, configuration change, IAM change, data mutation, log export, or
repair was performed while collecting this record.

## Functions and Cloud Run

- 21 second-generation Firebase Functions are active in `europe-west1`.
- All 21 Functions report the Node.js 24 runtime.
- The deployed Functions were last updated around
  `2026-07-18T20:26:21Z` through `2026-07-18T20:26:33Z`.
- The separate `replay-validator` Cloud Run service is ready at revision
  `replay-validator-00020-ps7`.
- Fourteen Firebase callable HTTP services have a public Cloud Run invoker
  binding. This is the expected transport exposure for Firebase callables;
  authentication, UID matching, and domain authorization remain application
  requirements.
- Scheduled/internal services and the replay validator do not have a public
  invoker binding.
- The deployed `runSessionCreate` environment contains the existing replay,
  migration, and Firebase runtime keys. It does not contain `APP_CHECK_*` or
  `ABUSE_*` keys, confirming that the remediation rollout configuration is not
  live.

The earlier audit baseline remains the source for exact callable revision names
and deployed source hash. This record does not claim that the current dirty
local source exactly matches any deployed revision.

## Tasks, schedules, and Eventarc

Two Cloud Tasks queues are running in `europe-west1`:

| Queue | Dispatches/second | Concurrent dispatches | Max attempts |
| --- | ---: | ---: | ---: |
| `replay-validation` | 50 | 20 | 100 |
| `replay-projection` | 50 | 20 | 100 |

Four Firebase scheduler jobs exist in `europe-west1`, all using `Etc/UTC`:

| Job | Schedule | State |
| --- | --- | --- |
| `runSubmissionCleanup` | Every 60 minutes | Enabled |
| `runSettlementRepair` | Every 5 minutes | Enabled |
| `runLegacyRewardGrantMigration` | Every 5 minutes | Paused |
| `leaderboardBoardMaintenance` | Every 60 minutes | Enabled |

Two Firestore Eventarc triggers exist in the Firestore multi-region `eur3`:

- `runProjectionOnAccepted` watches
  `validated_runs/{runSessionId}` document writes.
- `runSettlementOnHandoff` watches
  `run_sessions/{runSessionId}` document writes.

Both use the existing run-control service identity. Member identities and
transport resource names are intentionally omitted here.

## Firestore

- Database: `(default)`.
- Location: `eur3`.
- Mode: Firestore Native with pessimistic concurrency.
- Point-in-time recovery: disabled.
- Delete protection: disabled.
- Version retention period: one hour.
- Deployed composite indexes reported by the CLI: none.
- Deployed field TTL policies reported by the CLI: none.

The active source file `firestore.indexes.json` defines eight composite indexes,
including the two added for per-UID active run-session and upload-grant
queries. Those indexes must be built before the corresponding Functions are
deployed or exercised in staging/production.

Quota and compact ownership-idempotency expiry are currently implemented by
bounded scheduled cleanup. A native Firestore TTL policy must not be claimed
as deployed unless a later configuration record proves it.

## Replay Storage

Bucket `rpg-runner-replay-euw1-20260312-01` reports:

- location `EUROPE-WEST1`;
- default storage class `STANDARD`;
- public-access prevention enforced;
- uniform bucket-level access enabled;
- seven-day soft-delete retention;
- no explicit bucket retention policy returned;
- no lifecycle rules returned;
- no CORS rules returned.

Signed upload/download behavior, browser CORS behavior, artifact lifecycle, and
application-driven deletion still require staging verification before release.

## Hosted Flutter Web

The live Firebase Hosting channel points at:

- release `1784321267467000`;
- version `21226b1d32302e46`;
- finalized at `2026-07-17T20:47:46.971514Z`;
- released at `2026-07-17T20:47:47.467Z`;
- 254 files and 57,353,317 version bytes.

Native Android/iOS release versions are not discoverable from the inspected
Firebase/GCP resources. They remain an external Play Console/App Store release
inventory task.

## Deployment prerequisites exposed by this baseline

1. Build all source-defined composite indexes before deploying Functions that
   rely on them.
2. Keep `APP_CHECK_ROLLOUT_MODE` and `ABUSE_CONTROL_MODE` in monitoring until
   platform and normal-client telemetry has been reviewed.
3. Do not set production quota values without measured client behavior and an
   approved rollback threshold.
4. Validate signed Storage operations and browser CORS in staging; the bucket
   currently reports no CORS policy.
5. Decide whether Firestore PITR/delete protection and bucket lifecycle are
   required operational safeguards, then record any approved configuration
   change separately.
6. Obtain native client release versions from their authoritative release
   systems before declaring the deployed baseline reproducible.
