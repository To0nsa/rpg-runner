[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot "release_support.ps1")
$workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
$fixture = Join-Path $workspaceRoot ".tmp/release-tests/$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$global:releaseTrace = [System.Collections.Generic.List[string]]::new()
$global:fakeIssuancePaused = $false
$global:fakeActiveRuns = $false
$global:fakeBuildStatus = "SUCCESS"
$global:fakeImageTag = ""
$global:fakeImageUri = "europe-west1-docker.pkg.dev/test-project/replay/replay-validator@sha256:$('a' * 64)"
$global:mockFiles = @(
  "tools/release/release.ps1", "tools/release/release_support.ps1",
  "functions/src/index.ts", "functions/src/runs/compatibility.ts",
  "functions/src/boards/provisioning.ts", "lib/ui/state/app/app_state.dart",
  "services/replay_validator/lib/src/validator_worker.dart", "firebase.json", ".firebaserc"
)

function git {
  $global:LASTEXITCODE = 0
  return $global:mockFiles
}
function corepack {
  $global:releaseTrace.Add("firebase " + ($args -join " "))
  $global:LASTEXITCODE = 0
  return "Mock Firebase success"
}
function node {
  $global:LASTEXITCODE = 0
  return ([ordered]@{
    readOnly = $true; projectId = "test-project"
    runs = @{
      sessionStateCounts = $(if ($global:fakeActiveRuns) { @{ validating = 1 } } else { @{ cancelled = 2 } })
      rewardGrantStateCounts = @{ validated_settled = 1 }
      quarantinedSettlementCount = 0
    }
    boards = @{ missingExpectedCurrentOrNextCount = 0 }
  } | ConvertTo-Json -Depth 10)
}
function gcloud {
  $global:LASTEXITCODE = 0
  $command = $args -join " "
  $global:releaseTrace.Add($command)
  if ($command.StartsWith("builds submit")) {
    $global:fakeImageTag = ($args | Where-Object { $_ -like "--substitutions=*" }).Substring("--substitutions=_IMAGE_URI=".Length)
    return '{"id":"build-1"}'
  }
  if ($command.StartsWith("builds describe")) {
    return (@{ status = $global:fakeBuildStatus; logUrl = "mock://logs"
      results = @{ images = @(@{name=$global:fakeImageTag; digest="sha256:$('a' * 64)"}) }
    } | ConvertTo-Json -Depth 10)
  }
  if ($command.StartsWith("run services update runsessioncreate")) {
    if ($command.Contains("--update-env-vars=")) { $global:fakeIssuancePaused = $true }
    if ($command.Contains("--remove-env-vars=")) { $global:fakeIssuancePaused = $false }
    return "{}"
  }
  if ($command.StartsWith("run services describe runsessioncreate")) {
    return (@{ spec = @{ template = @{ spec = @{ containers = @(@{
      env = @(@{name="RUN_SUPPORTED_GAME_COMPAT_VERSIONS";value=$(if ($global:fakeIssuancePaused) {"release-paused"} else {"normal"})})
    }) } } } } | ConvertTo-Json -Depth 15)
  }
  if ($command.StartsWith("run services describe replay-validator")) {
    return (@{status=@{latestReadyRevisionName="ready";traffic=@(@{revisionName="ready";percent=100})}} | ConvertTo-Json -Depth 10)
  }
  if ($command.StartsWith("run revisions describe ready")) { return $global:fakeImageUri }
  if ($command.Contains("get-iam-policy")) {
    return '{"bindings":[{"role":"roles/run.invoker","members":["serviceAccount:private"]}]}'
  }
  if ($command.StartsWith("firestore indexes")) { return "[]" }
  return "{}"
}
function Invoke-WebRequest {
  param($Uri, $Headers, $OutFile, [switch]$UseBasicParsing)
  $global:releaseTrace.Add("hosting byte check")
  Copy-Item -LiteralPath (Join-Path $fixture "build/web/main.dart.js") -Destination $OutFile
}
function Assert-Test {
  param([bool]$Value, [string]$Message)
  if (-not $Value) { throw "FAIL: $Message" }
  Write-Host "PASS: $Message"
}

