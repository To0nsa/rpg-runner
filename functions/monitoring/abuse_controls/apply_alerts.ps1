[CmdletBinding()]
param(
  [string]$ProjectId = "rpg-runner-d7add",

  [Parameter(Mandatory = $true)]
  [string]$NotificationChannel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$metricRoot = Join-Path $PSScriptRoot "metrics"
$policyRoot = Join-Path $PSScriptRoot "policies"
$expectedChannelPrefix = "projects/$ProjectId/notificationChannels/"
if (-not $NotificationChannel.StartsWith(
    $expectedChannelPrefix,
    [System.StringComparison]::Ordinal
  )) {
  throw "NotificationChannel must belong to project $ProjectId."
}

function Invoke-Gcloud {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  & gcloud @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
}

function Get-MonitoringHeaders {
  $token = (& gcloud auth print-access-token).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw "Unable to obtain a Google Cloud access token."
  }
  return @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
  }
}

function Assert-NotificationChannelReady {
  param([Parameter(Mandatory = $true)][hashtable]$Headers)

  $channel = Invoke-RestMethod `
    -Method Get `
    -Uri "https://monitoring.googleapis.com/v3/$NotificationChannel" `
    -Headers $Headers
  if ($channel.enabled -ne $true) {
    throw "Notification channel $NotificationChannel is disabled."
  }
  if (
    $channel.PSObject.Properties.Name -contains "verificationStatus" -and
    $channel.verificationStatus -ne "VERIFIED"
  ) {
    throw "Notification channel $NotificationChannel is not verified."
  }
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
    [Parameter(Mandatory = $true)][string]$Channel
  )

  $policy = Get-Content -Raw $TemplatePath | ConvertFrom-Json -AsHashtable
  $policy.notificationChannels = @($Channel)
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
      return $existing[0].name
    }
    $createdJson = @(& gcloud monitoring policies create `
      "--project=$ProjectId" `
      "--policy-from-file=$temporaryPath" `
      "--format=json")
    if ($LASTEXITCODE -ne 0) {
      throw "Unable to create alert policy $($policy.displayName)."
    }
    return (($createdJson -join [Environment]::NewLine) |
      ConvertFrom-Json).name
  } finally {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
  }
}

$headers = Get-MonitoringHeaders
Assert-NotificationChannelReady -Headers $headers

Get-ChildItem -Path $metricRoot -Filter "*.yaml" | Sort-Object Name |
  ForEach-Object {
    Ensure-LogMetric `
      -Name $_.BaseName `
      -ConfigPath $_.FullName
  }

$applied = @()
Get-ChildItem -Path $policyRoot -Filter "*.json" | Sort-Object Name |
  ForEach-Object {
    $applied += Ensure-AlertPolicy `
      -TemplatePath $_.FullName `
      -Channel $NotificationChannel
  }

Write-Output "Applied callable abuse/resource monitoring to $ProjectId."
Write-Output "Notification channel: $NotificationChannel"
$applied | ForEach-Object { Write-Output "Policy: $_" }
