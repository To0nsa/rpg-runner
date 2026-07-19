[CmdletBinding()]
param(
  [string]$ProjectId = "rpg-runner-d7add",

  [Parameter(Mandatory = $true)]
  [string]$NotificationEmail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$metricRoot = Join-Path $PSScriptRoot "metrics"
$policyRoot = Join-Path $PSScriptRoot "policies"

function Invoke-Gcloud {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  & gcloud @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
}

function Get-OrCreateEmailChannel {
  $token = (& gcloud auth print-access-token).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw "Unable to obtain a Google Cloud access token."
  }
  $headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
  }
  $channels = Invoke-RestMethod `
    -Method Get `
    -Uri "https://monitoring.googleapis.com/v3/projects/$ProjectId/notificationChannels" `
    -Headers $headers
  $existing = @($channels.notificationChannels | Where-Object {
    $_.type -eq "email" -and $_.labels.email_address -eq $NotificationEmail
  } | Select-Object -First 1)
  if ($existing.Count -gt 0) {
    return $existing[0].name
  }
  $body = @{
    type = "email"
    displayName = "RPG Runner production alerts"
    labels = @{ email_address = $NotificationEmail }
    enabled = $true
  } | ConvertTo-Json -Compress
  $created = Invoke-RestMethod `
    -Method Post `
    -Uri "https://monitoring.googleapis.com/v3/projects/$ProjectId/notificationChannels" `
    -Headers $headers `
    -Body $body
  return $created.name
}

function Ensure-LogMetric {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$ConfigPath
  )

  & gcloud logging metrics describe $Name "--project=$ProjectId" *> $null
  if ($LASTEXITCODE -eq 0) {
    Invoke-Gcloud @(
      "logging", "metrics", "update", $Name,
      "--project=$ProjectId",
      "--config-from-file=$ConfigPath"
    )
    return
  }
  Invoke-Gcloud @(
    "logging", "metrics", "create", $Name,
    "--project=$ProjectId",
    "--config-from-file=$ConfigPath"
  )
}

function Ensure-AlertPolicy {
  param(
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)][string]$NotificationChannel
  )

  $policy = Get-Content -Raw $TemplatePath | ConvertFrom-Json -AsHashtable
  $policy.notificationChannels = @($NotificationChannel)
  $temporaryPath = New-TemporaryFile
  try {
    $policy | ConvertTo-Json -Depth 20 | Set-Content -NoNewline $temporaryPath
    $policiesJson = @(& gcloud monitoring policies list `
      "--project=$ProjectId" "--format=json")
    if ($LASTEXITCODE -ne 0) {
      throw "Unable to list existing alert policies."
    }
    $existingPolicies = @(($policiesJson -join [Environment]::NewLine) |
      ConvertFrom-Json)
    $existing = @($existingPolicies | Where-Object {
      $_.displayName -eq $policy.displayName
    } | Select-Object -First 1)
    if ($existing.Count -gt 0) {
      Invoke-Gcloud @(
        "monitoring", "policies", "update", $existing[0].name,
        "--project=$ProjectId",
        "--policy-from-file=$temporaryPath"
      )
      return
    }
    Invoke-Gcloud @(
      "monitoring", "policies", "create",
      "--project=$ProjectId",
      "--policy-from-file=$temporaryPath"
    )
  } finally {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
  }
}

Ensure-LogMetric `
  -Name "reward_settlement_immediate_dispatch_attempts" `
  -ConfigPath (Join-Path $metricRoot "immediate_dispatch_attempts.yaml")
Ensure-LogMetric `
  -Name "reward_settlement_immediate_dispatch_fallbacks" `
  -ConfigPath (Join-Path $metricRoot "immediate_dispatch_fallbacks.yaml")
Ensure-LogMetric `
  -Name "reward_settlement_finalize_to_handoff_latency_ms" `
  -ConfigPath (Join-Path $metricRoot "finalize_to_handoff_latency_ms.yaml")

$channel = Get-OrCreateEmailChannel
Get-ChildItem -Path $policyRoot -Filter "*.json" | Sort-Object Name |
  ForEach-Object {
    Ensure-AlertPolicy -TemplatePath $_.FullName -NotificationChannel $channel
  }

Write-Output "Applied reward-settlement monitoring to $ProjectId."
Write-Output "Email channel: $channel"
Write-Output "Confirm the Google Cloud verification email sent to $NotificationEmail before relying on notifications."
