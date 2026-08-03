[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectId,

  [string]$Region = "europe-west1",
  [string]$CloudBuildBucket = "",
  [string]$ReplayArtifactRepository = "replay",
  [switch]$DryRunArtifactCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Gcloud {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  & gcloud @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
}

if ([string]::IsNullOrWhiteSpace($CloudBuildBucket)) {
  $CloudBuildBucket = "${ProjectId}_cloudbuild"
}

$cloudBuildLifecycleFile = Join-Path $PSScriptRoot "cloudbuild-source-lifecycle.json"
$replayArtifactCleanupFile = Join-Path $PSScriptRoot "replay-artifact-cleanup.json"
foreach ($policyFile in @($cloudBuildLifecycleFile, $replayArtifactCleanupFile)) {
  if (-not (Test-Path -LiteralPath $policyFile -PathType Leaf)) {
    throw "Required retention policy file is missing: $policyFile"
  }
}

# The checked-in lifecycle configuration is authoritative for this build bucket.
# It expires only completed build-source archives and explicitly preserves the
# seven-day soft-delete recovery window for a mistaken lifecycle configuration.
Invoke-Gcloud @(
  "storage", "buckets", "update", "gs://$CloudBuildBucket",
  "--lifecycle-file=$cloudBuildLifecycleFile",
  "--soft-delete-duration=7d"
)

$artifactCleanupCommand = @(
  "artifacts", "repositories", "set-cleanup-policies", $ReplayArtifactRepository,
  "--project=$ProjectId",
  "--location=$Region",
  "--policy=$replayArtifactCleanupFile"
)
if ($DryRunArtifactCleanup) {
  $artifactCleanupCommand += "--dry-run"
} else {
  # Omission preserves a repository's existing dry-run setting. Explicitly
  # disable it after the review step so the configured policy becomes active.
  $artifactCleanupCommand += "--no-dry-run"
}
Invoke-Gcloud $artifactCleanupCommand

Invoke-Gcloud @(
  "storage", "buckets", "describe", "gs://$CloudBuildBucket",
  "--format=yaml(name,lifecycle_config,softDeletePolicy)"
)
Invoke-Gcloud @(
  "artifacts", "repositories", "describe", $ReplayArtifactRepository,
  "--project=$ProjectId",
  "--location=$Region",
  "--format=yaml(name,cleanupPolicies,cleanupPolicyDryRun)"
)
