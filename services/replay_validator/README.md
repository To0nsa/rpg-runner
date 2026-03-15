# Replay Validator Service

`services/replay_validator` is the Cloud Run worker service for replay-validation
tasks.

Current scope in this scaffold:

- standalone Dart HTTP service package
- health endpoint: `GET /healthz`
- Cloud Tasks endpoint: `POST /tasks/validate`
- deterministic validator worker when required env vars are present
- safe fallback behavior: validation dispatch returns `501 not_implemented`
  when required env vars are missing

## Local Run

```bash
cd services/replay_validator
dart pub get
dart run bin/server.dart
```

Default port is `8080` (or `PORT` env var if set).

## Build And Test

```bash
dart analyze services/replay_validator
dart test services/replay_validator/test
dart compile exe services/replay_validator/bin/server.dart -o .tmp/replay_validator_server
```

## Build Container Image

Run from repository root (`c:\dev\rpg_runner`):

```bash
PROJECT_ID="rpg-runner-d7add"
IMAGE_URI="europe-west1-docker.pkg.dev/${PROJECT_ID}/replay/replay-validator:$(date +%Y%m%d-%H%M%S)"

cat > /tmp/replay-validator-build.yaml <<'EOF'
steps:
- name: gcr.io/cloud-builders/docker
  args: ["build","-f","services/replay_validator/Dockerfile","-t","${_IMAGE_URI}","."]
images: ["${_IMAGE_URI}"]
EOF

gcloud builds submit \
  . \
  --project="${PROJECT_ID}" \
  --config=/tmp/replay-validator-build.yaml \
  --substitutions=_IMAGE_URI="${IMAGE_URI}"
```

## Deploy To Cloud Run

```bash
PROJECT_ID="rpg-runner-d7add"
REGION="europe-west1"
SERVICE="replay-validator"
QUEUE_NAME="replay-validation"
VALIDATOR_SA="sa-replay-validator@${PROJECT_ID}.iam.gserviceaccount.com"
TASK_DISPATCH_SA="sa-replay-task-dispatch@${PROJECT_ID}.iam.gserviceaccount.com"
REPLAY_STORAGE_BUCKET="rpg-runner-replay-euw1-20260312-01"
IMAGE_URI="europe-west1-docker.pkg.dev/${PROJECT_ID}/replay/replay-validator:<replace-with-built-tag>"

gcloud run deploy "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --image="${IMAGE_URI}" \
  --service-account="${VALIDATOR_SA}" \
  --no-allow-unauthenticated \
  --set-env-vars="GCLOUD_PROJECT=${PROJECT_ID},REPLAY_STORAGE_BUCKET=${REPLAY_STORAGE_BUCKET}"

gcloud run services add-iam-policy-binding "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --member="serviceAccount:${TASK_DISPATCH_SA}" \
  --role="roles/run.invoker"

RUN_URL="$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='value(status.url)')"

HOST="$(echo "${RUN_URL}" | sed -E 's#https?://([^/]+)/?#\1#')"

gcloud tasks queues update "${QUEUE_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --http-uri-override="scheme:https,host:${HOST},path:/tasks/validate" \
  --http-oidc-service-account-email-override="${TASK_DISPATCH_SA}" \
  --http-oidc-token-audience-override="${RUN_URL}"
```

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

gcloud functions logs read runSessionFinalizeUpload --gen2 --region us-central1 --limit 50
gcloud functions logs read runSessionLoadStatus --gen2 --region us-central1 --limit 50
```

Healthy signals:

- validator logs show `POST [202] /tasks/validate`
- queue task `lastAttempt.responseStatus` is not `HTTP status code 501/403`
- `runSessionLoadStatus` eventually stops returning `pending_validation/uploaded` and moves to a terminal verification state
