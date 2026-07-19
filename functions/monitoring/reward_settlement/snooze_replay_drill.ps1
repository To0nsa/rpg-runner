[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$ProjectId = "rpg-runner-d7add",

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Reason,

  [ValidateRange(1, 60)]
  [int]$DurationMinutes = 30,

  [datetime]$StartUtc = (Get-Date).ToUniversalTime(),

  [string[]]$PolicyDisplayName = @(
    "RPG Runner - payout latency p99 above 15 seconds",
    "RPG Runner - replay validator HTTP 5xx",
    "RPG Runner - replay validation retry activity"
  )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Gcloud {
  param([Parameter(Mandatory = $true)][string[]]$CommandArgs)

  & gcloud @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "gcloud command failed: gcloud $($CommandArgs -join ' ')"
  }
}

$start = $StartUtc.ToUniversalTime()
$end = $start.AddMinutes($DurationMinutes)
if ($end -le $start) {
  throw "The snooze end time must be after its start time."
}

$policiesJson = @(& gcloud monitoring policies list `
  "--project=$ProjectId" "--format=json")
if ($LASTEXITCODE -ne 0) {
  throw "Unable to list alert policies for $ProjectId."
}
$policies = @(($policiesJson -join [Environment]::NewLine) | ConvertFrom-Json)
$policyNames = foreach ($displayName in $PolicyDisplayName) {
  $matches = @($policies | Where-Object { $_.displayName -eq $displayName })
  if ($matches.Count -ne 1) {
    throw "Expected exactly one alert policy named '$displayName'; found $($matches.Count)."
  }
  $matches[0].name
}

$displayName = "RPG Runner replay drill: $Reason"
$startText = $start.ToString("o")
$endText = $end.ToString("o")
$policyArgument = $policyNames -join ","

if ($PSCmdlet.ShouldProcess(
  $ProjectId,
  "Create replay-drill snooze '$displayName' from $startText through $endText"
)) {
  Invoke-Gcloud @(
    "monitoring", "snoozes", "create",
    "--project=$ProjectId",
    "--display-name=$displayName",
    "--criteria-policies=$policyArgument",
    "--start-time=$startText",
    "--end-time=$endText"
  )
}

Write-Output "Replay-drill snooze covers $($policyNames.Count) policies from $startText through $endText."
