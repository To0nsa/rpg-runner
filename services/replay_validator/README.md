# Replay Validator Service

`services/replay_validator` is the Cloud Run worker service for replay-validation
tasks.

Current scope:

- standalone Dart HTTP service package
- liveness/readiness endpoints: `GET /live` and `GET /ready`
- Cloud Tasks endpoint: `POST /tasks/validate`
- independent Cloud Tasks endpoint: `POST /tasks/project` for optional
  leaderboard and ghost publication retries
- deterministic validator worker and immediate backend-settlement dispatch after
  its durable handoff when required env vars are present
- token-fenced, expiring validation leases with scheduled lost-task repair
- bounded replay download, streaming gzip expansion, JSON nesting, frame count,
  duration, and simulation wall time
- exact-generation replay validation and ghost promotion with persisted
  generation/digest lineage
- sealed `replay-submissions/validated/...` artifacts before accepted-run
  handoff, with pending-upload cleanup guarded by that durable record
- atomic accepted, rejected, and exhausted-error handoffs
- conditional player-best writes and versioned, no-op Top-10 materialization
  plus scheduled board/ghost reconciliation
- structured projection outcomes that distinguish changed, unchanged,
  ghost-only, retryable, and conflict-exhaustion work
- safe local fallback behavior: validation dispatch returns
  `501 not_implemented` when required env vars are missing

## Local Run

```bash
cd services/replay_validator
dart pub get
dart run bin/server.dart
```

Default port is `8080` (or `PORT` env var if set).

## Build And Test

Run from `services/replay_validator`:

```bash
dart analyze
dart test test
dart compile exe bin/server.dart -o ../../.tmp/replay_validator_server
../../.tmp/replay_validator_server benchmark --ticks=36000 --strict
dart compile exe tool/aot_protocol_probe.dart -o ../../.tmp/aot_protocol_probe
../../.tmp/aot_protocol_probe
```

The benchmark subcommand uses the validator's production replay loop and
normal generated Field/Forest terrain streams. It records and replays 36,000
ticks per level, requires at least 2x real time and less than 300 seconds per
level, verifies the final deterministic outcome, and emits a JSON report.
Before compatible issuance, Phase 7 reruns the same compiled command in the
one-CPU/512 MiB container and records its report.

The current validator build accepts game compatibility `2026.08.0` and the
draining `2026.03.0`; replay/command format `1`, `rules-v2`, `score-v1`, and
`ghost-v1` are the supported ranked tuple. `rules-v2` owns capsule target
narrow-phase combat. The retired `rules-v1` is rejected because this repository
does not ship a historical AABB-combat simulator beside current Core.

Do not deploy this hard-cutover validator until ranked `rules-v1` issuance is
paused, every issued/pending session and validation task is drained or
explicitly closed, and the matching Functions/client build is ready. Remove
the draining game-compatibility label only in a separate deployment after its
own 24-hour issuance drain and active-session audit.

## Build Container Image

Run from repository root (`c:\dev\rpg_runner`):

```bash
PROJECT_ID="rpg-runner-d7add"
IMAGE_TAG="europe-west1-docker.pkg.dev/${PROJECT_ID}/replay/replay-validator:$(date +%Y%m%d-%H%M%S)"

gcloud builds submit \
  . \
  --project="${PROJECT_ID}" \
  --config=services/replay_validator/cloudbuild.yaml \
  --substitutions=_IMAGE_URI="${IMAGE_TAG}"

# Deploy only the immutable digest reported by Artifact Registry.
IMAGE_DIGEST="$(gcloud artifacts docker images describe "${IMAGE_TAG}" \
  --format='value(image_summary.digest)')"
IMAGE_URI="${IMAGE_TAG%:*}@${IMAGE_DIGEST}"
```

## Deploy To Cloud Run

For a new environment, deploy the paired Functions repair/settlement surfaces
and required Firestore indexes first:

```powershell
firebase deploy --project rpg-runner-d7add `
  --only "firestore:indexes,functions:runValidationRepair,functions:runSettlementOnHandoff,functions:runSettlementRepair,functions:runSettlementImmediate,functions:runProjectionOnAccepted,functions:runProjectionReconciliation"
```

Then run the checked-in service/queue policy from the repository root.
For the Phase 7 compatibility cutover in an environment where those paired
surfaces are already deployed, deploy the dual-compatible validator before the
Functions/client revision that can issue `2026.08.0`; this guarantees every
new ticket is accepted from its first issuance:

```powershell
.\services\replay_validator\configure_cloud.ps1 `
  -ProjectId "rpg-runner-d7add" `
  -ReplayStorageBucket "rpg-runner-replay-euw1-20260312-01" `
  -ImageUri "europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator@sha256:<replace-with-64-character-digest>" `
  -SettlementDispatchUrl "https://europe-west1-rpg-runner-d7add.cloudfunctions.net/runSettlementImmediate"
