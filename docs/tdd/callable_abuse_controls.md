# Callable Abuse Controls

## Status

Implemented and deployed on July 19, 2026. Per-UID quotas are enforced with
reviewed source-controlled defaults. App Check remains in monitoring mode. The
production web client has supplied one verified end-to-end reCAPTCHA Enterprise
attestation. Native cloud/client/device preflight is complete, but release
platforms remain unmeasured because production identity, signing,
distribution/device evidence, and explicit platform exclusions are incomplete.
Source-controlled rejection, App Check gap, transaction, retention, Storage,
task, and
resource/cost-pressure alerts are deployed to the verified production channel.
The initial production evidence, completed legacy-idempotency migration, and
web rollout are recorded in the
[Functions production verification](../building/functions-audit-remediation/production-verification-2026-07-19.md)
and
[App Check client rollout](../building/functions-audit-remediation/app-check-client-rollout-2026-07-19.md),
with native readiness details in the
[native App Check preflight](../building/functions-audit-remediation/native-app-check-readiness-2026-07-19.md)
and quota selection and enforcement in the
[quota rollout record](../building/functions-audit-remediation/quota-selection-and-enforcement-2026-07-19.md).

## Purpose and boundary

These controls reduce automated Functions, Firestore, Storage-signing, Cloud
Tasks, and read-amplification cost. They are defense in depth:

- Firebase Auth and exact UID matching remain mandatory.
- App Check does not authorize an ownership command or make client data
  authoritative.
- Quotas do not replace payload validation, revision checks, idempotency, or
  account-deletion guards.
- Direct client access to server-owned Firestore state remains denied.

The implementation lives under `functions/src/abuse/`, with domain integration
in ownership, run, leaderboard, and ghost handlers.

## App Check rollout contract

All user callable exports set Firebase Functions v2 `enforceAppCheck` from
`APP_CHECK_ROLLOUT_MODE`:

- absent or `monitor`: requests continue through Auth/UID authorization;
  verified versus missing/invalid App Check context is logged. The Functions
  SDK also logs invalid tokens while enforcement is disabled.
- `enforce`: the Functions callable runtime rejects missing or invalid tokens
  before the handler runs.

Any other value is an invalid deployment configuration and throws during
Functions initialization; it must not silently behave as monitor mode.

`consumeAppCheckToken` remains false. Token consumption requires a separate
limited-use-token client contract and is not necessary for the current
callables.

The standalone Flutter app activates App Check after `Firebase.initializeApp`
and before starting `UiApp`:

| Platform | Debug | Release |
| --- | --- | --- |
| Android | Firebase debug provider; optional registered `FIREBASE_APP_CHECK_DEBUG_TOKEN` | Play Integrity |
| iOS/macOS | Firebase debug provider; optional registered `FIREBASE_APP_CHECK_DEBUG_TOKEN` | App Attest with DeviceCheck fallback |
| Web | Firebase web debug provider | reCAPTCHA Enterprise score key using `FIREBASE_APP_CHECK_WEB_SITE_KEY` |
| Windows | Explicit registered `FIREBASE_APP_CHECK_WINDOWS_DEBUG_TOKEN` only | Unsupported; app startup fails closed |
| Linux/Fuchsia | Unsupported | Unsupported; app startup fails closed |

Release web startup fails when its site key is absent. The Functions
`enforceAppCheck` option is global for each callable, not a client-selectable or
per-platform switch. Production enforcement must therefore remain off until
every production platform using these callables has a measured, working
attestation path. If Windows, Linux, or another unsupported production client
remains in scope, it must be excluded from the Firebase-backed release or
routed to separately reviewed endpoints before global enforcement. A
client-supplied platform claim is not an acceptable bypass. Embedding hosts are
responsible for activating App Check before using the exported game Firebase
adapters.

The production web provider is a score-based reCAPTCHA Enterprise key limited
to the Firebase Hosting `web.app` and `firebaseapp.com` domains. The public
site key is supplied with `--dart-define=FIREBASE_APP_CHECK_WEB_SITE_KEY=...`
during the release build and is not stored as a repository secret. Firebase
App Check exchanges its assessment for a one-hour App Check token.

