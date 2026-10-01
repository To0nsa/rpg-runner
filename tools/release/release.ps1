<#
.SYNOPSIS
Checks, prepares, inspects, builds and deploys the configured Firebase release.
.DESCRIPTION
Plan is offline. Prepare changes only local build output. Inspect is read-only.
BuildImage uploads source and starts Cloud Build; PauseIssuance, Deploy and
ResumeIssuance change production.
Deploy requires successful unchanged preparation. Coordinated releases also
require a benchmarked image, fresh drain evidence and CutoverReady. Scoped
releases require unchanged live consumers and a verified production baseline.
No data is cancelled or deleted. Issuance pauses and resumes explicitly.
#>
[CmdletBinding()]
param(
  [ValidateSet("Plan", "Checkout", "ImportCI", "Prepare", "Inspect", "BuildImage", "ImageStatus", "PauseIssuance", "Deploy", "ResumeIssuance")]
  [string]$Action = "Plan",
  [string]$ProjectId = "",
  [string]$Region = "europe-west1",
  [ValidateSet("Auto", "Hosting", "Backend", "Coordinated")]
  [string]$Scope = "Auto",
  [string]$CacheDirectory = "",
  [string]$Commit = "HEAD",
  [long]$RunId = 0,
  [switch]$Rebuild,
  [switch]$CutoverReady
)

. (Join-Path $PSScriptRoot "release_support.ps1")
. (Join-Path $PSScriptRoot "release_cache.ps1")
. (Join-Path $PSScriptRoot "prepare_release.ps1")
. (Join-Path $PSScriptRoot "release_ci.ps1")
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
$cacheRoot = Get-ReleaseCacheRoot $root $CacheDirectory
if ($Action -eq "Checkout") {
  New-ReleaseCheckout $root $Commit
  return
}
if ($Action -eq "ImportCI") {
  Import-ReleaseCI $root $cacheRoot $RunId
  return
}
$firebase = Get-Content -Raw -LiteralPath (Join-Path $root "firebase.json") | ConvertFrom-Json
$defaultProject = (Get-Content -Raw -LiteralPath (Join-Path $root ".firebaserc") | ConvertFrom-Json).projects.default
if (-not $ProjectId) { $ProjectId = $defaultProject }
if ($ProjectId -ne $defaultProject -or $firebase.hosting.site -ne $ProjectId) {
  throw "This workflow targets the configured project and Hosting site only. Configure a separate environment before deploying elsewhere."
}
$contract = Get-ReleaseContract $root $ProjectId
$inputs = Get-ReleaseInputHashes $root $ProjectId
$baseline = Read-ReleaseBaseline $cacheRoot $ProjectId $Region
$resolvedScope = Resolve-ReleaseScope $inputs $contract $baseline $Scope
$sourceDigest = Get-ReleaseSourceDigest $root $ProjectId
$evidenceDirectory = Join-Path $root ".tmp/releases/$ProjectId/$sourceDigest"
$statePath = Join-Path $evidenceDirectory "release.json"
$environment = Read-ReleaseEnvironment $root $ProjectId

function Save-ReleaseState {
  $script:state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding utf8
}

function Invoke-ReleaseGcloud {
  param([string[]]$CommandArgs, [string]$LogName = "")
  $log = if ($LogName) { Join-Path $evidenceDirectory "$LogName.log" } else { "" }
  return Invoke-ReleaseCommand gcloud $CommandArgs $root $log
}

function Invoke-ReleaseFirebase {
  param([string]$Targets)
  $commandArgs = @("--dir", "functions", "exec", "firebase", "deploy",
    "--config", (Join-Path $root "firebase.json"), "--project", $ProjectId,
    "--only", $Targets, "--non-interactive")
  Write-Host "Deploying $Targets"
  $savedDebug = $env:DEBUG
  try {
    # An inherited DEBUG value makes Firebase print full API responses.
    $env:DEBUG = ""
    Invoke-ReleaseCommand corepack (@("pnpm") + $commandArgs) $root (Join-Path $evidenceDirectory "firebase.log") | Write-Host
  } finally { $env:DEBUG = $savedDebug }
}

