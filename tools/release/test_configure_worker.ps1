[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture = Join-Path $workspace ".tmp/worker-config-tests/$([Guid]::NewGuid().ToString('N'))"
$trace = [System.Collections.Generic.List[string]]::new()
$image = "europe-west1-docker.pkg.dev/test-project/replay/replay-validator@sha256:$('a' * 64)"
# The child script resolves this function instead of the cloud CLI.
function gcloud {
  $global:LASTEXITCODE = 0
  $command = $args -join ' '
  $trace.Add($command)
  if ($command -like '*--format=value(status.latestReadyRevisionName)*') { return 'worker-ready' }
  if ($command -like '*--format=value(status.imageDigest)*') { return $image }
  if ($command -like '*--format=value(status.url)*') { return 'https://worker-test.run.app' }
  return '{}'
}
try {
  $serviceDirectory = Join-Path $fixture 'services/replay_validator'
  $cloudDirectory = Join-Path $fixture 'tools/cloud'
  New-Item -ItemType Directory -Force -Path $serviceDirectory, $cloudDirectory | Out-Null
  Copy-Item -LiteralPath (Join-Path $workspace 'services/replay_validator/configure_cloud.ps1') -Destination $serviceDirectory
  '$global:LASTEXITCODE = 0' | Set-Content -LiteralPath (Join-Path $cloudDirectory 'apply_retention_policies.ps1')
  & (Join-Path $serviceDirectory 'configure_cloud.ps1') -ProjectId test-project -ReplayStorageBucket test-bucket -ImageUri $image -SettlementDispatchUrl https://example.test/settle
  $deploy = @($trace | Where-Object { $_ -like 'run deploy *' })
  if ($deploy.Count -ne 1) { throw 'Expected one worker deployment.' }
  foreach ($flag in @('--min-instances=0', '--min=0', '--scaling=auto', '--cpu-throttling',
      '--no-allow-unauthenticated', 'SETTLEMENT_DELIVERY_MODE=eventarc')) {
    if (-not $deploy[0].Contains($flag)) { throw "Missing deployment policy: $flag" }
  }
  if (@($trace | Where-Object { $_ -like 'tasks queues resume *' -or $_ -like 'tasks queues pause *' }).Count -ne 0) {
    throw 'Worker configuration must preserve existing replay queue pause state.'
  }
  $trace.Clear()
  & (Join-Path $serviceDirectory 'configure_cloud.ps1') -ProjectId test-project -ReplayStorageBucket test-bucket -ImageUri $image -SettlementDispatchUrl https://example.test/settle -SettlementDeliveryMode immediate
  if (@($trace | Where-Object { $_ -like 'run deploy *SETTLEMENT_DELIVERY_MODE=immediate*' }).Count -ne 1) {
    throw 'Explicit immediate-settlement rollback mode is missing.'
  }
  Write-Host 'Worker configuration checks passed with mocked cloud commands.'
} finally {
  $resolved = [IO.Path]::GetFullPath($fixture)
  if (-not $resolved.StartsWith($workspace + '\.tmp\worker-config-tests\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unsafe worker test cleanup path.'
  }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
