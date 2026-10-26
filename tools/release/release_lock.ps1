# A generation-conditional object serializes operators across machines/checkouts.
# There is no lease expiry: a slow or disconnected deployment must not lose its
# lock while it can still mutate the environment. Abandoned locks need inspection.
function Invoke-ReleaseLockRequest {
  param([string]$Root, [string]$Method, [string]$Uri, [string]$Body = '', [switch]$AllowNotFound)
  $token = $null
  try {
    $token = (Invoke-ReleaseCommand gcloud @('auth', 'print-access-token') $Root).Trim()
    if (-not $token) { throw 'No authenticated operator.' }
    $arguments = @{ Method=$Method; Uri=$Uri; Headers=@{Authorization="Bearer $token"};
      ErrorAction='Stop'; Verbose=$false; Debug=$false }
    if ($Body) { $arguments.Body = [Text.Encoding]::UTF8.GetBytes($Body); $arguments.ContentType='application/json' }
    return Invoke-RestMethod @arguments
  } catch {
    # Avoid including SDK/HTTP error bodies or authorization headers in logs.
    $status = 0
    if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
    }
    if ($status -eq 412) { throw 'Release lock precondition failed: another operator owns this environment, or its lock generation changed.' }
    if ($status -eq 404 -and $AllowNotFound) { return $null }
    throw "Release lock request failed (HTTP $status). Inspect access and the selected project's lock before retrying."
  } finally { $token = $null }
}

# The action mutex alone cannot prevent candidate B from interleaving between
# candidate A's pause and deploy commands. Keep a source-bound record throughout
# maintenance; another operator may resume the same candidate, never replace it.
function Assert-ReleaseCutoverOwner {
  param([string]$Root, [object]$Definition, [string]$SourceDigest, [switch]$Claim)
  if ($SourceDigest -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid cutover source digest.' }
  $project = $Definition.projectId
  $bucket = "${project}_cloudbuild"
  $name = '_release/cutover.json'
  $encoded = [Uri]::EscapeDataString($name)
  $uri = "https://storage.googleapis.com/storage/v1/b/$bucket/o/$encoded"
  $metadata = Invoke-ReleaseLockRequest $Root 'Get' $uri -AllowNotFound
  if (-not $metadata) {
    if (-not $Claim) { throw 'No candidate owns this cutover. Run PauseIssuance or Bootstrap for the prepared source.' }
    $body = [ordered]@{schemaVersion=1;projectId=$project;sourceDigest=$SourceDigest;startedAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Compress
    $metadata = Invoke-ReleaseLockRequest $Root 'Post' "https://storage.googleapis.com/upload/storage/v1/b/$bucket/o?uploadType=media&name=$encoded&ifGenerationMatch=0" $body
  }
  if ($metadata.bucket -ne $bucket -or $metadata.name -ne $name -or $metadata.generation -notmatch '^[1-9][0-9]*$') {
    throw 'Unverified cutover ownership record.'
  }
  $record = Invoke-ReleaseLockRequest $Root 'Get' "${uri}?alt=media&ifGenerationMatch=$($metadata.generation)"
  if ($record.schemaVersion -ne 1 -or $record.projectId -ne $project -or $record.sourceDigest -ne $SourceDigest) {
    throw 'Another candidate owns this environment cutover. Resume it or inspect an explicit recovery before changing candidates.'
  }
  return [pscustomobject]@{projectId=$project;generation=[string]$metadata.generation;sourceDigest=$SourceDigest}
}

function Complete-ReleaseCutover {
  param([string]$Root, [object]$Definition, [object]$Cutover)
  $current = Assert-ReleaseCutoverOwner $Root $Definition $Cutover.sourceDigest
  if ($current.projectId -ne $Cutover.projectId -or $current.generation -ne $Cutover.generation) {
    throw 'Cutover ownership changed; refusing cleanup.'
  }
  $bucket = "$($Definition.projectId)_cloudbuild"
  $encoded = [Uri]::EscapeDataString('_release/cutover.json')
  Invoke-ReleaseLockRequest $Root 'Delete' "https://storage.googleapis.com/storage/v1/b/$bucket/o/${encoded}?ifGenerationMatch=$($current.generation)" | Out-Null
}

function Enter-ReleaseMutationLock {
  param([string]$Root, [object]$Definition, [string]$Action)
  $project = $Definition.projectId
  if ($project -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$') { throw 'Invalid release lock project.' }
  $bucket = "${project}_cloudbuild"
  $name = '_release/mutation-lock.json'
  $owner = [Guid]::NewGuid().ToString('N')
  $body = [ordered]@{schemaVersion=1;projectId=$project;action=$Action;owner=$owner;
    machine=[Environment]::MachineName;processId=$PID;acquiredAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Compress
  $encodedName = [Uri]::EscapeDataString($name)
  $uri = "https://storage.googleapis.com/upload/storage/v1/b/$bucket/o?uploadType=media&name=$encodedName&ifGenerationMatch=0"
  $result = Invoke-ReleaseLockRequest $Root 'Post' $uri $body
  if ($result.bucket -ne $bucket -or $result.name -ne $name -or $result.generation -notmatch '^[1-9][0-9]*$') {
    throw 'Release lock identity was not verified. Inspect the lock; no release mutation was started.'
  }
  Write-Host "Acquired $project release lock, generation $($result.generation), owner $owner."
  return [pscustomobject]@{projectId=$project;bucket=$bucket;name=$name;generation=[string]$result.generation;owner=$owner}
}

function Exit-ReleaseMutationLock {
  param([string]$Root, [object]$Definition, [object]$Lock)
  if (-not $Lock) { return }
  $project = $Definition.projectId
  if ($Lock.projectId -ne $project -or $Lock.bucket -ne "${project}_cloudbuild" -or
      $Lock.name -ne '_release/mutation-lock.json' -or $Lock.generation -notmatch '^[1-9][0-9]*$') {
    throw 'Refusing to release a different environment or unverified lock.'
  }
  $encodedName = [Uri]::EscapeDataString($Lock.name)
  $uri = "https://storage.googleapis.com/storage/v1/b/$($Lock.bucket)/o/${encodedName}?ifGenerationMatch=$($Lock.generation)"
  Invoke-ReleaseLockRequest $Root 'Delete' $uri | Out-Null
  Write-Host "Released $project release lock, generation $($Lock.generation)."
}
