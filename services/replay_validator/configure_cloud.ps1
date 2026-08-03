[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [string]$ReplayStorageBucket,

  [Parameter(Mandatory = $true)]
  [string]$ImageUri,

  [Parameter(Mandatory = $true)]
  [string]$SettlementDispatchUrl,

  [string]$Region = "europe-west1",
  [string]$Service = "replay-validator",
  [string]$ValidationQueue = "replay-validation",
  [string]$ProjectionQueue = "replay-projection",
  [string]$ValidatorServiceAccount = "",
  [string]$RunControlServiceAccount = "",
  [string]$TaskDispatchServiceAccount = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ValidatorServiceAccount)) {
  $ValidatorServiceAccount =
    "sa-replay-validator@$ProjectId.iam.gserviceaccount.com"
}
if ([string]::IsNullOrWhiteSpace($RunControlServiceAccount)) {
  $RunControlServiceAccount =
    "sa-run-control@$ProjectId.iam.gserviceaccount.com"
}
if ([string]::IsNullOrWhiteSpace($TaskDispatchServiceAccount)) {
  $TaskDispatchServiceAccount =
    "sa-replay-task-dispatch@$ProjectId.iam.gserviceaccount.com"
}

if ($ImageUri -notmatch '^[^@\s]+@sha256:[0-9a-f]{64}$') {
  throw "ImageUri must be an immutable container digest ending in @sha256:<64 hex characters>."
}

function Invoke-Gcloud {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  & gcloud @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
}

