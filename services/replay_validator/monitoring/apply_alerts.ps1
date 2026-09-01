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
$dashboardPath = Join-Path $PSScriptRoot "dashboard.json"
$monitoringRoot = "https://monitoring.googleapis.com/v3/projects/$ProjectId"

function Invoke-Gcloud {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  & gcloud @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
}

function Get-AccessHeaders {
  $token = (& gcloud auth print-access-token).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw "Unable to obtain a Google Cloud access token."
  }
  return @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
  }
}

function Get-AllPagedResources {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$Property,
    [Parameter(Mandatory = $true)][hashtable]$Headers
  )

  $resources = @()
  $pageToken = ""
  do {
    $pageUri = $Uri
    if (-not [string]::IsNullOrWhiteSpace($pageToken)) {
      $separator = if ($pageUri.Contains("?")) { "&" } else { "?" }
      $pageUri += "$separator`pageToken=$([Uri]::EscapeDataString($pageToken))"
    }
    $response = Invoke-RestMethod -Method Get -Uri $pageUri -Headers $Headers
    if ($response.PSObject.Properties.Name -contains $Property) {
      $resources += @($response.$Property)
    }
    $pageToken = if (
      $response.PSObject.Properties.Name -contains "nextPageToken"
    ) {
      [string]$response.nextPageToken
    } else {
      ""
    }
  } while (-not [string]::IsNullOrWhiteSpace($pageToken))
  return $resources
}

function Get-OrCreateEmailChannel {
  param([Parameter(Mandatory = $true)][hashtable]$Headers)

  $channels = Get-AllPagedResources `
    -Uri "$monitoringRoot/notificationChannels?pageSize=1000" `
    -Property "notificationChannels" `
    -Headers $Headers
  $existing = @($channels | Where-Object {
    $_.type -eq "email" -and
    $_.labels.email_address -eq $NotificationEmail -and
    $_.enabled -ne $false
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
    -Uri "$monitoringRoot/notificationChannels" `
    -Headers $Headers `
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
    [Parameter(Mandatory = $true)][string]$NotificationChannel,
    [Parameter(Mandatory = $true)][hashtable]$Headers,
    [Parameter(Mandatory = $true)][object[]]$ExistingPolicies
  )

  $policy = Get-Content -Raw $TemplatePath | ConvertFrom-Json -AsHashtable
  $policy.notificationChannels = @($NotificationChannel)
  $existing = @($ExistingPolicies | Where-Object {
    $_.displayName -eq $policy.displayName
  } | Select-Object -First 1)
  if ($existing.Count -eq 0) {
    $body = $policy | ConvertTo-Json -Depth 20 -Compress
    $null = Invoke-RestMethod `
      -Method Post `
      -Uri "$monitoringRoot/alertPolicies" `
      -Headers $Headers `
      -Body $body
    return "created"
  }

  $policy.name = $existing[0].name
  $body = $policy | ConvertTo-Json -Depth 20 -Compress
  $null = Invoke-RestMethod `
    -Method Patch `
    -Uri "https://monitoring.googleapis.com/v3/$($existing[0].name)" `
    -Headers $Headers `
    -Body $body
  return "updated"
}

function Ensure-Dashboard {
  param([Parameter(Mandatory = $true)][string]$ConfigPath)

  $dashboardJson = (Get-Content -Raw $ConfigPath).Replace(
    "projects/rpg-runner-d7add",
    "projects/$ProjectId"
  )
  $dashboard = $dashboardJson | ConvertFrom-Json -AsHashtable
  $dashboardsJson = @(& gcloud monitoring dashboards list `
    "--project=$ProjectId" "--format=json")
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to list existing dashboards."
  }
  $existingDashboards = @(($dashboardsJson -join [Environment]::NewLine) |
    ConvertFrom-Json)
  $existing = @($existingDashboards | Where-Object {
    $_.displayName -eq $dashboard.displayName
  } | Select-Object -First 1)

  $temporaryPath = New-TemporaryFile
  try {
    if ($existing.Count -gt 0) {
      $currentJson = @(& gcloud monitoring dashboards describe $existing[0].name `
        "--project=$ProjectId" "--format=json")
      if ($LASTEXITCODE -ne 0) {
        throw "Unable to load existing dashboard $($existing[0].name)."
      }
      $current = ($currentJson -join [Environment]::NewLine) |
        ConvertFrom-Json -AsHashtable
      $dashboard.etag = $current.etag
      $dashboard | ConvertTo-Json -Depth 30 | Set-Content -NoNewline $temporaryPath
      Invoke-Gcloud @(
        "monitoring", "dashboards", "update", $existing[0].name,
        "--project=$ProjectId",
        "--config-from-file=$temporaryPath"
      )
      return
    }

    $dashboard | ConvertTo-Json -Depth 30 | Set-Content -NoNewline $temporaryPath
    Invoke-Gcloud @(
      "monitoring", "dashboards", "create",
      "--project=$ProjectId",
      "--config-from-file=$temporaryPath"
    )
  } finally {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
  }
}

Get-ChildItem -Path $metricRoot -Filter "*.yaml" | Sort-Object Name |
  ForEach-Object {
    Ensure-LogMetric -Name $_.BaseName -ConfigPath $_.FullName
  }

$headers = Get-AccessHeaders
$channel = Get-OrCreateEmailChannel -Headers $headers
$existingPolicies = @(
  Get-AllPagedResources `
    -Uri "$monitoringRoot/alertPolicies?pageSize=1000" `
    -Property "alertPolicies" `
    -Headers $headers
)
$results = @()
Get-ChildItem -Path $policyRoot -Filter "*.json" | Sort-Object Name |
  ForEach-Object {
    $outcome = Ensure-AlertPolicy `
      -TemplatePath $_.FullName `
      -NotificationChannel $channel `
      -Headers $headers `
      -ExistingPolicies $existingPolicies
    $results += "$outcome`: $($_.Name)"
  }
Ensure-Dashboard -ConfigPath $dashboardPath

Write-Output "Applied replay-validator monitoring to $ProjectId."
Write-Output "Notification channel: $channel"
$results | ForEach-Object { Write-Output $_ }
