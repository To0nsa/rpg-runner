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
- conditional player-best/top-10 writes plus scheduled board/ghost
  reconciliation
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
dart compile exe tool/aot_protocol_probe.dart -o ../../.tmp/aot_protocol_probe
../../.tmp/aot_protocol_probe
```

## Build Container Image

Run from repository root (`c:\dev\rpg_runner`):

```bash
PROJECT_ID="rpg-runner-d7add"
IMAGE_URI="europe-west1-docker.pkg.dev/${PROJECT_ID}/replay/replay-validator:$(date +%Y%m%d-%H%M%S)"

gcloud builds submit \
  . \
  --project="${PROJECT_ID}" \
  --config=services/replay_validator/cloudbuild.yaml \
  --substitutions=_IMAGE_URI="${IMAGE_URI}"
```

## Deploy To Cloud Run

Deploy the paired Functions repair/settlement surfaces and required Firestore
indexes first:

```powershell
firebase deploy --project rpg-runner-d7add `
  --only "firestore:indexes,functions:runValidationRepair,functions:runSettlementOnHandoff,functions:runSettlementRepair,functions:runSettlementImmediate,functions:runProjectionOnAccepted,functions:runProjectionReconciliation"
```

Then run the checked-in service/queue policy from the repository root:

```powershell
.\services\replay_validator\configure_cloud.ps1 `
  -ProjectId "rpg-runner-d7add" `
  -ReplayStorageBucket "rpg-runner-replay-euw1-20260312-01" `
  -ImageUri "europe-west1-docker.pkg.dev/rpg-runner-d7add/replay/replay-validator:<replace-with-built-tag>" `
  -SettlementDispatchUrl "https://europe-west1-rpg-runner-d7add.cloudfunctions.net/runSettlementImmediate"
```

The script is idempotent for existing queues and fixes the release policy at:

- Cloud Run: 1 CPU, 512 MiB, 240-second request timeout, concurrency 1,
  maximum 10 instances, readiness startup probe, and independent liveness
  probe
- validation queue: 8 attempts, 24-hour retry duration, 30-second minimum and
  4-hour maximum backoff, 5 dispatches/second, 5 concurrent dispatches
- projection queue: independent retry/URI policy; it never targets
  `/tasks/validate`
- validation lease: 10 minutes
- orphaned-task repair eligibility: 15 minutes
- compressed/expanded replay limits: 8 MiB / 32 MiB; JSON nesting depth: 64
- command-frame/run-duration/simulation limits: 250,000 / 6 hours / 2 minutes
- the container runtime user is unprivileged and root build-context ignore
  files include only the service and its local package dependencies

It also tags the accepted revision as `production` and applies the checked-in
cloud retention policy. The policy keeps that production image plus the five
most recent replay-validator versions, deletes other replay-validator versions
after 90 days, and expires Cloud Build `source/` archives after 30 days. Run
the policy independently after creating a project or changing its buckets:

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
