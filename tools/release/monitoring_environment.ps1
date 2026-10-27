function Set-ReleaseMonitoring {
  param([string]$Root, [object]$Definition, [string]$NotificationEmail)
  if (-not $NotificationEmail -or $NotificationEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
    throw 'MonitoringSetup requires an explicit -NotificationEmail.'
  }
  $project = $Definition.projectId
  $directory = Join-Path $Root ".tmp/releases/$project/monitoring"
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $bundles = @('services/replay_validator/monitoring', 'functions/monitoring/reward_settlement',
    'functions/monitoring/abuse_controls', 'functions/monitoring/account_deletion')
  foreach ($bundle in $bundles[0..1]) {
    Invoke-ReleaseCommand pwsh @('-NoProfile', '-File', (Join-Path $Root "$bundle/apply_alerts.ps1"),
      '-ProjectId', $project, '-NotificationEmail', $NotificationEmail) $Root (Join-Path $directory 'apply.log') | Out-Null
  }
  $token = $null
  try {
    $token = (Invoke-ReleaseCommand gcloud @('auth', 'print-access-token') $Root).Trim()
    $headers = @{Authorization="Bearer $token"}
    $response = Invoke-RestMethod -Method Get -Uri "https://monitoring.googleapis.com/v3/projects/$project/notificationChannels?pageSize=1000" -Headers $headers
    $channels = @($response.notificationChannels | Where-Object {
      $_.type -eq 'email' -and $_.labels.email_address -eq $NotificationEmail -and $_.enabled -and
      (-not $_.PSObject.Properties['verificationStatus'] -or $_.verificationStatus -in @('VERIFIED','VERIFICATION_STATUS_UNSPECIFIED'))
    })
    if ($channels.Count -ne 1) { throw 'Confirm the selected project notification channel, then retry MonitoringSetup.' }
    # The API treats omitted/unspecified status as usable (verification is not
    # required). Never label it VERIFIED or attempt to copy verification codes.
    # https://docs.cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.notificationChannels
    $verification = if ($channels[0].PSObject.Properties['verificationStatus']) {
      [string]$channels[0].verificationStatus
    } else { 'VERIFICATION_STATUS_UNSPECIFIED' }
    $channel = $channels[0].name
    if (-not $channel.StartsWith("projects/$project/notificationChannels/", [StringComparison]::Ordinal)) {
      throw 'Notification channel belongs to a different project.'
    }
    foreach ($bundle in $bundles[2..3]) {
      Invoke-ReleaseCommand pwsh @('-NoProfile', '-File', (Join-Path $Root "$bundle/apply_alerts.ps1"),
        '-ProjectId', $project, '-NotificationChannel', $channel) $Root (Join-Path $directory 'apply.log') | Out-Null
    }
    $response = Invoke-RestMethod -Method Get -Uri "https://monitoring.googleapis.com/v3/projects/$project/alertPolicies?pageSize=1000" -Headers $headers
    $expected = @($bundles | ForEach-Object {
      Get-ChildItem -LiteralPath (Join-Path $Root "$_/policies") -Filter '*.json' | ForEach-Object {
        (Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json).displayName
      }
    })
    foreach ($name in $expected) {
      $matches = @($response.alertPolicies | Where-Object { $_.displayName -eq $name -and $_.enabled -and $_.notificationChannels -contains $channel })
      if ($matches.Count -ne 1) { throw "Missing or ambiguous enabled monitoring policy: $name" }
    }
    $evidence = [ordered]@{projectId=$project;checkedAt=[DateTime]::UtcNow.ToString('o');notificationChannel=$channel;
      notificationEmail=$NotificationEmail;verificationStatus=$verification;policyCount=$expected.Count;
      policies=$expected;limitation='Configuration readback; incident delivery and deployed service health remain separate checks.'}
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'monitoring.json') -Encoding utf8
    $evidence | ConvertTo-Json -Depth 6
  } finally { $token=$null; $headers=$null }
}
