. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_environments.ps1')
. (Join-Path $PSScriptRoot 'database_recovery.ps1')
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:passed = 0
$script:calls = [Collections.Generic.List[string]]::new()
$script:recoveryProject = ''; $script:scheduleExists = $false; $script:foreignDatabase = $false
$script:pitrEnabled = $false; $script:wrongRetention = $false
function gcloud {
  $global:LASTEXITCODE = 0
  $command = $args -join ' '; $script:calls.Add($command)
  if ($command -like 'firestore databases describe*') {
    return @{name="projects/$(if($script:foreignDatabase){'foreign-project'}else{$script:recoveryProject})/databases/(default)";
      locationId='europe-west1';pointInTimeRecoveryEnablement=$(if($script:pitrEnabled){'POINT_IN_TIME_RECOVERY_ENABLED'}else{'POINT_IN_TIME_RECOVERY_DISABLED'});
      deleteProtectionState='DELETE_PROTECTION_ENABLED';earliestVersionTime='2026-10-27T00:00:00Z'} | ConvertTo-Json
  }
  if ($command -like 'firestore databases update*') { $script:pitrEnabled=$true; return '{}' }
  if ($command -like 'firestore backups schedules create*') { $script:scheduleExists=$true; return '{}' }
  if ($command -like 'firestore backups schedules list*') {
    if (-not $script:scheduleExists) { return '[]' }
    return @(@{name="projects/$script:recoveryProject/databases/(default)/backupSchedules/fixture";
      dailyRecurrence=@{};retention=$(if($script:wrongRetention){'86400s'}else{'604800s'})}) | ConvertTo-Json -Depth 5
  }
  throw 'Unexpected mock recovery command.'
}
function Assert-RecoveryTest {
  param([bool]$Condition,[string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:passed++; Write-Host "PASS: $Message"
}
foreach ($environment in @('staging','prod')) {
  $definition=Get-ReleaseEnvironmentDefinition $workspace $environment
  $script:recoveryProject=$definition.projectId; $script:calls.Clear(); $script:scheduleExists=$false; $script:pitrEnabled=$false
  $result=Set-ReleaseDatabaseRecovery $workspace $definition $environment | ConvertFrom-Json
  Assert-RecoveryTest ($result.projectId -eq $definition.projectId -and $result.retention -eq '604800s') "$environment records verified managed recovery"
  Assert-RecoveryTest (@($script:calls | Where-Object { $_ -notlike "*--project=$($definition.projectId)*" }).Count -eq 0) "$environment commands cannot address another project"
  $script:calls.Clear()
  Set-ReleaseDatabaseRecovery $workspace $definition $environment | Out-Null
  Assert-RecoveryTest (@($script:calls | Where-Object { $_ -like '* schedules create*' }).Count -eq 0) 'retry preserves daily schedule'
}
$script:foreignDatabase=$true; $script:calls.Clear(); $caught=$false
try { Set-ReleaseDatabaseRecovery $workspace $definition prod } catch { $caught=$_.Exception.Message -like '*identity/location mismatch*' }
Assert-RecoveryTest ($caught -and $script:calls.Count -eq 1) 'foreign database fails before mutation'
$script:foreignDatabase=$false; $script:wrongRetention=$true; $caught=$false
try { Set-ReleaseDatabaseRecovery $workspace $definition prod } catch { $caught=$_.Exception.Message -like '*retention differs*' }
Assert-RecoveryTest $caught 'existing retention is never silently replaced'
$script:calls.Clear(); $caught=$false
try { Set-ReleaseDatabaseRecovery $workspace (Get-ReleaseEnvironmentDefinition $workspace dev) dev } catch { $caught=$true }
Assert-RecoveryTest ($caught -and $script:calls.Count -eq 0) 'default dev database is outside managed beta setup'
Write-Host "$script:passed mocked database recovery checks passed."
