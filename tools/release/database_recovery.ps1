# Managed retention only. Restoring live player state requires a separate
# issuance/drain and deletion/reward reconciliation review, never an automatic reset.
function Set-ReleaseDatabaseRecovery {
  param([string]$Root, [object]$Definition, [string]$Environment)
  if ($Environment -notin @('staging','prod')) { throw 'Managed beta recovery setup is limited to staging/prod; dev rehearsals use isolated synthetic databases.' }
  $project = $Definition.projectId
  function Invoke-RecoveryCloud {
    param([string[]]$Arguments)
    Invoke-ReleaseCommand gcloud ($Arguments + @("--project=$project",'--quiet','--format=json')) $Root
  }
  $database = Invoke-RecoveryCloud @('firestore','databases','describe','--database=(default)') | ConvertFrom-Json
  if ($database.name -ne "projects/$project/databases/(default)" -or $database.locationId -ne $Definition.firestoreLocation) {
    throw 'Recovery database identity/location mismatch.'
  }
  Invoke-RecoveryCloud @('firestore','databases','update','--database=(default)',
    '--enable-pitr','--delete-protection') | Out-Null
  $schedules = @(Invoke-RecoveryCloud @('firestore','backups','schedules','list','--database=(default)') | ConvertFrom-Json)
  $daily = @($schedules | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'dailyRecurrence' })
  if ($daily.Count -gt 1) { throw 'Multiple daily recovery schedules found; inspect before changing retention.' }
  if ($daily.Count -eq 0) {
    Invoke-RecoveryCloud @('firestore','backups','schedules','create','--database=(default)',
      '--recurrence=daily','--retention=7d') | Out-Null
  } elseif ($daily[0].retention -ne '604800s') {
    throw 'Existing daily backup retention differs from seven days; inspect before changing it.'
  }
  $verified = Invoke-RecoveryCloud @('firestore','databases','describe','--database=(default)') | ConvertFrom-Json
  $schedules = @(Invoke-RecoveryCloud @('firestore','backups','schedules','list','--database=(default)') | ConvertFrom-Json)
  $daily = @($schedules | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'dailyRecurrence' -and $_.retention -eq '604800s' })
  if ($verified.pointInTimeRecoveryEnablement -ne 'POINT_IN_TIME_RECOVERY_ENABLED' -or
      $verified.deleteProtectionState -ne 'DELETE_PROTECTION_ENABLED' -or $daily.Count -ne 1) {
    throw 'Managed recovery settings did not pass live readback.'
  }
  [ordered]@{environment=$Environment;projectId=$project;database=$verified.name;
    pointInTimeRecovery=$verified.pointInTimeRecoveryEnablement;earliestVersionTime=$verified.earliestVersionTime;
    backupSchedule=$daily[0].name;retention=$daily[0].retention;verifiedAt=[DateTime]::UtcNow.ToString('o');
    limitation='Configuration readback only; scheduled backup completion and restore acceptance are separate evidence.'} | ConvertTo-Json
}