function Get-ReleaseInventory {
  $nodeArguments = @()
  foreach ($relative in @("functions/.env", "functions/.env.$ProjectId")) {
    $path = Join-Path $root $relative
    if (Test-Path -LiteralPath $path) { $nodeArguments += "--env-file=$path" }
  }
  $nodeArguments += @("functions/tool/production_inventory.mjs", "--project", $ProjectId)
  $json = Invoke-ReleaseCommand node $nodeArguments $root
  $inventory = $json | ConvertFrom-Json
  if ($inventory.projectId -ne $ProjectId) { throw "Inventory project mismatch." }
  $json | Set-Content -LiteralPath (Join-Path $evidenceDirectory "inventory.json") -Encoding utf8
  return $inventory
}

function Get-ImageStatus {
  if (-not $script:state.buildId) { throw "No Cloud Build recorded. Run BuildImage." }
  $json = Invoke-ReleaseGcloud @("builds", "describe", $script:state.buildId,
    "--project=$ProjectId", "--region=global", "--format=json")
  $build = $json | ConvertFrom-Json
  Write-Host "Cloud Build $($script:state.buildId): $($build.status)"
  if ($build.status -in @("QUEUED", "PENDING", "WORKING")) { return $false }
  if ($build.status -ne "SUCCESS") { throw "Cloud Build failed: $($build.status). See $($build.logUrl)" }
  $image = @($build.results.images | Where-Object { $_.name -eq $script:state.imageTag })
  if ($image.Count -ne 1 -or $image[0].digest -notmatch '^sha256:[0-9a-f]{64}$') {
    throw "Cloud Build did not report exactly one expected immutable image."
  }
  $script:state.imageUri = "$Region-docker.pkg.dev/$ProjectId/replay/replay-validator@$($image[0].digest)"
  $script:state.imageVerified = $true
  Save-ReleaseState
  $imageDirectory = Join-Path $cacheRoot "images/$ProjectId/$Region"
  New-Item -ItemType Directory -Force -Path $imageDirectory | Out-Null
  @{ workerInputs = $inputs.worker; buildId = $state.buildId; imageTag = $state.imageTag; imageUri = $state.imageUri } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $imageDirectory "$($inputs.worker).json") -Encoding utf8
  $json | Set-Content -LiteralPath (Join-Path $evidenceDirectory "cloud-build.json") -Encoding utf8
  Write-Host $script:state.imageUri
  return $true
}


function Get-ServingIssuerRevision {
  $json = Invoke-ReleaseGcloud @("run", "services", "describe", "runsessioncreate",
    "--project=$ProjectId", "--region=$Region", "--format=json(status)")
  $service = $json | ConvertFrom-Json
  $ready = $service.status.latestReadyRevisionName
  $traffic = @($service.status.traffic | Where-Object { $_.percent -gt 0 })
  if (-not $ready -or $traffic.Count -ne 1 -or
      $traffic[0].revisionName -ne $ready -or $traffic[0].percent -ne 100) {
    throw "Issuer traffic is not entirely on its ready revision; inspect production before continuing."
  }
  $json = Invoke-ReleaseGcloud @("run", "revisions", "describe", $ready,
    "--project=$ProjectId", "--region=$Region", "--format=json(status,spec.containers)")
  return [pscustomobject]@{ service = $service; revision = ($json | ConvertFrom-Json) }
}

function Assert-IssuancePaused {
  $issuer = Get-ServingIssuerRevision
  $status = $issuer.service.status
  if ($status.latestCreatedRevisionName -ne $status.latestReadyRevisionName -or
      @($status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }).Count -ne 1) {
    throw "Issuer is not paused on a healthy current revision; inspect the failed deployment."
  }
  $overrides = @($issuer.revision.spec.containers[0].env |
    Where-Object { $_ -and $_.name -eq "RUN_SUPPORTED_GAME_COMPAT_VERSIONS" })
  if ($overrides.Count -ne 1 -or $overrides[0].value -ne "release-paused") {
    throw "Issuance is not paused by this workflow. Run PauseIssuance after preparing the image."
  }
}

