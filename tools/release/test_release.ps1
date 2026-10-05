[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "release_support.ps1")
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
$fixture = Join-Path $root ".tmp/release-tests/$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$script:passed = 0

function Assert-True {
  param([bool]$Value, [string]$Name)
  if (-not $Value) { throw "FAIL: $Name" }
  $script:passed += 1
  Write-Host "PASS: $Name"
}
function Assert-Throws {
  param([scriptblock]$Operation, [string]$Message, [string]$Name)
  $caught = $null
  try { & $Operation | Out-Null } catch { $caught = $_ }
  Assert-True ($null -ne $caught -and $caught.Exception.Message -like "*$Message*") $Name
}

try {
  foreach ($relative in @("lib/ui/state/app/app_state.dart", "functions/src/runs/compatibility.ts",
    "functions/src/boards/provisioning.ts", "services/replay_validator/lib/src/validator_worker.dart")) {
    $target = Join-Path $fixture $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
  }
  $contract = Get-ReleaseContract $fixture "test-project"
  Assert-True ($contract.gameCompatVersion -and $contract.scoreVersion -eq "score-v3") "current release tuple aligns"

  $clientPath = Join-Path $fixture "lib/ui/state/app/app_state.dart"
  $originalClient = Get-Content -Raw -LiteralPath $clientPath
  $originalClient.Replace($contract.gameCompatVersion, "incompatible") | Set-Content -LiteralPath $clientPath
  Assert-Throws { Get-ReleaseContract $fixture "test-project" } "versions differ" "reject client/backend drift"
  $originalClient | Set-Content -LiteralPath $clientPath

  $workerPath = Join-Path $fixture "services/replay_validator/lib/src/validator_worker.dart"
  $originalWorker = Get-Content -Raw -LiteralPath $workerPath
  $originalWorker.Replace("'$($contract.gameCompatVersion)'", "'$($contract.gameCompatVersion)', 'legacy'") | Set-Content -LiteralPath $workerPath
  Assert-Throws { Get-ReleaseContract $fixture "test-project" } "one supported" "reject historical worker support assumption"
  $originalWorker | Set-Content -LiteralPath $workerPath

  "RUN_SUPPORTED_GAME_COMPAT_VERSIONS=legacy" | Set-Content -LiteralPath (Join-Path $fixture "functions/.env.test-project")
  Assert-Throws { Get-ReleaseContract $fixture "test-project" } "Stale Functions override" "reject stale environment allowlist"
  "" | Set-Content -LiteralPath (Join-Path $fixture "functions/.env.test-project")

  foreach ($relative in @("functions/lib/index.js", "build/web/index.html")) {
    $target = Join-Path $fixture $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    "artifact" | Set-Content -LiteralPath $target
  }
  $state = [pscustomobject]@{
    schemaVersion = 2; scope = "Coordinated"; projectId = "test-project"; region = "europe-west1"
    sourceDigest = "source-a"; prepared = $true
    functionsDigest = Get-ReleaseTreeDigest (Join-Path $fixture "functions/lib")
    webDigest = Get-ReleaseTreeDigest (Join-Path $fixture "build/web")
    imageUri = "europe-west1-docker.pkg.dev/test-project/replay/replay-validator@sha256:$('a' * 64)"
    imageVerified = $true
  }
  Assert-ReleasePrepared $state "source-a" "test-project" "europe-west1" $fixture
  Assert-True $true "accept unchanged prepared artifacts"
  Assert-Throws { Assert-ReleasePrepared $state "source-b" "test-project" "europe-west1" $fixture } "Run Prepare" "reject changed source"
  Assert-Throws { Assert-ReleasePrepared $state "source-a" "other-project" "europe-west1" $fixture } "Run Prepare" "reject cross-project evidence"
  "tampered" | Set-Content -LiteralPath (Join-Path $fixture "build/web/index.html")
  Assert-Throws { Assert-ReleasePrepared $state "source-a" "test-project" "europe-west1" $fixture } "artifacts changed" "reject tampered web artifact"
  "artifact" | Set-Content -LiteralPath (Join-Path $fixture "build/web/index.html")
  "extra" | Set-Content -LiteralPath (Join-Path $fixture "functions/lib/extra.js")
  Assert-Throws { Assert-ReleasePrepared $state "source-a" "test-project" "europe-west1" $fixture } "artifacts changed" "reject added Functions artifact"
  Remove-Item -LiteralPath (Join-Path $fixture "functions/lib/extra.js")

  $inventory = [pscustomobject]@{
    readOnly = $true
    runs = [pscustomobject]@{
      sessionStateCounts = [pscustomobject]@{ validated = 1; cancelled = 2 }
      rewardGrantStateCounts = [pscustomobject]@{ validated_settled = 1 }
      quarantinedSettlementCount = 0
    }
  }
  Assert-ReleaseDrained $inventory
  Assert-True $true "permit drained inventory including cancelled runs"
  $inventory.runs.sessionStateCounts = [pscustomobject]@{ validating = 1 }
  Assert-Throws { Assert-ReleaseDrained $inventory } "Cutover blocked" "reject live validator lease/session"
  $inventory.runs.sessionStateCounts = [pscustomobject]@{ unexpected = 1 }
  Assert-Throws { Assert-ReleaseDrained $inventory } "Cutover blocked" "reject unknown run state"
  $inventory.runs.sessionStateCounts = [pscustomobject]@{ validated = 1 }
  $inventory.runs.rewardGrantStateCounts = [pscustomobject]@{ settlement_pending = 1 }
  Assert-Throws { Assert-ReleaseDrained $inventory } "unsettled" "reject unsettled grant"
  $inventory.runs.rewardGrantStateCounts = [pscustomobject]@{ validated_settled = 1 }
  $inventory.runs.quarantinedSettlementCount = 1
  Assert-Throws { Assert-ReleaseDrained $inventory } "quarantined" "reject quarantined settlement"

  Assert-ReleaseImage $state "test-project" "europe-west1"
  Assert-True $true "permit verified immutable image"
  $state.imageUri = "europe-west1-docker.pkg.dev/test-project/replay/replay-validator:latest"
  Assert-Throws { Assert-ReleaseImage $state "test-project" "europe-west1" } "immutable image" "reject mutable image tag"
  $state.imageUri = "europe-west1-docker.pkg.dev/other-project/replay/replay-validator@sha256:$('a' * 64)"
  Assert-Throws { Assert-ReleaseImage $state "test-project" "europe-west1" } "immutable image" "reject foreign image repository"

  Assert-Throws { Invoke-ReleaseCommand node @("-e", "process.exit(7)") $root } "failed (7)" "propagate native command failure"
  $jsonOutput = Invoke-ReleaseCommand node @("-e", "process.stderr.write('warning'); process.stdout.write(JSON.stringify({ok:true}));") $root
  Assert-True (($jsonOutput | ConvertFrom-Json).ok -eq $true) "native warnings do not corrupt JSON output"
  $hashA = Get-ReleaseFileDigest $fixture @("functions/lib/index.js")
  "different" | Set-Content -LiteralPath (Join-Path $fixture "functions/lib/index.js")
  $hashB = Get-ReleaseFileDigest $fixture @("functions/lib/index.js")
  Assert-True ($hashA -ne $hashB) "content changes invalidate fingerprint"

  foreach ($path in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1")) {
    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-True ($parseErrors.Count -eq 0) "PowerShell syntax: $($path.Name)"
  }
  Write-Host "$script:passed release checks passed."
} finally {
  $resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
  $allowedPrefix = (Join-Path $root ".tmp/release-tests").TrimEnd('\') + '\'
  if (-not $resolvedFixture.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove fixture outside the test workspace."
  }
  Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