## Request bounds

Every callable request parser applies the same JSON boundary before domain
logic:

- serialized UTF-8 payload: 32 KiB;
- maximum nesting depth: 8;
- maximum string length: 2,048 characters;
- maximum array length: 128;
- maximum object fields: 64;
- maximum object-field-name length: 128;
- maximum total JSON nodes: 512.

Only JSON primitives, arrays, and plain objects are accepted. Non-finite
numbers, non-JSON values (including `Date`, `Map`, and `Set`), and cyclic
structures are rejected.
Ownership command IDs and run-create request IDs are additionally limited to 96
characters and `[A-Za-z0-9._:-]`, starting with an alphanumeric character.

These are protocol safety bounds, not player activity quotas. Changing them
requires checking every Flutter request DTO and adding malformed-boundary
tests.

## Atomic quota state

`abuse_quota/{uid}` stores a fixed map of burst and sustained counters for:

- `ownership_command`;
- `run_create`;
- `upload_grant`;
- `finalize_replay_bytes`;
- `leaderboard_read`, including active-board reads;
- `ghost_url`.

Each decision runs in a Firestore transaction that also checks the
account-deletion tombstone. Concurrent requests therefore serialize on the UID
document and cannot all pass the same limit. Rejected attempts are counted so
monitoring shows attempted load, not only accepted work.

Default windows are one minute and 24 hours. Window lengths and limits are
configurable per route:

```text
ABUSE_<ROUTE>_BURST_WINDOW_MS
ABUSE_<ROUTE>_BURST_LIMIT
ABUSE_<ROUTE>_SUSTAINED_WINDOW_MS
ABUSE_<ROUTE>_SUSTAINED_LIMIT
```

For example, the run-create prefix is `ABUSE_RUN_CREATE`. Reviewed
source-controlled defaults are:

| Route | Burst per minute | Sustained per 24 hours |
| --- | ---: | ---: |
| `ownership_command` | 120 requests | 5,000 requests |
| `run_create` | 20 requests | 300 requests |
| `upload_grant` | 20 requests | 300 requests |
| `finalize_replay_bytes` | 32 MiB | 1 GiB |
| `leaderboard_read` | 120 requests | 5,000 requests |
| `ghost_url` | 30 requests | 1,000 requests |

`ABUSE_CONTROL_MODE=monitor` records counters and `wouldReject` signals without
rejecting. Production uses `enforce`; an exceeded limit returns
`resource-exhausted` before Storage signing, task dispatch, or the protected
expensive read. Route environment variables can override the defaults.
Malformed overrides fail closed with `failed-precondition` during enforcement;
monitor mode logs the configuration error and uses the reviewed default.
The rollout mode itself accepts only `monitor` or `enforce`; another value is a
configuration error rather than an implicit monitor-mode fallback.

The quota document contains only the fixed route set and expires after the
longest active window plus a 24-hour operational margin.
`abuseQuotaRetentionCleanup` deletes expired documents hourly. Security Rules
deny direct clients, and account deletion removes the UID document.

### Active resource gauges

Run creation transactionally counts non-terminal sessions and upload-grant
issuance transactionally counts unexpired `uploading` sessions. Their optional
limits are:

```text
ABUSE_RUN_ACTIVE_SESSIONS_LIMIT
ABUSE_RUN_ACTIVE_UPLOAD_GRANTS_LIMIT
```

Both follow `ABUSE_CONTROL_MODE`. Production defaults are 32 active sessions
and eight active upload grants. Scans are capped at 256 sessions and 128 active
upload grants, respectively, and the required composite indexes are in
`firestore.indexes.json`.

## Run-create idempotency and replay size

Flutter generates a new bounded `clientRequestId` for each logical
`runSessionCreate` invocation. The backend derives the run-session document ID
from UID plus request ID and stores a hash of UID, request ID, mode, level, and
compatibility version.

- A retry with the same request and payload returns the original ticket.
- Concurrent duplicates create one run-session document.
- Reusing the request ID with different parameters returns `already-exists`.
- The final create transaction still reads the deletion tombstone and active
  session query before creating the document.