function Invoke-PausedIssuerRebuild {
  $path = Join-Path $root "functions/.env.$ProjectId"
  $existed = Test-Path -LiteralPath $path
  $original = if ($existed) { [IO.File]::ReadAllBytes($path) } else { $null }
  try {
    $text = if ($existed) { [IO.File]::ReadAllText($path) } else { "" }
    $text = [regex]::Replace($text,
      '(?m)^[ \t]*RUN_SUPPORTED_GAME_COMPAT_VERSIONS[ \t]*=.*(?:\r?\n|$)', "")
    $text = $text.TrimEnd() + [Environment]::NewLine +
      "RUN_SUPPORTED_GAME_COMPAT_VERSIONS=release-paused" + [Environment]::NewLine
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    # The explicit gate is part of this deployment, so rebuilt source cannot
    # open issuance before its matching replay consumers are ready.
    Invoke-ReleaseFirebase "functions:runSessionCreate"
  } finally {
    if ($existed) { [IO.File]::WriteAllBytes($path, $original) }
    elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
  if ((Get-ReleaseSourceDigest $root $ProjectId) -ne $sourceDigest) {
    throw "Release source changed during issuer recovery; inspect production and prepare matching source."
  }
}


function Assert-LiveReleaseArtifacts {
  Assert-LiveWorker $state.imageUri
  Assert-LiveHosting (Get-FileHash -LiteralPath (Join-Path $root "build/web/main.dart.js")).Hash
}

function Assert-LiveWorker {
  param([string]$ExpectedImage)
  $json = Invoke-ReleaseGcloud @("run", "services", "describe", "replay-validator",
    "--project=$ProjectId", "--region=$Region", "--format=json(status)")
  $service = $json | ConvertFrom-Json
  $revision = $service.status.latestReadyRevisionName
  $digest = Invoke-ReleaseGcloud @("run", "revisions", "describe", $revision,
    "--project=$ProjectId", "--region=$Region", "--format=value(status.imageDigest)")
  $traffic = @($service.status.traffic | Where-Object { $_.revisionName -eq $revision -and $_.percent -eq 100 })
  if ($digest -ne $ExpectedImage -or $traffic.Count -ne 1 -or
      $service.status.latestCreatedRevisionName -ne $revision -or
      @($service.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }).Count -ne 1) {
    throw "Live worker digest/traffic differs from the prepared release."
  }
}

function Assert-LiveHosting {
  param([string]$ExpectedHash)
  $download = Join-Path $evidenceDirectory "hosting-main.dart.js"
  Invoke-WebRequest -UseBasicParsing -Uri "https://$ProjectId.web.app/main.dart.js?release=$sourceDigest" -Headers @{ "Cache-Control" = "no-cache" } -OutFile $download
  if ((Get-FileHash -LiteralPath $download).Hash -ne $ExpectedHash) {
    throw "Live Hosting JavaScript differs from the prepared release."
  }
}

function Get-LiveFunctionsIdentity {
  $decodedFunctions = Invoke-ReleaseGcloud @("functions", "list", "--project=$ProjectId", "--regions=$Region", "--format=json") | ConvertFrom-Json
  $functions = @($decodedFunctions)
  $exports = [regex]::Matches((Get-Content -Raw -LiteralPath (Join-Path $root "functions/src/index.ts")), 'export const ([A-Za-z][A-Za-z0-9_]*)\s*=')
  foreach ($export in $exports) {
    $found = @($functions | Where-Object { ($_.name -split '/')[-1] -eq $export.Groups[1].Value -and $_.state -eq "ACTIVE" })
    if ($found.Count -ne 1 -or -not $found[0].updateTime) { throw "Functions inventory is missing an ACTIVE export: $($export.Groups[1].Value)" }
  }
  $identity = @($functions | Sort-Object name | ForEach-Object { [ordered]@{ name = $_.name; updateTime = $_.updateTime } }) | ConvertTo-Json -Compress
  return Get-ReleaseComponentKey $identity "functions-live-v1"
}