```

The script is idempotent for existing queues and fixes the release policy at:

- Cloud Run: 1 CPU, 512 MiB, 240-second request timeout, concurrency 1,
  maximum 10 instances, readiness startup probe, and independent liveness
  probe
- validation queue: 8 attempts, 24-hour retry duration, 30-second minimum and
  4-hour maximum backoff, 5 dispatches/second, 5 concurrent dispatches
- projection queue: independent retry/URI policy; it never targets
  `/tasks/validate`; Cloud Tasks operation-log sampling is `0.1`, while the
  validation queue remains at `1.0`
- validation lease: 10 minutes
- orphaned-task repair eligibility: 15 minutes
- compressed/expanded replay limits: 8 MiB / 32 MiB; JSON nesting depth: 64
- command-frame/run-duration/simulation limits: 250,000 / 6 hours / 2 minutes
- the container runtime user is unprivileged and root build-context ignore
  files include only the service and its local package dependencies

It accepts only an immutable image digest, verifies that Cloud Run accepted that
exact digest, tags it as `production`, and applies the checked-in cloud
retention policy. The policy keeps that production image plus the five most
recent replay-validator versions, deletes other replay-validator versions after
90 days, expires Cloud Build `source/` archives after 30 days, and enforces a
seven-day Cloud Build bucket soft-delete recovery window. Run the policy
independently after creating a project or changing its buckets:

```powershell
.\tools\cloud\apply_retention_policies.ps1 -ProjectId "rpg-runner-d7add"
```

Do not apply only the Cloud Run revision. The Firestore indexes and scheduled
validation repair are required to recover expired leases and tasks deleted
after retry exhaustion.

## Monitoring

Apply the checked-in validator/projection metrics and alert policies from the
repository root:

```powershell
.\services\replay_validator\monitoring\apply_alerts.ps1 `
  -ProjectId "rpg-runner-d7add" `
  -NotificationEmail "lothringen.rpg@gmail.com"
```

The idempotent policy covers validation and projection retries, terminal
internal errors, replay resource-limit bursts, Cloud Run 5xx/probe/memory
failures, validation/projection queue backlog, and scheduled repair or
reconciliation failures. See
`services/replay_validator/monitoring/README.md` for thresholds and operational
interpretation.

Before this Cloud Run deployment, deploy the paired Firebase Functions
settlement dispatcher, immediate settlement endpoint, and repair schedule. The
immediate endpoint's IAM invoker must be only `${VALIDATOR_SA}`. This validator
revision emits `settlement_pending` for accepted runs, requests that endpoint
with its Cloud Run identity token, and deliberately does not mark runs terminal
or credit wallets itself. Eventarc and scheduled repair remain fallback
delivery paths when immediate dispatch fails or times out.
Leaderboard and ghost projection are enqueued only after accepted validation;
their retries use `${PROJECTION_QUEUE_NAME}` and never affect reward settlement.

## Projection Cost Rollout And Rollback

The early-release recovery policy is one scheduled invocation per hour, four
selected boards by default, one lookahead document, and a maximum batch override
of 64. Normal accepted-run projection remains event-driven; the hourly sweep is
only the missed-delivery repair path. At the release limit of 96 retained boards,
one successful cursor cycle takes 24 hours.

Apply this change only after explicit production authorization, in this order:

1. Deploy an immutable validator image containing versioned no-op Top-10
   materialization.
2. Reconcile an empty and populated canary board twice and prove the second pass
   performs no materialization writes.
3. Deploy `runProjectionReconciliation`, then confirm its Scheduler job is
   hourly and its structured log reports `effectiveBatchSize: 4` and the
   expected `retainedBoardCount`.
4. Set the projection queue operation-log sampling ratio to `0.1`. Keep the
   validation queue at `1.0`.
5. Observe a complete cursor cycle before treating the rollout as healthy.

The narrow queue-policy command for step 4 is:

```powershell
gcloud tasks queues update replay-projection `
  --project=rpg-runner-d7add `
  --location=europe-west1 `
  --log-sampling-ratio=0.1
```

Cloud Tasks operation sampling applies to the queue's operation-log stream; it
is not a success-only filter. Validator retry/internal-error logs, scheduled
Function error logs, Cloud Run 5xx metrics, and native Cloud Tasks backlog and
attempt metrics remain independent and unsampled. No checked-in retry or
backlog alert depends on successful Cloud Tasks operation logs.

