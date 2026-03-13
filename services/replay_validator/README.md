# Replay Validator Service

`services/replay_validator` is the Cloud Run worker service for replay-validation
tasks.

Current scope in this scaffold:

- standalone Dart HTTP service package
- health endpoint: `GET /healthz`
- Cloud Tasks endpoint: `POST /tasks/validate`
- safe default behavior: validation dispatch returns `501 not_implemented`
  until full Phase 4 validator logic is implemented

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
IMAGE_URI="europe-west1-docker.pkg.dev/${PROJECT_ID}/replay/replay-validator:phase4-bootstrap"

gcloud builds submit \
  --project="${PROJECT_ID}" \
  --tag="${IMAGE_URI}" \
  --file="services/replay_validator/Dockerfile" \
  .
```

## Deploy To Cloud Run

```bash
PROJECT_ID="rpg-runner-d7add"
REGION="europe-west1"
SERVICE="replay-validator"
VALIDATOR_SA="sa-replay-validator@${PROJECT_ID}.iam.gserviceaccount.com"
TASK_DISPATCH_SA="sa-replay-task-dispatch@${PROJECT_ID}.iam.gserviceaccount.com"
IMAGE_URI="europe-west1-docker.pkg.dev/${PROJECT_ID}/replay/replay-validator:phase4-bootstrap"

gcloud run deploy "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --image="${IMAGE_URI}" \
  --service-account="${VALIDATOR_SA}" \
  --no-allow-unauthenticated

gcloud run services add-iam-policy-binding "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --member="serviceAccount:${TASK_DISPATCH_SA}" \
  --role="roles/run.invoker"

RUN_URL="$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='value(status.url)')"

gcloud tasks queues update replay-validation \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --http-oidc-service-account-email-override="${TASK_DISPATCH_SA}" \
  --http-oidc-token-audience-override="${RUN_URL}"
```