function Assert-ScopedBaseline {
  if (-not $baseline) { throw "Scoped deployment requires a verified production baseline." }
  $expectedFunctions = if ($state.scope -eq "Backend" -and $state.functionsDeployedAt) { $state.functionsLiveIdentity } else { $baseline.functionsIdentity }
  if ((Get-LiveFunctionsIdentity) -ne $expectedFunctions) { throw "Live Functions changed outside the release baseline. Use a coordinated release." }
  Assert-LiveWorker $baseline.workerImage
  $expectedWeb = if ($state.scope -eq "Hosting" -and $state.hostingDeployedAt) { (Get-FileHash -LiteralPath (Join-Path $root "build/web/main.dart.js")).Hash } else { $baseline.webSha256 }
  Assert-LiveHosting $expectedWeb
  $issuer = Get-ServingIssuerRevision
  if ($issuer.service.status.latestCreatedRevisionName -ne $issuer.service.status.latestReadyRevisionName -or
      @($issuer.service.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }).Count -ne 1) { throw "Issuer is not healthy for a scoped deployment." }
  $overrides = @($issuer.revision.spec.containers[0].env | Where-Object { $_ -and $_.name -eq "RUN_SUPPORTED_GAME_COMPAT_VERSIONS" })
  if ($overrides.Count -gt 0 -and ($overrides.Count -ne 1 -or $overrides[0].value -ne $contract.gameCompatVersion)) { throw "Issuer compatibility override blocks a scoped deployment." }
  foreach ($queue in @("replay-validation", "replay-projection")) {
    $queueState = Invoke-ReleaseGcloud @("tasks", "queues", "describe", $queue, "--project=$ProjectId", "--location=$Region", "--format=value(state)")
    if ($queueState -ne "RUNNING") { throw "Scoped deployment requires both replay queues RUNNING." }
  }
}

function Confirm-ReleaseBackend {
  $indexes = Invoke-ReleaseGcloud @("firestore", "indexes", "composite", "list", "--project=$ProjectId", "--format=json") | ConvertFrom-Json
  if (@($indexes | Where-Object { $_.state -ne "READY" }).Count -gt 0) { throw "Firestore indexes are still building. Retry Deploy when READY." }
  foreach ($entry in @(
    @("runsettlementimmediate", "sa-replay-validator@$ProjectId.iam.gserviceaccount.com"),
    @("runprojectiononaccepted", "sa-run-control@$ProjectId.iam.gserviceaccount.com"),
    @("runsettlementonhandoff", "sa-run-control@$ProjectId.iam.gserviceaccount.com")
  )) {
    Invoke-ReleaseGcloud @("run", "services", "add-iam-policy-binding", $entry[0], "--project=$ProjectId", "--region=$Region", "--member=serviceAccount:$($entry[1])", "--role=roles/run.invoker", "--quiet") "iam" | Out-Null
    $policy = Invoke-ReleaseGcloud @("run", "services", "get-iam-policy", $entry[0], "--project=$ProjectId", "--region=$Region", "--format=json") | ConvertFrom-Json
    foreach ($binding in $policy.bindings) {
      if ($binding.role -eq "roles/run.invoker" -and @($binding.members | Where-Object { $_ -in @("allUsers", "allAuthenticatedUsers") }).Count -gt 0) { throw "Public invoker binding on $($entry[0]); inspect IAM before continuing." }
    }
  }
  Get-LiveFunctionsIdentity | Out-Null
}

function Save-ProductionBaseline {
  param([string]$WorkerImage, [string]$WebHash)
  Assert-LiveWorker $WorkerImage
  Assert-LiveHosting $WebHash
  $identity = Get-LiveFunctionsIdentity
  $directory = Join-Path $cacheRoot "deployments/$ProjectId"
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $path = Join-Path $directory "$Region.json"
  $temporary = "$path.$([Guid]::NewGuid().ToString('N')).tmp"
  @{ schemaVersion = 2; projectId = $ProjectId; region = $Region; verifiedAt = [DateTime]::UtcNow.ToString("o")
    contract = $contract; inputs = $inputs; workerImage = $WorkerImage; webSha256 = $WebHash; functionsIdentity = $identity } |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding utf8
  Move-Item -LiteralPath $temporary -Destination $path -Force
}

function Confirm-ReleaseQueues {
  param([string]$Operation)
  foreach ($queue in @("replay-validation", "replay-projection")) {
    Invoke-ReleaseGcloud @("tasks", "queues", $Operation, $queue,
      "--project=$ProjectId", "--location=$Region", "--quiet") "queues" | Out-Null
  }
}

if ($Action -eq "Plan") {
  [ordered]@{
    projectId = $ProjectId
    region = $Region
    contract = $contract
    sourceDigest = $sourceDigest
    evidenceDirectory = $evidenceDirectory
    cacheDirectory = $cacheRoot
    scope = $resolvedScope
    components = @(Get-ReleaseComponents $resolvedScope)
    stages = if ($resolvedScope -ne "Coordinated") { @("Prepare: reuse/validate changed components", "Deploy: verify baseline and publish $resolvedScope") } else { @("Prepare: parallel local validation/build", "Inspect: live read-only snapshot",
      "BuildImage: asynchronous remote build and strict benchmark", "ImageStatus: immutable result",
      "PauseIssuance: temporary runtime compatibility gate",
      "Deploy -CutoverReady: Functions/indexes, IAM, worker/queues, boards, Hosting",
      "ResumeIssuance -CutoverReady: readiness checks, queues, ticket issuer") }
  } | ConvertTo-Json -Depth 10
  return
}

