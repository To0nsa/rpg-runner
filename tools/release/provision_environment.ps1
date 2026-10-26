# Foundation setup only. Image-dependent deployment belongs to Bootstrap/Deploy.
function Initialize-ReleaseEnvironment {
  param([string]$Root, [string]$Environment, [string]$BillingAccount, [string]$BudgetAmount)
  $Definition = Get-ReleaseEnvironmentDefinition $Root $Environment
  if ($BillingAccount -notmatch '^[A-F0-9]{6}-[A-F0-9]{6}-[A-F0-9]{6}$') {
    throw 'Provision requires the explicitly selected billing account ID.'
  }
  if ($BudgetAmount -notmatch '^[1-9][0-9]*(\.[0-9]{1,2})?[A-Z]{3}$') {
    throw 'Provision requires a positive monthly budget including currency, for example 25EUR.'
  }
  $project = $Definition.projectId
  $region = $Definition.region
  function Invoke-FoundationGcloud {
    param([string[]]$Arguments)
    Invoke-ReleaseCommand gcloud ($Arguments + @("--project=$project", '--quiet')) $Root
  }
  function Add-FoundationProjectRole {
    param([string]$Email, [string]$Role)
    Invoke-FoundationGcloud @('projects','add-iam-policy-binding',$project,
      "--member=serviceAccount:$Email", "--role=$Role", '--condition=None') | Out-Null
  }

  # Failure to list is fatal; never interpret unavailable access as absence.
  $projects = Invoke-FoundationGcloud @('projects','list','--format=json') | ConvertFrom-Json
  if (-not @($projects | Where-Object { $_.projectId -eq $project }).Count) {
    Invoke-FoundationGcloud @('projects','create',$project,"--name=$($Definition.displayName)",
      "--labels=application=lothringen-long-run,environment=$Environment") | Out-Null
  }
  $projectInfo = Invoke-FoundationGcloud @('projects','describe',$project,'--format=json') | ConvertFrom-Json
  if ($projectInfo.lifecycleState -ne 'ACTIVE') { throw 'Selected project is not active.' }
  $billing = Invoke-FoundationGcloud @('billing','projects','describe',$project,'--format=json') | ConvertFrom-Json
  if ($billing.billingEnabled -and $billing.billingAccountName -ne "billingAccounts/$BillingAccount") {
    throw 'Selected project is already linked to a different billing account.'
  }
  if (-not $billing.billingEnabled) {
    Invoke-FoundationGcloud @('billing','projects','link',$project,"--billing-account=$BillingAccount") | Out-Null
  }
  Write-Host "$project : billing verified; enabling required APIs."
  $apis = @('cloudfunctions','run','cloudbuild','artifactregistry','firestore',
    'identitytoolkit','cloudtasks','cloudscheduler','eventarc','pubsub','storage',
    'iam','iamcredentials','firebase','firebaseappcheck','firebaserules','secretmanager',
    'monitoring','logging','cloudbilling','billingbudgets') | ForEach-Object { "$_.googleapis.com" }
  for ($offset = 0; $offset -lt $apis.Count; $offset += 20) {
    $last = [Math]::Min($offset + 19, $apis.Count - 1)
    Invoke-FoundationGcloud (@('services','enable') + $apis[$offset..$last]) | Out-Null
  }
  $savedDebug = $env:DEBUG
  try {
    $env:DEBUG = ''
    $firebaseProjects = Invoke-ReleaseCommand corepack @('pnpm','exec','firebase','projects:list','--json') $Root | ConvertFrom-Json
    if ($firebaseProjects.status -ne 'success') { throw 'Firebase project inventory did not succeed.' }
    if (-not @($firebaseProjects.result | Where-Object { $_.projectId -eq $project }).Count) {
      Invoke-ReleaseCommand corepack @('pnpm','exec','firebase','projects:addfirebase',$project,'--json') $Root | Out-Null
    }
  } finally { $env:DEBUG = $savedDebug }

  # Firebase project creation does not initialize its Auth configuration.
  # Keep OAuth secrets and bearer credentials in memory, never in command logs.
  $accessToken = Invoke-ReleaseCommand gcloud @('auth','print-access-token') $Root
  $authHeaders = @{Authorization="Bearer $accessToken"; 'x-goog-user-project'=$project}
  try {
    $authExists = $true
    try {
      Invoke-RestMethod -Uri "https://identitytoolkit.googleapis.com/admin/v2/projects/$project/config" -Headers $authHeaders -Method Get | Out-Null
    } catch {
      if ($_.ErrorDetails.Message -match 'CONFIGURATION_NOT_FOUND') { $authExists = $false }
      else { throw 'Unable to inspect selected-project Auth configuration.' }
    }
    if (-not $authExists) {
      try {
        Invoke-RestMethod -Uri "https://identitytoolkit.googleapis.com/v2/projects/$project/identityPlatform:initializeAuth" -Headers $authHeaders -Method Post -ContentType 'application/json' -Body '{}' | Out-Null
        Invoke-RestMethod -Uri "https://identitytoolkit.googleapis.com/admin/v2/projects/$project/config" -Headers $authHeaders -Method Get | Out-Null
      } catch { throw 'Selected-project Auth initialization or readback failed.' }
    }
  } finally { $accessToken = $null; $authHeaders = $null }

  $budgets = Invoke-FoundationGcloud @('billing','budgets','list',"--billing-account=$BillingAccount",'--format=json') | ConvertFrom-Json
  $budgetName = "Lothringen Long Run - $Environment"
  $existingBudget = @($budgets | Where-Object { $_.displayName -eq $budgetName })
  if ($existingBudget.Count -gt 1) { throw 'Ambiguous existing environment budgets; inspect billing.' }
  if ($existingBudget.Count -eq 0) {
    Invoke-FoundationGcloud @('billing','budgets','create',"--billing-account=$BillingAccount",
      "--display-name=$budgetName", "--budget-amount=$BudgetAmount", "--filter-projects=projects/$project",
      '--calendar-period=month','--threshold-rule=percent=0.5','--threshold-rule=percent=0.9',
      '--threshold-rule=percent=1.0','--threshold-rule=percent=1.0,basis=forecasted-spend') | Out-Null
  } elseif (@($existingBudget[0].budgetFilter.projects).Count -ne 1 -or
      $existingBudget[0].budgetFilter.projects[0] -notin @("projects/$project", "projects/$($projectInfo.projectNumber)")) {
    throw 'Existing budget is not scoped solely to this project.'
  } else {
    $specified = $existingBudget[0].amount.specifiedAmount
    $actualAmount = [decimal]$specified.units
    if ($specified.PSObject.Properties.Name -contains 'nanos') { $actualAmount += [decimal]$specified.nanos / 1000000000 }
    $requestedAmount = [decimal]::Parse($BudgetAmount.Substring(0, $BudgetAmount.Length - 3), [Globalization.CultureInfo]::InvariantCulture)
    if ($specified.currencyCode -ne $BudgetAmount.Substring($BudgetAmount.Length - 3) -or $actualAmount -ne $requestedAmount) {
      throw 'Existing environment budget differs from the requested amount; review it before changing it.'
    }
  }

  Write-Host "$project : preparing database, buckets and build repository."
  $databaseInfo = Invoke-FoundationGcloud @('firestore','databases','list','--format=json') | ConvertFrom-Json
  $database = @($databaseInfo | Where-Object { $_.name -eq "projects/$project/databases/(default)" })
  if ($database.Count -eq 0) {
    Invoke-FoundationGcloud @('firestore','databases','create','--database=(default)',
      "--location=$($Definition.firestoreLocation)",'--type=firestore-native','--delete-protection') | Out-Null
  } elseif ($database[0].locationId -ne $Definition.firestoreLocation -or $database[0].type -ne 'FIRESTORE_NATIVE') {
    throw 'Existing Firestore location/type differs from the environment definition.'
  }
  $buckets = Invoke-FoundationGcloud @('storage','buckets','list','--format=json') | ConvertFrom-Json
  foreach ($bucket in @($Definition.replayBucket, "${project}_cloudbuild")) {
    $existingBucket = @($buckets | Where-Object { $_.name -eq $bucket })
    if ($existingBucket.Count -eq 0) {
      Invoke-FoundationGcloud @('storage','buckets','create',"gs://$bucket","--location=$region",
        '--uniform-bucket-level-access','--public-access-prevention','--soft-delete-duration=7d') | Out-Null
    } elseif ($existingBucket[0].location.ToLowerInvariant() -ne $region) {
      throw "Bucket $bucket is in a different location."
    }
  }
  $repositories = Invoke-FoundationGcloud @('artifacts','repositories','list',"--location=$region",'--format=json') | ConvertFrom-Json
  if (-not @($repositories | Where-Object { $_.name -eq "projects/$project/locations/$region/repositories/replay" }).Count) {
    Invoke-FoundationGcloud @('artifacts','repositories','create','replay',"--location=$region",'--repository-format=docker') | Out-Null
  }

  Write-Host "$project : configuring project-local identities and paused queues."
  $accounts = Invoke-FoundationGcloud @('iam','service-accounts','list','--format=json') | ConvertFrom-Json
  foreach ($account in @('sa-run-control','sa-replay-validator','sa-replay-task-dispatch')) {
    if (-not @($accounts | Where-Object { $_.email -eq "$account@$project.iam.gserviceaccount.com" }).Count) {
      Invoke-FoundationGcloud @('iam','service-accounts','create',$account,"--display-name=$account") | Out-Null
    }
  }
  $control = "sa-run-control@$project.iam.gserviceaccount.com"
  $worker = "sa-replay-validator@$project.iam.gserviceaccount.com"
  $dispatcher = "sa-replay-task-dispatch@$project.iam.gserviceaccount.com"
  foreach ($role in @('datastore.user','firebaseauth.admin','eventarc.eventReceiver','serviceusage.serviceUsageConsumer')) {
    Add-FoundationProjectRole $control "roles/$role"
  }
  Add-FoundationProjectRole $worker 'roles/datastore.user'
  Invoke-FoundationGcloud @('iam','service-accounts','add-iam-policy-binding',$control,
    "--member=serviceAccount:$control",'--role=roles/iam.serviceAccountTokenCreator','--condition=None') | Out-Null
  Invoke-FoundationGcloud @('iam','service-accounts','add-iam-policy-binding',$dispatcher,
    "--member=serviceAccount:$control",'--role=roles/iam.serviceAccountUser','--condition=None') | Out-Null
  $queues = Invoke-FoundationGcloud @('tasks','queues','list',"--location=$region",'--format=json') | ConvertFrom-Json
  foreach ($queue in @($Definition.validationQueue, $Definition.projectionQueue)) {
    if (-not @($queues | Where-Object { $_.name -eq "projects/$project/locations/$region/queues/$queue" }).Count) {
      Invoke-FoundationGcloud @('tasks','queues','create',$queue,"--location=$region",
        '--max-concurrent-dispatches=5','--max-dispatches-per-second=5') | Out-Null
      Invoke-FoundationGcloud @('tasks','queues','pause',$queue,"--location=$region") | Out-Null
    }
    Invoke-FoundationGcloud @('tasks','queues','add-iam-policy-binding',$queue,"--location=$region",
      "--member=serviceAccount:$control",'--role=roles/cloudtasks.enqueuer') | Out-Null
  }
  $builder = (Invoke-FoundationGcloud @('builds','get-default-service-account','--region=global')).Trim().Split('/')[-1]
  if ($builder -notmatch "^($($projectInfo.projectNumber)@cloudbuild.gserviceaccount.com|$($projectInfo.projectNumber)-compute@developer.gserviceaccount.com)$") {
    throw 'Default build account is not one of this project''s platform identities.'
  }
  Add-FoundationProjectRole $builder 'roles/cloudbuild.builds.builder'
  & (Join-Path $Root 'tools/cloud/apply_retention_policies.ps1') -ProjectId $project -Region $region
  if ($LASTEXITCODE -ne 0) { throw 'Foundation retention configuration failed.' }
  [pscustomobject]@{projectId=$project;projectNumber=$projectInfo.projectNumber;region=$region;
    firestoreLocation=$Definition.firestoreLocation;replayBucket=$Definition.replayBucket;
    budgetAmount=$BudgetAmount;budgetIsSpendingCap=$false;buildServiceAccount=$builder;
    completedAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json
}