Replay uploads are capped at 8 MiB in the signed grant, the public finalize
validator, the Storage metadata check, and the persisted uploaded-replay
contract. Finalize byte quotas are charged before Storage metadata lookup and
represent attempted replay bytes, including repeated attempts.

## Ownership idempotency retention

The supported offline ownership-command retry window is seven days. New
idempotency documents are retained for 14 days and store only:

- payload hash;
- schema version;
- resulting revision;
- rejected reason or accepted outcome;
- numeric creation and expiry timestamps;
- a server timestamp for operations.

They do not duplicate canonical selection, meta, inventory, progression, or
store state. A replay returns the current canonical state for convergence while
preserving the stored outcome and payload-hash mismatch detection.

`ownershipIdempotencyRetentionCleanup` runs hourly:

1. deletes an expiry-bounded page;
2. advances a durable document-path cursor through the one-time legacy
   compaction;
3. removes legacy full `OwnershipCommandResult` snapshots and gives migrated
   records a fresh 14-day retention window.

The collection-group expiry query requires the source-controlled
`idempotency.expiresAtMs` ascending field override in
`firestore.indexes.json`. Production verification found the missing index,
deployed it, and then compacted all six legacy records with no missing expiry.

Deleting an idempotency record outside the supported retry window cannot
double-apply a purchase: the original command's expected revision is stale
after the accepted mutation. Settlement and reward proof records are separate
and are never expired by this cleanup.

## Metrics and operational rollout

Structured logs currently emit:

- `callable_app_check`: function, rollout mode, verified/missing status, app ID;
- `callable_quota`: route, mode, accepted/would-reject, units, counters,
  configured limits, and a truncated SHA-256 UID hash;
- `runSessionCreate_active_sessions`;
- `runUploadGrant_active_grants`;
- hourly quota and idempotency retention results;
- existing run-create latency and submission lifecycle metrics.

Raw UID is not written to the new quota logs. Firestore quota state necessarily
uses UID as its server-only document key.

Firebase callable verification summaries feed a counter for missing or invalid
App Check context and a total callable-request counter. Quota decisions feed
replay-finalize and signed-URL attempt counters. No log metric extracts UID,
app ID, function, route, or another high-cardinality label.

The source-controlled bundle under
`functions/monitoring/abuse_controls/` alerts on:

- App Check gaps above 20 observations in 15 minutes;
- any enforced quota rejection or malformed enforcement configuration;
- active-session or upload-grant saturation;
- backend 5xx and recognized Firestore transaction contention;
- a saturated 200-document quota-retention cleanup page;
- more than 64 replay finalizes, 500 signed-URL attempts, 1,000 replay-bucket
  operations, 1,000 task attempts, or 5,000 callable requests in 15 minutes.

The native Storage, Cloud Tasks, and Cloud Run metrics complement the
application logs. Existing replay-validator policies remain authoritative for
validation/projection queue backlog, retries, validator 5xx, resource
rejections, probes, and memory. These signals are project resource/cost
proxies, not a currency-denominated billing budget. The pre-launch thresholds
must be reviewed after at least seven days of organic traffic.

Rollout order:

1. deploy App Check-capable clients and backend monitoring mode;
2. register debug/staging tokens and release providers;
3. measure per-platform verified-token rates and normal route distributions;
4. choose burst, sustained, active-resource, and byte limits with recorded
   measurements and owner approval;
5. load-test atomic contention and rollback in staging;
6. configure alerts for App Check gaps, actual rejection, transaction errors,
   signed URLs, replay-finalize attempts, Storage/task volume, retention
   backlog, and callable cost pressure;
7. canary the enforcement configuration in staging or an isolated backend,
   then enable it globally only after every in-scope platform passes the
   readiness gate; retain a documented rollback to `monitor`.

Alert completion, quota selection, isolated load evidence, monitor canary, and
production quota enforcement were completed on July 19. App Check production
enforcement remains open in the audit remediation tracker.
The first direct production canary emitted only missing/invalid App Check
tokens, which monitoring accepted as designed. The follow-up web release
produced one server-verified production-origin attestation before reaching the
expected Firebase Auth gate. That sample proves web compatibility, but it is
not a sustained success rate and does not cover native platforms.