New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$state = if (Test-Path -LiteralPath $statePath) {
  Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
} else {
  [pscustomobject]@{
    schemaVersion = 2; projectId = $ProjectId; region = $Region; scope = $resolvedScope; inputs = $inputs; components = @()
    sourceDigest = $sourceDigest; contract = $contract
    prepared = $false; preparedAt = $null; toolchain = $null
    functionsDigest = ""; webDigest = ""; functionsLiveIdentity = ""
    buildId = ""; imageTag = ""; imageUri = ""; imageVerified = $false
    functionsDeployedAt = $null; workerDeployedAt = $null; hostingDeployedAt = $null
    deployedAt = $null; issuancePausedAt = $null; issuanceResumedAt = $null
  }
}

if ($state.schemaVersion -ne 2) { throw "Historical preparation is not compatible with component evidence. Preserve it and use a fresh release checkout/cache." }
if ($state.region -ne $Region) { throw "Evidence belongs to a different region." }

if ($Action -eq "Prepare") {
  $state.prepared = $false
  $state.scope = $resolvedScope
  $state.inputs = $inputs
  $state.functionsDeployedAt = $null
  $state.workerDeployedAt = $null
  $state.hostingDeployedAt = $null
  $state.deployedAt = $null
  Save-ReleaseState
  $state.components = @(Invoke-ReleasePreparation $root $cacheRoot (Get-ReleaseComponents $state.scope) $evidenceDirectory -Rebuild:$Rebuild)
  if ((Get-ReleaseSourceDigest $root $ProjectId) -ne $sourceDigest) {
    throw "Release source changed during preparation. Run Prepare again."
  }
  $state.functionsDigest = if ($state.scope -in @("Backend", "Coordinated")) { Get-ReleaseTreeDigest (Join-Path $root "functions/lib") } else { "" }
  $state.webDigest = if ($state.scope -in @("Hosting", "Coordinated")) { Get-ReleaseTreeDigest (Join-Path $root "build/web") } else { "" }
  $state.prepared = $true
  $state.preparedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
  Write-Host "Prepared $($state.scope) release: $statePath"
  return
}
if ($Action -eq "Inspect") {
  foreach ($entry in @(
    @("worker", @("run", "services", "describe", "replay-validator", "--region=$Region",
      "--format=json(status,spec.template.spec.containers,spec.template.spec.serviceAccountName,spec.traffic)")),
    @("functions", @("functions", "list", "--regions=$Region",
      "--format=json(name,state,updateTime,buildConfig.runtime)")),
    @("queues", @("tasks", "queues", "list", "--location=$Region", "--format=json")),
    @("scheduler", @("scheduler", "jobs", "list", "--location=$Region",
      "--format=json(name,schedule,state,lastAttemptTime)"))
  )) {
    $json = Invoke-ReleaseGcloud ($entry[1] + @("--project=$ProjectId"))
    $json | ConvertFrom-Json | Out-Null
    $json | Set-Content -LiteralPath (Join-Path $evidenceDirectory "$($entry[0]).json") -Encoding utf8
    Write-Host "Recorded $($entry[0])"
  }
  Invoke-ReleaseCommand corepack @("pnpm", "--dir", "functions", "build") $root (Join-Path $evidenceDirectory "inventory-build.log") | Out-Null
  Get-ReleaseInventory | ConvertTo-Json -Depth 20 | Write-Output
  Write-Host "Read-only evidence: $evidenceDirectory"
  return
}

Assert-ReleasePrepared $state $sourceDigest $ProjectId $Region $root

