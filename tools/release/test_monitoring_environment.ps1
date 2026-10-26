. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'monitoring_environment.ps1')
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture=Join-Path $workspace ".tmp/release-tests/monitoring-$([guid]::NewGuid().ToString('N'))"
$definition=[pscustomobject]@{projectId='test-staging'}
$script:passed=0
$script:commands=[Collections.Generic.List[string]]::new()
$script:status='VERIFIED'
$script:channel='projects/test-staging/notificationChannels/test-channel'
$script:policies=@()
function Assert-MonitoringTest {
  param([bool]$Condition,[string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:passed++; Write-Host "PASS: $Message"
}
function Invoke-ReleaseCommand {
  param($Command,$CommandArgs,$WorkingDirectory,$LogPath='')
  if ($Command -eq 'gcloud') { return 'mock-token' }
  if ($Command -ne 'pwsh' -or $CommandArgs[3] -ne '-ProjectId' -or $CommandArgs[4] -ne 'test-staging') { throw 'Wrong helper project' }
  $script:commands.Add($CommandArgs -join ' ')
}
function Invoke-RestMethod {
  param($Method,$Uri,$Headers)
  if ($Uri -notlike 'https://monitoring.googleapis.com/v3/projects/test-staging/*') { throw 'Wrong readback project' }
  if ($Uri -match '/notificationChannels') {
    $channel=[pscustomobject]@{type='email';labels=@{email_address='owner@example.com'};
      enabled=$true;verificationStatus=$script:status;name=$script:channel}
    if ($null -eq $script:status) { $channel.PSObject.Properties.Remove('verificationStatus') }
    return [pscustomobject]@{notificationChannels=@($channel)}
  }
  return [pscustomobject]@{alertPolicies=$script:policies}
}
try {
  foreach ($bundle in @('services/replay_validator/monitoring','functions/monitoring/reward_settlement','functions/monitoring/abuse_controls','functions/monitoring/account_deletion')) {
    $destination=Join-Path $fixture "$bundle/policies"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $workspace "$bundle/policies") -Filter '*.json' | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $destination
      $script:policies += [pscustomobject]@{displayName=(Get-Content $_.FullName -Raw | ConvertFrom-Json).displayName;enabled=$true;notificationChannels=@($script:channel)}
    }
  }
  $failed=$false
  try { Set-ReleaseMonitoring $fixture $definition '' | Out-Null } catch { $failed=$true }
  Assert-MonitoringTest ($failed -and $script:commands.Count -eq 0) 'missing owner email blocks before helpers'
  $script:status='UNVERIFIED'
  $failed=$false
  try { Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | Out-Null } catch { $failed=$_.Exception.Message -like '*Confirm the selected project*' }
  Assert-MonitoringTest ($failed -and $script:commands.Count -eq 2) 'unverified delivery stops before guarded bundles'
  $script:status='VERIFIED'
  $script:channel='projects/test-production/notificationChannels/foreign'
  $failed=$false
  try { Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | Out-Null } catch { $failed=$_.Exception.Message -like '*different project*' }
  Assert-MonitoringTest $failed 'foreign notification identity is rejected'
  $script:channel='projects/test-staging/notificationChannels/test-channel'
  $script:commands.Clear()
  $result=Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | ConvertFrom-Json
  Assert-MonitoringTest ($script:commands.Count -eq 4 -and $result.policyCount -eq 31 -and $result.verificationStatus -eq 'VERIFIED') 'all existing bundles and enabled policies are verified in the selected project'
  $script:status='VERIFICATION_STATUS_UNSPECIFIED'
  $result=Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | ConvertFrom-Json
  Assert-MonitoringTest ($result.verificationStatus -eq 'VERIFICATION_STATUS_UNSPECIFIED') 'API-exempt verification state is preserved without claiming verified delivery'
  $script:status=$null
  $result=Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | ConvertFrom-Json
  Assert-MonitoringTest ($result.verificationStatus -eq 'VERIFICATION_STATUS_UNSPECIFIED') 'omitted API status does not invent an email-verification requirement'
  $script:policies[0].enabled=$false
  $failed=$false
  try { Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | Out-Null } catch { $failed=$_.Exception.Message -like '*Missing or ambiguous*' }
  Assert-MonitoringTest $failed 'disabled policy cannot establish monitoring readiness'
  $script:policies[0].enabled=$true
  $script:policies += $script:policies[0]
  $failed=$false
  try { Set-ReleaseMonitoring $fixture $definition 'owner@example.com' | Out-Null } catch { $failed=$_.Exception.Message -like '*Missing or ambiguous*' }
  Assert-MonitoringTest $failed 'duplicate policy identity cannot establish readiness'
  Write-Host "$script:passed monitoring checks passed; no cloud commands executed."
} finally {
  $allowed=[IO.Path]::GetFullPath((Join-Path $workspace '.tmp/release-tests')).TrimEnd('\')+'\'
  $resolved=[IO.Path]::GetFullPath($fixture)
  if (-not $resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