function Get-GcloudOutput {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  $output = (& gcloud @CommandArgs | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
  return $output
}

function Ensure-Queue {
  param([Parameter(Mandatory = $true)][string]$QueueName)

  & gcloud tasks queues describe $QueueName `
    "--project=$ProjectId" `
    "--location=$Region" *> $null
  if ($LASTEXITCODE -eq 0) {
    return
  }
  Invoke-Gcloud @(
    "tasks", "queues", "create", $QueueName,
    "--project=$ProjectId",
    "--location=$Region"
  )
}

# These are conservative launch limits. Change them only with measured replay
# memory/CPU evidence and update replay_validator_worker.md in the same change.
$environmentVariables = @(
  "GCLOUD_PROJECT=$ProjectId",
  "REPLAY_STORAGE_BUCKET=$ReplayStorageBucket",
  "SETTLEMENT_DISPATCH_URL=$SettlementDispatchUrl",
  "SETTLEMENT_DISPATCH_TIMEOUT_MS=4000",
  "VALIDATOR_LEASE_DURATION_MS=600000",
  "VALIDATOR_ORPHANED_TASK_REPAIR_DELAY_MS=900000",
  "VALIDATOR_INTERNAL_ERROR_GRACE_WINDOW_MS=3600000",
  "VALIDATOR_INCIDENT_MODE_PAUSE_AUTO_REVOKE=false",
  "VALIDATOR_INCIDENT_MODE_RETRY_DELAY_MS=900000",
  "VALIDATOR_MAX_COMPRESSED_REPLAY_BYTES=8388608",
  "VALIDATOR_MAX_EXPANDED_REPLAY_BYTES=33554432",
  "VALIDATOR_MAX_JSON_NESTING_DEPTH=64",
  "VALIDATOR_MAX_COMMAND_FRAMES=250000",
  "VALIDATOR_MAX_RUN_DURATION_SECONDS=21600",
  "VALIDATOR_MAX_SIMULATION_WALL_TIME_MS=120000"
) -join ","

# The validator reads immutable source evidence, creates sealed artifacts, and
# owns the complete ghost object lifecycle. Each binding stays prefix-scoped.
Invoke-Gcloud @(
  "storage", "buckets", "add-iam-policy-binding", "gs://$ReplayStorageBucket",
  "--member=serviceAccount:$ValidatorServiceAccount",
  "--role=roles/storage.objectViewer",
  "--condition=expression=resource.name.startsWith('projects/_/buckets/$ReplayStorageBucket/objects/replay-submissions/'),title=ReplaySubmissionEvidenceRead,description=Read replay evidence pinned to a Storage generation"
)
Invoke-Gcloud @(
  "storage", "buckets", "add-iam-policy-binding", "gs://$ReplayStorageBucket",
  "--member=serviceAccount:$ValidatorServiceAccount",
  "--role=roles/storage.objectCreator",
  "--condition=expression=resource.name.startsWith('projects/_/buckets/$ReplayStorageBucket/objects/replay-submissions/validated/'),title=ValidatedReplayArtifactsWrite,description=Write sealed validated replay artifacts"
)
Invoke-Gcloud @(
  "storage", "buckets", "add-iam-policy-binding", "gs://$ReplayStorageBucket",
  "--member=serviceAccount:$ValidatorServiceAccount",
  "--role=roles/storage.objectUser",
  "--condition=expression=resource.name.startsWith('projects/_/buckets/$ReplayStorageBucket/objects/ghosts/'),title=GhostArtifactsManage,description=Create verify and delete validator-owned ghost artifacts"
)

# Storage only evaluates object-list access at the bucket level. The control
# plane gets bucket-wide listing, while destructive access remains prefix-scoped.
Invoke-Gcloud @(
  "storage", "buckets", "add-iam-policy-binding", "gs://$ReplayStorageBucket",
  "--member=serviceAccount:$RunControlServiceAccount",
  "--role=roles/storage.objectViewer",
  "--condition=None"
)
Invoke-Gcloud @(
  "storage", "buckets", "add-iam-policy-binding", "gs://$ReplayStorageBucket",
  "--member=serviceAccount:$RunControlServiceAccount",
  "--role=roles/storage.objectUser",
  "--condition=expression=resource.name.startsWith('projects/_/buckets/$ReplayStorageBucket/objects/replay-submissions/') || resource.name.startsWith('projects/_/buckets/$ReplayStorageBucket/objects/ghosts/'),title=RunControlReplayArtifactManage,description=Delete replay artifacts during cleanup and account deletion"
)

Invoke-Gcloud @(
  "run", "deploy", $Service,
  "--project=$ProjectId",
  "--region=$Region",
  "--image=$ImageUri",
  "--service-account=$ValidatorServiceAccount",
  "--no-allow-unauthenticated",
  "--cpu=1",
  "--memory=512Mi",
  "--timeout=240s",
  "--concurrency=1",
  "--max-instances=10",
  "--startup-probe=httpGet.path=/ready,httpGet.port=8080,periodSeconds=5,timeoutSeconds=2,failureThreshold=12",
  "--liveness-probe=httpGet.path=/live,httpGet.port=8080,periodSeconds=30,timeoutSeconds=2,failureThreshold=3",
  "--set-env-vars=$environmentVariables"
)

# Resolve the ready revision after deploy and prove it uses the requested
# immutable digest before assigning the stable retention tag.
$readyRevision = Get-GcloudOutput @(
  "run", "services", "describe", $Service,
  "--project=$ProjectId",
  "--region=$Region",
  "--format=value(status.latestReadyRevisionName)"
)
if ([string]::IsNullOrWhiteSpace($readyRevision)) {
  throw "Cloud Run deployment did not report a ready revision."
}
$deployedImageDigest = Get-GcloudOutput @(
  "run", "revisions", "describe", $readyRevision,
  "--project=$ProjectId",
  "--region=$Region",
  "--format=value(status.imageDigest)"
)
if ($deployedImageDigest -ne $ImageUri) {
  throw "Ready revision $readyRevision resolved to $deployedImageDigest instead of $ImageUri."
}

# Artifact cleanup preserves the accepted digest and five recent versions.
$productionImageUri = "$Region-docker.pkg.dev/$ProjectId/replay/replay-validator:production"
Invoke-Gcloud @(
  "artifacts", "docker", "tags", "add", $ImageUri, $productionImageUri
)

Invoke-Gcloud @(
  "run", "services", "add-iam-policy-binding", $Service,
  "--project=$ProjectId",
  "--region=$Region",
  "--member=serviceAccount:$TaskDispatchServiceAccount",
  "--role=roles/run.invoker"
)

$runUrl = (& gcloud run services describe $Service `
  "--project=$ProjectId" `
  "--region=$Region" `
  "--format=value(status.url)").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($runUrl)) {
  throw "Unable to resolve the deployed Cloud Run URL."
}
$runUri = [Uri]$runUrl

Ensure-Queue -QueueName $ValidationQueue
Invoke-Gcloud @(
  "tasks", "queues", "update", $ValidationQueue,
  "--project=$ProjectId",
  "--location=$Region",
  "--max-attempts=8",
  "--max-retry-duration=86400s",
  "--min-backoff=30s",
  "--max-backoff=14400s",
  "--max-doublings=8",
  "--max-dispatches-per-second=5",
  "--max-concurrent-dispatches=5",
  "--log-sampling-ratio=1.0",
  "--http-uri-override=scheme:https,host:$($runUri.Host),path:/tasks/validate",
  "--http-oidc-service-account-email-override=$TaskDispatchServiceAccount",
  "--http-oidc-token-audience-override=$runUrl"
)

Ensure-Queue -QueueName $ProjectionQueue
Invoke-Gcloud @(
  "tasks", "queues", "update", $ProjectionQueue,
  "--project=$ProjectId",
  "--location=$Region",
  "--max-attempts=100",
  "--max-retry-duration=604800s",
  "--min-backoff=30s",
  "--max-backoff=3600s",
  "--max-doublings=7",
  "--max-dispatches-per-second=5",
  "--max-concurrent-dispatches=5",
  "--log-sampling-ratio=1.0",
  "--http-uri-override=scheme:https,host:$($runUri.Host),path:/tasks/project",
  "--http-oidc-service-account-email-override=$TaskDispatchServiceAccount",
  "--http-oidc-token-audience-override=$runUrl"
)

Invoke-Gcloud @(
  "tasks", "queues", "describe", $ValidationQueue,
  "--project=$ProjectId",
  "--location=$Region"
)
Invoke-Gcloud @(
  "tasks", "queues", "describe", $ProjectionQueue,
  "--project=$ProjectId",
  "--location=$Region"
)

$retentionScript = Join-Path $PSScriptRoot "..\\..\\tools\\cloud\\apply_retention_policies.ps1"
if (-not (Test-Path -LiteralPath $retentionScript -PathType Leaf)) {
  throw "Retention policy script is missing: $retentionScript"
}
& $retentionScript -ProjectId $ProjectId -Region $Region
if ($LASTEXITCODE -ne 0) {
  throw "Retention policy configuration failed."
}
