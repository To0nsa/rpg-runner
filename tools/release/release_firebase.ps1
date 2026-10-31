Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReleaseInitialEventRetryTargets {
  param([object[]]$Functions, [string]$ProjectId, [string]$Region)
  $prefix = "projects/$ProjectId/locations/$Region/functions/"
  foreach ($name in @('runSettlementOnHandoff', 'runProjectionOnAccepted', 'accountDeletionOnRequest')) {
    $existing = @($Functions | Where-Object { $_.name -clike "*/functions/$name" })
    if ($existing.Count -eq 0) {
      "functions:$name"
      continue
    }
    if ($existing.Count -ne 1 -or $existing[0].name -cne "$prefix$name" -or $existing[0].state -ne 'ACTIVE' -or
        -not $existing[0].PSObject.Properties['eventTrigger'] -or
        -not $existing[0].eventTrigger.PSObject.Properties['retryPolicy'] -or
        $existing[0].eventTrigger.retryPolicy -ne 'RETRY_POLICY_RETRY') {
      throw "Existing event handler $name is not active with retries; inspect it before retrying."
    }
  }
}