if ($state.scope -in @("Hosting", "Backend", "None")) {
  if ($Action -ne "Deploy") { throw "$Action is only needed for coordinated releases. Use Deploy for $($state.scope)." }
  if ($resolvedScope -ne $state.scope) { throw "Deployment scope changed since preparation. Run Prepare again." }
  Assert-ScopedBaseline
  if ($state.scope -eq "None") { Write-Host "No runtime changes to deploy."; return }
  if ($state.scope -eq "Hosting") {
    if (-not $state.hostingDeployedAt) {
      Invoke-ReleaseFirebase "hosting"
      $state.hostingDeployedAt = [DateTime]::UtcNow.ToString("o")
      Save-ReleaseState
    }
    Save-ProductionBaseline $baseline.workerImage (Get-FileHash -LiteralPath (Join-Path $root "build/web/main.dart.js")).Hash
  } else {
    if (-not $state.functionsDeployedAt) {
      Invoke-ReleaseFirebase "functions,firestore:rules,firestore:indexes"
      $state.functionsLiveIdentity = Get-LiveFunctionsIdentity
      $state.functionsDeployedAt = [DateTime]::UtcNow.ToString("o")
      Save-ReleaseState
    }
    Confirm-ReleaseBackend
    $state.functionsDeployedAt = [DateTime]::UtcNow.ToString("o")
    Save-ProductionBaseline $baseline.workerImage $baseline.webSha256
  }
  $state.deployedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
  Write-Host "$($state.scope) deployed and verified. Linked Play Games smoke remains required."
  return
}

if ($Action -eq "BuildImage") {
  $imageCache = Join-Path $cacheRoot "images/$ProjectId/$Region/$($inputs.worker).json"
  if (-not $state.buildId -and -not $Rebuild -and (Test-Path -LiteralPath $imageCache)) {
    $imageRecord = Get-Content -Raw -LiteralPath $imageCache | ConvertFrom-Json
    if ($imageRecord.workerInputs -ne $inputs.worker) { throw "Worker image cache input mismatch." }
    $state.buildId = $imageRecord.buildId
    $state.imageTag = $imageRecord.imageTag
    Save-ReleaseState
  }
  if ($state.buildId -and -not $Rebuild) {
    Get-ImageStatus | Out-Null
    return
  }
  $tag = "$Region-docker.pkg.dev/$ProjectId/replay/replay-validator:release-$($sourceDigest.Substring(0,12))-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
  $buildJson = Invoke-ReleaseGcloud @("builds", "submit", ".", "--project=$ProjectId", "--region=global",
    "--config=services/replay_validator/cloudbuild.yaml", "--substitutions=_IMAGE_URI=$tag", "--async", "--format=json") "submit"
  $build = $buildJson | ConvertFrom-Json
  if ((Get-ReleaseSourceDigest $root $ProjectId) -ne $sourceDigest) {
    throw "Release source changed while uploading the image. Cloud Build $($build.id) is untrusted; run Prepare again."
  }
  $state.workerDeployedAt = $null
  $state.deployedAt = $null
  $state.buildId = $build.id
  $state.imageTag = $tag
  $state.imageUri = ""
  $state.imageVerified = $false
  Save-ReleaseState
  Write-Host "Started Cloud Build $($state.buildId). Run ImageStatus; preparation need not be repeated."
  return
}
if ($Action -eq "ImageStatus") {
  Get-ImageStatus | Out-Null
  return
}
if ($Action -eq "PauseIssuance") {
  if (-not (Get-ImageStatus)) { throw "Image is still building; issuance was not paused." }
  Assert-ReleaseImage $state $ProjectId $Region
  $issuer = Get-ServingIssuerRevision
  $issuerImage = $issuer.revision.status.imageDigest
  if ($issuerImage -notmatch "^$([regex]::Escape("$Region-docker.pkg.dev/$ProjectId/"))[^@]+@sha256:[0-9a-f]{64}$") {
    throw "Serving issuer did not report a project-local immutable image; inspect production."
  }
  $imageExists = $true
  try {
    Invoke-ReleaseGcloud @("artifacts", "docker", "images", "describe", $issuerImage,
      "--project=$ProjectId", "--format=json(image_summary)") "issuance" | Out-Null
  } catch {
    if ($_.Exception.Message -notlike "*Image not found*") { throw }
    $imageExists = $false
  }
  if ($imageExists) {
    Invoke-ReleaseGcloud @("run", "services", "update", "runsessioncreate",
      "--project=$ProjectId", "--region=$Region", "--image=$issuerImage",
      "--update-env-vars=RUN_SUPPORTED_GAME_COMPAT_VERSIONS=release-paused", "--quiet") "issuance" | Out-Null
  } else {
    Write-Host "Previous issuer image was removed. Rebuilding prepared issuer with the explicit pause gate."
    Invoke-PausedIssuerRebuild
  }
  Assert-IssuancePaused
  $state.issuancePausedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
  Write-Host "Normal ticket issuance paused. Leave both queues running until validation and settlement drain."
  return
}

