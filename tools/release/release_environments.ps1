Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# The registry is the only resource selector. Overrides can assert an identity,
# but cannot redirect a selected environment into another project's resources.
function Get-ReleaseEnvironmentDefinition {
  param([string]$Root, [string]$Environment = "dev", [string]$ProjectId = "", [string]$Region = "")
  if ($Environment -notin @("dev", "staging", "prod")) { throw "Unknown release environment: $Environment" }
  $registry = Get-Content -Raw -LiteralPath (Join-Path $Root "tools/release/environments.json") | ConvertFrom-Json
  if ($registry.schemaVersion -ne 1) { throw "Unsupported environment registry." }
  $definition = $registry.environments.$Environment
  foreach ($field in @("projectId", "displayName", "region", "firestoreLocation", "firebaseConfig", "replayBucket",
      "workerService", "validationQueue", "projectionQueue", "androidPackage")) {
    if (-not $definition.$field) { throw "Missing $Environment environment field: $field" }
  }
  if ($definition.projectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$' -or
      $definition.region -notmatch '^[a-z]+-[a-z]+[0-9]+$' -or
      $definition.replayBucket -notmatch '^[a-z0-9][a-z0-9.-]+[a-z0-9]$') { throw "Invalid environment resource identity." }
  foreach ($other in @("dev", "staging", "prod") | Where-Object { $_ -ne $Environment }) {
    foreach ($field in @("projectId", "replayBucket", "androidPackage", "firebaseConfig")) {
      if ($definition.$field -eq $registry.environments.$other.$field) { throw "Environments share $field." }
    }
  }
  if (($ProjectId -and $ProjectId -ne $definition.projectId) -or
      ($Region -and $Region -ne $definition.region)) { throw "Project/region contradict selected environment $Environment." }
  $aliases = Get-Content -Raw -LiteralPath (Join-Path $Root ".firebaserc") | ConvertFrom-Json
  if ($aliases.projects.$Environment -ne $definition.projectId -or
      $aliases.projects.default -ne $registry.environments.dev.projectId) { throw "Firebase aliases contradict environment registry." }
  $expectedConfig = if ($Environment -eq "dev") { "firebase.json" } else { "firebase.$Environment.json" }
  if ($definition.firebaseConfig -ne $expectedConfig) { throw "Invalid Firebase config path for $Environment." }
  $config = Get-Content -Raw -LiteralPath (Join-Path $Root $definition.firebaseConfig) | ConvertFrom-Json
  if ($definition.hostingSite) {
    if ($definition.hostingSite -ne $definition.projectId -or $config.hosting.site -ne $definition.hostingSite) {
      throw "Hosting site contradicts selected environment."
    }
  } elseif ($config.PSObject.Properties.Name -contains "hosting") { throw "Hosting is disabled for $Environment." }
  if ($definition.workerService -ne "replay-validator" -or $definition.validationQueue -ne "replay-validation" -or
      $definition.projectionQueue -ne "replay-projection") { throw "Unsupported worker/queue topology." }
  return $definition
}

function Assert-ReleaseEnvironmentValues {
  param([object]$Definition, [hashtable]$Values, [switch]$RequireConfiguration)
  $project = $Definition.projectId
  $expected = @{
    REPLAY_STORAGE_BUCKET = $Definition.replayBucket
    REPLAY_VALIDATOR_URL = $Definition.workerUrl
    FUNCTIONS_REGION = $Definition.region
    RUN_SESSION_CREATE_REGION = $Definition.region
    LEADERBOARD_REGION = $Definition.region
    REPLAY_VALIDATION_QUEUE_LOCATION = $Definition.region
    REPLAY_VALIDATION_QUEUE_NAME = $Definition.validationQueue
    REPLAY_PROJECTION_QUEUE_NAME = $Definition.projectionQueue
    REPLAY_VALIDATOR_SERVICE_ACCOUNT = "sa-replay-validator@$project.iam.gserviceaccount.com"
    REPLAY_TASK_DISPATCH_SERVICE_ACCOUNT = "sa-replay-task-dispatch@$project.iam.gserviceaccount.com"
    GCLOUD_PROJECT = $project
    GOOGLE_CLOUD_PROJECT = $project
  }
  foreach ($key in $expected.Keys) {
    if ($Values.ContainsKey($key) -and $Values[$key] -ne $expected[$key]) { throw "Environment resource mismatch: $key" }
  }
  if ($RequireConfiguration) {
    if (-not $Definition.workerUrl) { throw "Worker URL has not been registered for $project." }
    foreach ($key in @("REPLAY_STORAGE_BUCKET", "REPLAY_VALIDATION_QUEUE_LOCATION", "REPLAY_VALIDATOR_URL")) {
      if (-not $Values.ContainsKey($key) -or -not $Values[$key]) { throw "Missing environment configuration: $key" }
    }
  }
  if ($Values.ContainsKey("REPLAY_VALIDATOR_URL")) {
    $uri = $null
    if (-not [Uri]::TryCreate($Values.REPLAY_VALIDATOR_URL, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne "https" -or $uri.Host -notlike "replay-validator-*.run.app" -or
        $uri.AbsolutePath -ne "/" -or $uri.Query -or $uri.UserInfo) { throw "Invalid replay worker URL." }
    if ($Values.ContainsKey("REPLAY_VALIDATOR_TASK_URL") -and
        $Values.REPLAY_VALIDATOR_TASK_URL -ne "$($Values.REPLAY_VALIDATOR_URL.TrimEnd('/'))/tasks/validate") {
      throw "Validation task URL contradicts worker URL."
    }
  }
}
