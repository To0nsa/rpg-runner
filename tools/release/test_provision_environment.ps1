[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_environments.ps1')
. (Join-Path $PSScriptRoot 'provision_environment.ps1')
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$global:foundationTest_trace = [Collections.Generic.List[string]]::new()
$global:foundationTest_existing = $false
$global:foundationTest_foreignBilling = $false
$global:foundationTest_foreignBudget = $false
$global:foundationTest_authExists = $false
$global:foundationTest_authInitializations = 0
$script:passed = 0
function gcloud {
  $global:LASTEXITCODE = 0
  $command = $args -join ' '
  $global:foundationTest_trace.Add($command)
  switch -Regex ($command) {
    '^auth print-access-token' { return 'mock-token-never-logged' }
    '^projects list' { return (@(@{projectId=$global:foundationTest_definition.projectId}) | ConvertTo-Json -Compress) }
    '^projects describe' { return (@{projectId=$global:foundationTest_definition.projectId;projectNumber='123456789012';lifecycleState='ACTIVE'} | ConvertTo-Json) }
    '^billing projects describe' { return (@{billingEnabled=$true;billingAccountName=$(if ($global:foundationTest_foreignBilling) {'billingAccounts/000000-000000-000000'} else {'billingAccounts/111111-222222-333333'})} | ConvertTo-Json) }
    '^billing budgets list' {
      if (-not $global:foundationTest_existing) { return '[]' }
      return (@(@{displayName="Lothringen Long Run - $global:foundationTest_environment";
        budgetFilter=@{projects=@($(if ($global:foundationTest_foreignBudget) {'projects/another-project'} else {"projects/$($global:foundationTest_definition.projectId)"}))};
        amount=@{specifiedAmount=@{currencyCode='EUR';units='25'}}}) | ConvertTo-Json -Depth 8)
    }
    '^firestore databases list' {
      if (-not $global:foundationTest_existing) { return '[]' }
      return (@(@{name="projects/$($global:foundationTest_definition.projectId)/databases/(default)";locationId=$global:foundationTest_definition.firestoreLocation;type='FIRESTORE_NATIVE'}) | ConvertTo-Json)
    }
    '^storage buckets list' {
      if (-not $global:foundationTest_existing) { return '[]' }
      return (@($global:foundationTest_definition.replayBucket,"$($global:foundationTest_definition.projectId)_cloudbuild") | ForEach-Object { @{name=$_;location='EUROPE-WEST1'} } | ConvertTo-Json)
    }
    '^artifacts repositories list' {
      if (-not $global:foundationTest_existing) { return '[]' }
      return (@(@{name="projects/$($global:foundationTest_definition.projectId)/locations/europe-west1/repositories/replay"}) | ConvertTo-Json)
    }
    '^iam service-accounts list' {
      if (-not $global:foundationTest_existing) { return '[]' }
      return (@('sa-run-control','sa-replay-validator','sa-replay-task-dispatch') | ForEach-Object { @{email="$_@$($global:foundationTest_definition.projectId).iam.gserviceaccount.com"} } | ConvertTo-Json)
    }
    '^tasks queues list' {
      if (-not $global:foundationTest_existing) { return '[]' }
      return (@('replay-validation','replay-projection') | ForEach-Object { @{name="projects/$($global:foundationTest_definition.projectId)/locations/europe-west1/queues/$_";state='RUNNING'} } | ConvertTo-Json)
    }
    '^builds get-default-service-account' { return 'projects/123456789012/serviceAccounts/123456789012-compute@developer.gserviceaccount.com' }
    default { return '{}' }
  }
}
function corepack {
  $global:LASTEXITCODE = 0
  return (@{status='success';result=@(@{projectId=$global:foundationTest_definition.projectId})} | ConvertTo-Json -Depth 5)
}
function Invoke-RestMethod {
  param($Uri,$Headers,$Method,$ContentType,$Body)
  if ($Uri -notlike "*/projects/$($global:foundationTest_definition.projectId)/*" -or
      $Headers['x-goog-user-project'] -ne $global:foundationTest_definition.projectId) { throw 'Foreign Auth request.' }
  if ($Method -eq 'Post') {
    if ($Uri -notlike '*:initializeAuth' -or $Body -ne '{}') { throw 'Unexpected Auth mutation.' }
    $global:foundationTest_authInitializations++
    $global:foundationTest_authExists = $true
  } elseif (-not $global:foundationTest_authExists) {
    $failure = [Management.Automation.ErrorRecord]::new([InvalidOperationException]::new('Auth missing'), 'MockAuthMissing', 'ObjectNotFound', $null)
    $failure.ErrorDetails = [Management.Automation.ErrorDetails]::new('{"error":{"message":"CONFIGURATION_NOT_FOUND"}}')
    throw $failure
  }
  return @{}
}
function Assert-Provision {
  param([bool]$Condition,[string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:passed++; Write-Host "PASS: $Message"
}
foreach ($global:foundationTest_environment in @('dev','staging','prod')) {
  $global:foundationTest_definition = Get-ReleaseEnvironmentDefinition $workspace $global:foundationTest_environment
  $global:foundationTest_existing=$false; $global:foundationTest_trace.Clear()
  $global:foundationTest_authExists=$false; $global:foundationTest_authInitializations=0
  Initialize-ReleaseEnvironment $workspace $global:foundationTest_environment '111111-222222-333333' '25EUR' | Out-Null
  Assert-Provision ($global:foundationTest_authInitializations -eq 1) 'missing Auth configuration is initialized once'
  Assert-Provision (@($global:foundationTest_trace | Where-Object { $_ -like 'tasks queues pause*' }).Count -eq 2) "$global:foundationTest_environment new queues start paused"
  Assert-Provision (@($global:foundationTest_trace | Where-Object { $_ -like 'services enable*' -and (@($_ -split ' ' | Where-Object { $_ -like '*.googleapis.com' }).Count -gt 20) }).Count -eq 0) 'API batches respect the service limit'
  Assert-Provision (@($global:foundationTest_trace | Where-Object { $_ -match 'roles/editor|roles/owner|allUsers|allAuthenticatedUsers' }).Count -eq 0) 'foundation grants no editor/owner/public roles'
  foreach ($other in @('dev','staging','prod') | Where-Object { $_ -ne $global:foundationTest_environment }) {
    $otherProject = (Get-ReleaseEnvironmentDefinition $workspace $other).projectId
    Assert-Provision (-not (($global:foundationTest_trace -join "`n").Contains($otherProject))) "$global:foundationTest_environment never addresses $other"
  }
  $global:foundationTest_existing=$true; $global:foundationTest_trace.Clear()
  Initialize-ReleaseEnvironment $workspace $global:foundationTest_environment '111111-222222-333333' '25EUR' | Out-Null
  Assert-Provision ($global:foundationTest_authInitializations -eq 1) 'retry preserves existing Auth configuration'
  Assert-Provision (@($global:foundationTest_trace | Where-Object { $_ -match ' create |tasks queues pause' }).Count -eq 0) 'retry preserves existing resources and live queue state'
  $global:foundationTest_foreignBilling=$true; $global:foundationTest_trace.Clear(); $rejected=$false
  try { Initialize-ReleaseEnvironment $workspace $global:foundationTest_environment '111111-222222-333333' '25EUR' | Out-Null } catch { $rejected=$_.Exception.Message -like '*different billing*' }
  Assert-Provision ($rejected -and @($global:foundationTest_trace | Where-Object { $_ -like 'services enable*' }).Count -eq 0) 'foreign billing fails before mutations'
  $global:foundationTest_foreignBilling=$false; $global:foundationTest_foreignBudget=$true; $rejected=$false
  try { Initialize-ReleaseEnvironment $workspace $global:foundationTest_environment '111111-222222-333333' '25EUR' | Out-Null } catch { $rejected=$_.Exception.Message -like '*budget is not scoped*' }
  Assert-Provision $rejected 'foreign budget cannot be reused'
  $global:foundationTest_foreignBudget=$false
}
Write-Host "$script:passed mocked provisioning checks passed; no cloud commands executed."