try {
  foreach ($relative in $global:mockFiles) {
    $target = Join-Path $fixture $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $workspaceRoot $relative) -Destination $target
  }
  '{"projects":{"default":"test-project"}}' | Set-Content -LiteralPath (Join-Path $fixture ".firebaserc")
  '{"hosting":{"site":"test-project"}}' | Set-Content -LiteralPath (Join-Path $fixture "firebase.json")
  @("REPLAY_STORAGE_BUCKET=test-bucket", "REPLAY_VALIDATION_QUEUE_LOCATION=europe-west1") |
    Set-Content -LiteralPath (Join-Path $fixture "functions/.env.test-project")
  $cloudScript = Join-Path $fixture "services/replay_validator/configure_cloud.ps1"
  '$global:releaseTrace.Add("configure matching worker")' | Set-Content -LiteralPath $cloudScript
  foreach ($relative in @("functions/lib/index.js", "build/web/main.dart.js")) {
    $target = Join-Path $fixture $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    "artifact" | Set-Content -LiteralPath $target
  }
  $source = Get-ReleaseSourceDigest $fixture "test-project"
  $evidence = Join-Path $fixture ".tmp/releases/test-project/$source"
  New-Item -ItemType Directory -Force -Path $evidence | Out-Null
  [pscustomobject]@{
    schemaVersion=1; projectId="test-project"; region="europe-west1"; sourceDigest=$source
    contract=(Get-ReleaseContract $fixture "test-project"); prepared=$true; preparedAt="fixture"
    toolchain="fixture"; functionsDigest=(Get-ReleaseTreeDigest (Join-Path $fixture "functions/lib"))
    webDigest=(Get-ReleaseTreeDigest (Join-Path $fixture "build/web"))
    buildId=""; imageTag=""; imageUri=""; imageVerified=$false; deployedAt=$null
    functionsDeployedAt=$null; workerDeployedAt=$null; hostingDeployedAt=$null
    issuancePausedAt=$null; issuanceResumedAt=$null
  } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidence "release.json")
  $entry = Join-Path $fixture "tools/release/release.ps1"
  & $entry -Action BuildImage
  & $entry -Action ImageStatus

  $rejected = $false
  try { & $entry -Action Deploy } catch { $rejected = $_.Exception.Message -like "*requires -CutoverReady*" }
  Assert-Test $rejected "deployment requires explicit cutover review"

  $rejected = $false
  try { & $entry -Action Deploy -CutoverReady } catch { $rejected = $_.Exception.Message -like "*not paused*" }
  Assert-Test $rejected "deployment requires verified issuance pause"
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like "firebase *" }).Count -eq 0) "unpaused deployment makes no Firebase changes"

  & $entry -Action PauseIssuance
  $global:fakeActiveRuns = $true
  $rejected = $false
  try { & $entry -Action Deploy -CutoverReady } catch { $rejected = $_.Exception.Message -like "*Cutover blocked*" }
  Assert-Test $rejected "active-run inventory blocks production cutover"
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like "tasks queues pause*" }).Count -eq 0) "queues keep draining while active runs remain"
  $global:fakeActiveRuns = $false
  $global:fakeBuildStatus = "FAILURE"
  $rejected = $false
  try { & $entry -Action Deploy -CutoverReady } catch { $rejected = $_.Exception.Message -like "*Cloud Build failed*" }
  Assert-Test $rejected "failed remote benchmark/build blocks deployment"
  $global:fakeBuildStatus = "SUCCESS"
  & $entry -Action Deploy -CutoverReady
  $firebaseChanges = @($global:releaseTrace | Where-Object { $_ -like "firebase *" })
  Assert-Test ($firebaseChanges[0] -notmatch 'functions:runSessionCreate(,|\s)' -and
    $firebaseChanges[0] -match 'functions:runSettlementImmediate') "backend deploy excludes ticket issuer and includes settlement"
  Assert-Test ($global:releaseTrace.IndexOf($firebaseChanges[0]) -lt
    $global:releaseTrace.IndexOf("configure matching worker")) "settlement deploy precedes matching worker"
  Assert-Test ($global:fakeIssuancePaused) "Deploy leaves ticket issuance paused"
  & $entry -Action Deploy -CutoverReady
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like "firebase *" }).Count -eq 2) "retry reuses completed backend and Hosting checkpoints"
  & $entry -Action ResumeIssuance -CutoverReady
  $issuer = @($global:releaseTrace | Where-Object { $_ -match "functions:runSessionCreate(,|\s|$)" })
  Assert-Test ($issuer.Count -eq 1 -and
    $global:releaseTrace.IndexOf("hosting byte check") -lt $global:releaseTrace.IndexOf($issuer[0])) "live artifact verification precedes ticket issuer deployment"
  Assert-Test (-not $global:fakeIssuancePaused) "explicit ResumeIssuance removes temporary runtime gate"
  Write-Host "12 mocked release integration checks passed; no cloud commands executed."
} finally {
  $resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
  $allowedPrefix = (Join-Path $workspaceRoot ".tmp/release-tests").TrimEnd('\') + '\'
  if (-not $resolvedFixture.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove fixture outside the test workspace."
  }
  Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
  foreach ($name in @("releaseTrace", "fakeIssuancePaused", "fakeActiveRuns", "fakeBuildStatus", "fakeImageTag", "fakeImageUri", "mockFiles")) {
    Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
  }
}
