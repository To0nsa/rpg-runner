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
$global:fakeIssuerImageUri = "europe-west1-docker.pkg.dev/test-project/gcf-artifacts/issuer@sha256:$('b' * 64)"
$global:fakeIssuerHealthy = $true
$global:fakeIssuerSplitTraffic = $false
$global:fakeMissingIssuerImage = $false
$global:fakeIssuerDeployFails = $false
$global:fakeArtifactLookupDenied = $false
$global:fakeFirebaseDebug = $false
$global:fakeIndexesReady = $true
$global:fakeFunctionsVersion = '2026-10-01T00:00:00Z'
$script:passed = 0
$global:mockFiles = @(
  "tools/release/release.ps1", "tools/release/release_support.ps1", "tools/release/release_cache.ps1",
  "tools/release/prepare_release.ps1", "tools/release/profile_tests.ps1", "tools/release/release_ci.ps1",
  "functions/src/index.ts", "functions/src/runs/compatibility.ts",
  "functions/src/boards/provisioning.ts", "lib/ui/state/app/app_state.dart",
  "services/replay_validator/lib/src/validator_worker.dart", "firebase.json", ".firebaserc"
)

function git {
  $global:LASTEXITCODE = 0
  if (($args -join ' ') -like '*--git-common-dir*') { return Join-Path $fixture '.git' }
  if (($args -join ' ') -like 'rev-parse*') { return 'c' * 40 }
  return $global:mockFiles
}
function corepack {
  if (($args -join ' ') -match '--only functions,firestore:rules') { $global:fakeFunctionsVersion='2026-10-02T00:00:00Z' }
  $global:fakeFirebaseDebug = [bool]$env:DEBUG
  $global:releaseTrace.Add("firebase " + ($args -join " "))
  $global:LASTEXITCODE = 0
  if (($args -join " ") -match 'functions:runSessionCreate(,|\s|$)') {
    $envValues = Read-ReleaseEnvironment $fixture "test-project"
    $global:fakeIssuancePaused = $envValues.ContainsKey("RUN_SUPPORTED_GAME_COMPAT_VERSIONS") -and
      $envValues.RUN_SUPPORTED_GAME_COMPAT_VERSIONS -eq "release-paused"
    if ($global:fakeIssuerDeployFails) { $global:LASTEXITCODE = 7; return "Mock issuer rebuild failed" }
    $global:fakeIssuerHealthy = $true
  }
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
    $global:fakeIssuerHealthy = $true
    return "{}"
  }
  if ($command.StartsWith("run services describe runsessioncreate")) {
    # A failed update can leave the desired template paused while old live
    # traffic remains unpaused. Only the serving revision establishes the gate.
    return (@{
      spec = @{template=@{spec=@{containers=@(@{env=@(@{name="RUN_SUPPORTED_GAME_COMPAT_VERSIONS";value="release-paused"})})}}}
      status = @{
        latestReadyRevisionName="issuer-ready"
        latestCreatedRevisionName=$(if ($global:fakeIssuerHealthy) {"issuer-ready"} else {"issuer-failed"})
        conditions=@(@{type="Ready";status=$(if ($global:fakeIssuerHealthy) {"True"} else {"False"})})
        traffic=$(if ($global:fakeIssuerSplitTraffic) {
          @(@{revisionName="issuer-ready";percent=50},@{revisionName="old-issuer";percent=50})
        } else { @(@{revisionName="issuer-ready";percent=100}) })
      }
    } | ConvertTo-Json -Depth 15)
  }
  if ($command.StartsWith("run revisions describe issuer-ready")) {
    return (@{
      status=@{imageDigest=$global:fakeIssuerImageUri}
      spec=@{containers=@(@{env=@(@{name=$(if ($global:fakeIssuancePaused) {'RUN_SUPPORTED_GAME_COMPAT_VERSIONS'} else {'GCLOUD_PROJECT'});value=$(if ($global:fakeIssuancePaused) {'release-paused'} else {'test-project'})})})}
    } | ConvertTo-Json -Depth 10)
  }
  if ($command.StartsWith("artifacts docker images describe")) {
    if ($global:fakeArtifactLookupDenied) { $global:LASTEXITCODE=1; return "PERMISSION_DENIED" }
    if ($global:fakeMissingIssuerImage) { $global:LASTEXITCODE=1; return "Image not found." }
    return "{}"
  }
  if ($command.StartsWith("run services describe replay-validator")) {
    return (@{status=@{latestCreatedRevisionName="ready";latestReadyRevisionName="ready";conditions=@(@{type="Ready";status="True"});traffic=@(@{revisionName="ready";percent=100})}} | ConvertTo-Json -Depth 10)
  }
  if ($command.StartsWith("run revisions describe ready")) { return $global:fakeImageUri }
  if ($command.Contains("get-iam-policy")) {
    return '{"bindings":[{"role":"roles/run.invoker","members":["serviceAccount:private"]}]}'
  }
  if ($command.StartsWith("firestore indexes")) { if ($global:fakeIndexesReady) { return "[]" }; return '[{"state":"CREATING"}]' }
  if ($command.StartsWith("tasks queues describe")) { return 'RUNNING' }
  if ($command.StartsWith("functions list")) {
    $exports = [regex]::Matches((Get-Content -Raw (Join-Path $fixture 'functions/src/index.ts')), 'export const ([A-Za-z][A-Za-z0-9_]*)\s*=')
    return (@($exports | ForEach-Object { @{ name = "projects/test-project/locations/europe-west1/functions/$($_.Groups[1].Value)"; state = "ACTIVE"; updateTime = $global:fakeFunctionsVersion } }) | ConvertTo-Json -Depth 5)
  }
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
  $script:passed += 1
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
    schemaVersion=2; scope="Coordinated"; inputs=@{}; components=@(); functionsLiveIdentity=""; projectId="test-project"; region="europe-west1"; sourceDigest=$source
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
  try { & $entry -Action Deploy -CutoverReady } catch {
    $rejected = $_.Exception.Message -like "*not paused*"
    if (-not $rejected) { throw }
  }
  Assert-Test $rejected "deployment requires verified issuance pause"
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like "firebase *" }).Count -eq 0) "unpaused deployment makes no Firebase changes"

  $global:fakeIssuerHealthy = $false
  $rejected = $false
  try { & $entry -Action Deploy -CutoverReady } catch { $rejected = $_.Exception.Message -like "*healthy current revision*" }
  Assert-Test $rejected "failed paused template cannot establish a live issuance pause"
  $global:fakeIssuerHealthy = $true
  $global:fakeIssuerSplitTraffic = $true
  $rejected = $false
  try { & $entry -Action Deploy -CutoverReady } catch { $rejected = $_.Exception.Message -like "*Issuer traffic*" }
  Assert-Test $rejected "split issuer traffic blocks cutover"
  $global:fakeIssuerSplitTraffic = $false

  $global:fakeArtifactLookupDenied = $true
  $rejected = $false
  try { & $entry -Action PauseIssuance } catch { $rejected = $_.Exception.Message -like "*PERMISSION_DENIED*" }
  Assert-Test ($rejected -and @($global:releaseTrace | Where-Object { $_ -like "firebase *" }).Count -eq 0) "registry access failure does not trigger an issuer rebuild"
  $global:fakeArtifactLookupDenied = $false
  $global:fakeMissingIssuerImage = $true
  $envPath = Join-Path $fixture "functions/.env.test-project"
  $envBefore = (Get-FileHash -LiteralPath $envPath).Hash
  $savedDebug = $env:DEBUG
  $env:DEBUG = "true"
  try {
    & $entry -Action PauseIssuance
    Assert-Test ($env:DEBUG -eq "true" -and -not $global:fakeFirebaseDebug) "Firebase deployment suppresses inherited debug responses and restores the caller setting"
  } finally { $env:DEBUG = $savedDebug }
  Assert-Test $global:fakeIssuancePaused "removed issuer image is rebuilt with a deployed pause gate"
  Assert-Test ((Get-FileHash -LiteralPath $envPath).Hash -eq $envBefore -and
    (Get-ReleaseSourceDigest $fixture "test-project") -eq $source) "successful issuer recovery restores the original environment bytes and source fingerprint"
  $global:fakeIssuerDeployFails = $true
  $rejected = $false
  try { & $entry -Action PauseIssuance } catch { $rejected = $_.Exception.Message -like "*failed (7)*" }
  Assert-Test ($rejected -and (Get-FileHash -LiteralPath $envPath).Hash -eq $envBefore) "failed issuer recovery also restores the original environment bytes"
  $global:fakeIssuerDeployFails = $false
  $global:fakeMissingIssuerImage = $false
  $global:releaseTrace.Clear()

  & $entry -Action PauseIssuance
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like "run services update runsessioncreate*--image=$($global:fakeIssuerImageUri)*" }).Count -eq 1) "runtime pause pins the serving immutable issuer image"
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

  # A second checkout with a UI-only delta uses the verified baseline written
  # by ResumeIssuance, and must not touch the worker, queues or ticket issuer.
  $global:mockFiles += 'lib/ui/menu.dart'
  'new menu' | Set-Content -LiteralPath (Join-Path $fixture 'lib/ui/menu.dart')
  $source = Get-ReleaseSourceDigest $fixture 'test-project'
  $evidence = Join-Path $fixture ".tmp/releases/test-project/$source"
  New-Item -ItemType Directory -Force -Path $evidence | Out-Null
  $scopedState = [pscustomobject]@{
    schemaVersion=2;scope='Hosting';projectId='test-project';region='europe-west1';sourceDigest=$source
    prepared=$true;preparedAt=$null;inputs=@{};components=@();functionsLiveIdentity='';functionsDigest='';webDigest=(Get-ReleaseTreeDigest (Join-Path $fixture 'build/web'))
    functionsDeployedAt=$null;workerDeployedAt=$null;hostingDeployedAt=$null;deployedAt=$null
  }
  $scopedState | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'release.json')
  $global:releaseTrace.Clear()
  $global:fakeIssuancePaused=$true
  $rejected=$false
  try { & $entry -Action Deploy } catch { $rejected=$_.Exception.Message -like '*compatibility override*' }
  Assert-Test ($rejected -and @($global:releaseTrace | Where-Object { $_ -like 'firebase *' }).Count -eq 0) 'scoped deploy refuses a paused issuer before mutations'
  $global:fakeIssuancePaused=$false
  $global:releaseTrace.Clear()
  & $entry -Action Deploy
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like 'firebase *' }).Count -eq 1 -and
    @($global:releaseTrace | Where-Object { $_ -match 'builds|tasks queues (pause|resume)|run services update|configure matching' }).Count -eq 0) 'Hosting-only release deploys once without image, queue or issuer mutations'
  & $entry -Action Prepare
  $after = Get-Content -Raw (Join-Path $evidence 'release.json') | ConvertFrom-Json
  Assert-Test ($after.scope -eq 'None') 'successful scoped release advances the runtime baseline'
  $global:mockFiles += 'functions/src/profiles/profile.ts'
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'functions/src/profiles') | Out-Null
  'profile change' | Set-Content -LiteralPath (Join-Path $fixture 'functions/src/profiles/profile.ts')
  $source = Get-ReleaseSourceDigest $fixture 'test-project'
  $evidence = Join-Path $fixture ".tmp/releases/test-project/$source"
  New-Item -ItemType Directory -Force -Path $evidence | Out-Null
  $scopedState.sourceDigest=$source; $scopedState.scope='Backend'; $scopedState.webDigest=''
  $scopedState.functionsDigest=Get-ReleaseTreeDigest (Join-Path $fixture 'functions/lib')
  $scopedState | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'release.json')
  $global:releaseTrace.Clear(); $global:fakeIndexesReady=$false
  $rejected=$false
  try { & $entry -Action Deploy } catch { $rejected=$_.Exception.Message -like '*indexes are still building*' }
  Assert-Test $rejected 'backend-only release stops while indexes build'
  $global:fakeIndexesReady=$true
  & $entry -Action Deploy
  Assert-Test (@($global:releaseTrace | Where-Object { $_ -like 'firebase *' }).Count -eq 1 -and
    @($global:releaseTrace | Where-Object { $_ -match 'builds|tasks queues (pause|resume)|run services update|configure matching' }).Count -eq 0) 'backend retry reuses deployed Functions without worker/Hosting/queue cutover'
  Write-Host "$script:passed mocked release integration checks passed; no cloud commands executed."
} finally {
  $resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
  $allowedPrefix = (Join-Path $workspaceRoot ".tmp/release-tests").TrimEnd('\') + '\'
  if (-not $resolvedFixture.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove fixture outside the test workspace."
  }
  Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
  foreach ($name in @("releaseTrace", "fakeIssuancePaused", "fakeActiveRuns", "fakeBuildStatus", "fakeImageTag", "fakeImageUri", "mockFiles",
    "fakeIssuerImageUri", "fakeIssuerHealthy", "fakeIssuerSplitTraffic", "fakeMissingIssuerImage", "fakeIssuerDeployFails", "fakeArtifactLookupDenied", "fakeFirebaseDebug", "fakeIndexesReady", "fakeFunctionsVersion")) {
    Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
  }
}