if (-not $CutoverReady) {
  throw "$Action requires -CutoverReady after release authorization and drain/cancellation review. See docs/tdd/deployment_workflow.md."
}
if (-not (Get-ImageStatus)) { throw "Cloud Build is still running; no production changes made." }
Assert-ReleaseImage $state $ProjectId $Region
Assert-IssuancePaused
$inventory = Get-ReleaseInventory
Assert-ReleaseDrained $inventory
if (-not $environment.REPLAY_STORAGE_BUCKET -or
    $environment.REPLAY_VALIDATION_QUEUE_LOCATION -ne $Region) {
  throw "Functions replay bucket/region configuration is missing or inconsistent."
}

if ($Action -eq "ResumeIssuance") {
  if (-not $state.deployedAt -or $inventory.boards.missingExpectedCurrentOrNextCount -ne 0) {
    throw "Artifacts or current/next boards are not ready. Complete Deploy and inspect board maintenance."
  }
  Assert-LiveReleaseArtifacts
  Confirm-ReleaseQueues "resume"
  Invoke-ReleaseFirebase "functions:runSessionCreate"
  # Firebase may preserve a runtime override. Remove only the temporary gate
  # after every consumer and queue is ready for the matching source.
  Invoke-ReleaseGcloud @("run", "services", "update", "runsessioncreate",
    "--project=$ProjectId", "--region=$Region",
    "--remove-env-vars=RUN_SUPPORTED_GAME_COMPAT_VERSIONS", "--quiet") "issuance" | Out-Null
  $state.issuanceResumedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
  Save-ProductionBaseline $state.imageUri (Get-FileHash -LiteralPath (Join-Path $root "build/web/main.dart.js")).Hash
  Write-Host "Ticket issuance restored. Linked Play Games end-to-end smoke remains required."
  return
}

# Repair/settlement surfaces and indexes must exist before the matching worker.
Confirm-ReleaseQueues "pause"
if (-not $state.functionsDeployedAt) {
  $exports = [regex]::Matches(
    (Get-Content -Raw -LiteralPath (Join-Path $root "functions/src/index.ts")),
    'export const ([A-Za-z][A-Za-z0-9_]*)\s*='
  )
  $targets = @($exports | ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -ne "runSessionCreate" } | ForEach-Object { "functions:$_" })
  if ($targets.Count -eq 0) { throw "Cannot identify Functions exports." }
  Invoke-ReleaseFirebase (($targets + @("firestore:rules", "firestore:indexes")) -join ",")
  $state.functionsDeployedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
}
Assert-IssuancePaused
Confirm-ReleaseBackend
$cloudScript = Join-Path $root "services/replay_validator/configure_cloud.ps1"
if (-not $state.workerDeployedAt) {
  $cloudArguments = @{
    ProjectId = $ProjectId; Region = $Region
    ReplayStorageBucket = $environment.REPLAY_STORAGE_BUCKET; ImageUri = $state.imageUri
    SettlementDispatchUrl = "https://$Region-$ProjectId.cloudfunctions.net/runSettlementImmediate"
  }
  & $cloudScript @cloudArguments
  $state.workerDeployedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
}
Assert-IssuancePaused
Invoke-ReleaseGcloud @("scheduler", "jobs", "run", "firebase-schedule-leaderboardBoardMaintenance-$Region",
  "--project=$ProjectId", "--location=$Region", "--quiet") "boards" | Out-Null
if (-not $state.hostingDeployedAt) {
  Invoke-ReleaseFirebase "hosting"
  $state.hostingDeployedAt = [DateTime]::UtcNow.ToString("o")
  Save-ReleaseState
}
$state.deployedAt = [DateTime]::UtcNow.ToString("o")
Save-ReleaseState
Write-Host "Artifacts deployed. Issuance and both queues remain paused. Verify board maintenance, then run ResumeIssuance -CutoverReady and linked Play Games smoke checks."
Write-Host "Release evidence: $statePath"
