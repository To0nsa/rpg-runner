[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_environments.ps1')
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture = Join-Path $workspace ".tmp/release-tests/$([Guid]::NewGuid().ToString('N'))"
$passed = 0
function Assert-EnvironmentTest {
  param([bool]$Value, [string]$Description)
  if (-not $Value) { throw "FAIL: $Description" }
  $script:passed++; Write-Host "PASS: $Description"
}
function Assert-EnvironmentThrows {
  param([scriptblock]$Operation, [string]$Pattern, [string]$Description)
  $failure = $null
  try { & $Operation | Out-Null } catch { $failure = $_ }
  Assert-EnvironmentTest ($failure -and $failure.Exception.Message -like "*$Pattern*") $Description
}
try {
  foreach ($relative in @('.firebaserc', 'firebase.json', 'firebase.staging.json', 'firebase.prod.json', 'tools/release/environments.json')) {
    $target = Join-Path $fixture $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $workspace $relative) -Destination $target
  }
  foreach ($name in @('dev', 'staging', 'prod')) {
    $definition = Get-ReleaseEnvironmentDefinition $fixture $name
    $values = @{
      REPLAY_STORAGE_BUCKET = $definition.replayBucket
      REPLAY_VALIDATION_QUEUE_LOCATION = $definition.region
      REPLAY_VALIDATOR_URL = "https://replay-validator-$name.run.app"
      REPLAY_VALIDATOR_SERVICE_ACCOUNT = "sa-replay-validator@$($definition.projectId).iam.gserviceaccount.com"
      REPLAY_TASK_DISPATCH_SERVICE_ACCOUNT = "sa-replay-task-dispatch@$($definition.projectId).iam.gserviceaccount.com"
    }
    $definition.workerUrl = $values.REPLAY_VALIDATOR_URL
    Assert-ReleaseEnvironmentValues $definition $values -RequireConfiguration
    Assert-EnvironmentTest $true "$name accepts its own resources"
    Assert-EnvironmentThrows { Get-ReleaseEnvironmentDefinition $fixture $name 'other-project' } 'contradict' "$name rejects project override"
    Assert-EnvironmentThrows { Get-ReleaseEnvironmentDefinition $fixture $name '' 'us-central1' } 'contradict' "$name rejects region override"
    foreach ($key in @('REPLAY_STORAGE_BUCKET', 'REPLAY_VALIDATOR_URL', 'REPLAY_VALIDATOR_SERVICE_ACCOUNT', 'REPLAY_TASK_DISPATCH_SERVICE_ACCOUNT')) {
      $invalid = $values.Clone(); $invalid[$key] = 'another-environment'
      Assert-EnvironmentThrows { Assert-ReleaseEnvironmentValues $definition $invalid -RequireConfiguration } 'mismatch' "$name rejects foreign $key"
    }
    $invalid = $values.Clone(); $invalid.REPLAY_VALIDATOR_TASK_URL = 'https://replay-validator-other.run.app/tasks/validate'
    Assert-EnvironmentThrows { Assert-ReleaseEnvironmentValues $definition $invalid -RequireConfiguration } 'contradicts' "$name rejects foreign task URL"
    Assert-EnvironmentThrows { Assert-ReleaseEnvironmentValues $definition @{} -RequireConfiguration } 'Missing environment' "$name requires complete configuration"
  }
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'functions') | Out-Null
  'REPLAY_STORAGE_BUCKET=dev-only-bucket' | Set-Content -LiteralPath (Join-Path $fixture 'functions/.env')
  Assert-EnvironmentTest ((Read-ReleaseEnvironment $fixture 'missing-project').Count -eq 0) 'missing project file cannot inherit shared dev configuration'
  $registryPath = Join-Path $fixture 'tools/release/environments.json'
  $registry = Get-Content -Raw $registryPath | ConvertFrom-Json
  $registry.environments.prod.replayBucket = $registry.environments.dev.replayBucket
  $registry | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $registryPath
  Assert-EnvironmentThrows { Get-ReleaseEnvironmentDefinition $fixture prod } 'share replayBucket' 'registry rejects shared replay storage'
  Write-Host "$passed environment isolation checks passed; no cloud commands executed."
} finally {
  $resolved = [IO.Path]::GetFullPath($fixture)
  $allowed = [IO.Path]::GetFullPath((Join-Path $workspace '.tmp/release-tests')).TrimEnd('\') + '\'
  if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