Useful post-deploy checks:

```powershell
gcloud scheduler jobs list `
  --project=rpg-runner-d7add `
  --location=europe-west1 `
  --filter='name~runprojectionreconciliation' `
  --format='table(name,schedule,state)'

gcloud tasks queues describe replay-projection `
  --project=rpg-runner-d7add `
  --location=europe-west1 `
  --format='yaml(state,stackdriverLoggingConfig,rateLimits,retryConfig)'

gcloud logging read `
  'resource.type="cloud_run_revision" AND resource.labels.service_name="runprojectionreconciliation" AND jsonPayload.message="runProjectionReconciliation"' `
  --project=rpg-runner-d7add `
  --limit=24 `
  --format=json
```

Rollback uses the last verified immutable validator digest and Functions source.
Restore projection queue sampling to `1.0` when full queue-operation evidence is
needed for an incident. Restore the former cadence/batch only when the repair
SLO fails; never disable the immediate projection trigger, Cloud Tasks retry,
settlement, or account-deletion fencing. Cursor state is forward- and
backward-tolerant and must not be deleted during rollback.

After deploying `runSettlementImmediate`, grant its underlying Cloud Run
service invoker role explicitly and verify that no public principal is present:

```bash
gcloud run services add-iam-policy-binding runsettlementimmediate \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --member="serviceAccount:${VALIDATOR_SA}" \
  --role="roles/run.invoker"

gcloud run services get-iam-policy runsettlementimmediate \
  --project="${PROJECT_ID}" \
  --region="${REGION}"
```

Firestore Eventarc delivery has a separate, non-public invoker binding. After
every Firebase Functions deployment, grant the Functions control-plane service
account access to both Eventarc target services:

```bash
for service in runprojectiononaccepted runsettlementonhandoff; do
  gcloud run services add-iam-policy-binding "${service}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --member="serviceAccount:sa-run-control@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/run.invoker"
done
```

This is required in addition to `roles/eventarc.eventReceiver`: it permits the
authenticated Eventarc push to invoke the generated Cloud Run services without
making either endpoint public. It covers both projection and the independent
settlement fallback.

## Quick Verify (End-To-End)

Run a fresh practice run in the app, then execute:

```bash
PROJECT_ID="rpg-runner-d7add"
REGION="europe-west1"
SERVICE="replay-validator"
QUEUE_NAME="replay-validation"

# 1) Watch live validator logs (leave this running in one terminal)
gcloud beta run services logs tail "${SERVICE}" --region "${REGION}"
```

In a second terminal:

```bash
PROJECT_ID="rpg-runner-d7add"
REGION="europe-west1"
QUEUE_NAME="replay-validation"

# 2) See latest queue tasks and attempts
gcloud tasks list \
  --queue "${QUEUE_NAME}" \
  --location "${REGION}" \
  --limit 5 \
  --format='table(name,scheduleTime,dispatchCount,responseCount)'

# 3) Inspect latest task in detail
TASK_ID="$(gcloud tasks list \
  --queue "${QUEUE_NAME}" \
  --location "${REGION}" \
  --limit 1 \
  --format='value(name)' | awk -F/ '{print $NF}')"

echo "TASK_ID=${TASK_ID}"

gcloud tasks describe "${TASK_ID}" \
  --queue "${QUEUE_NAME}" \
  --location "${REGION}" \
  --format='yaml(name,scheduleTime,dispatchCount,responseCount,lastAttempt)'

# 4) Optional: force-run latest task once (useful while debugging)
gcloud tasks run "${TASK_ID}" \
  --queue "${QUEUE_NAME}" \
  --location "${REGION}"
```

Optional focused logs from last 10 minutes:

```bash
SINCE="$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
FILTER="resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"replay-validator\" AND timestamp>=\"${SINCE}\""

gcloud logging read "${FILTER}" \
--limit=100 \
--format='table(timestamp,textPayload)'

gcloud functions logs read runSessionFinalizeUpload --gen2 --region europe-west1 --limit 50
gcloud functions logs read runSessionLoadStatus --gen2 --region europe-west1 --limit 50
```

Healthy signals:

- `GET /live` and `GET /ready` return `200` on the deployed revision
- validator logs show `POST [202] /tasks/validate`
- queue task `lastAttempt.responseStatus` is not `HTTP status code 501/403`
- `runSessionLoadStatus` may briefly return `settlement_pending`, then moves to
  terminal `validated` only after the Functions-owned wallet settlement
