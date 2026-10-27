. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_lock.ps1')
$script:objects = @{}
$script:generation = 100
$script:passed = 0
$script:requestCount = 0
function Assert-LockTest {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:passed++; Write-Host "PASS: $Message"
}
function Invoke-ReleaseCommand { return 'test-token-never-logged' }
function Invoke-RestMethod {
  param($Method, $Uri, $Headers, $Body, $ContentType, $ErrorAction, $Verbose, $Debug)
  $script:requestCount++
  if ($Headers.Authorization -ne 'Bearer test-token-never-logged') { throw 'Missing operator auth.' }
  $bucket = [regex]::Match($Uri, '/b/([^/]+)/o').Groups[1].Value
  if ($Method -eq 'Post') {
    if (-not $Uri.EndsWith('&ifGenerationMatch=0')) { throw 'Missing create precondition.' }
    if ($script:objects.ContainsKey($bucket)) { throw 'Conflict' }
    $content = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
    $script:generation++
    $result = [pscustomobject]@{bucket=$bucket;name='_release/mutation-lock.json';generation=[string]$script:generation;content=$content}
    $script:objects[$bucket] = $result
    return $result
  }
  $expected = [regex]::Match($Uri, 'ifGenerationMatch=([0-9]+)$').Groups[1].Value
  if ($Method -ne 'Delete' -or -not $expected -or -not $script:objects.ContainsKey($bucket) -or
      $script:objects[$bucket].generation -ne $expected) { throw 'Changed generation' }
  $script:objects.Remove($bucket)
}
$stage = [pscustomobject]@{projectId='test-staging'}
$prod = [pscustomobject]@{projectId='test-production'}
$first = Enter-ReleaseMutationLock '' $stage 'Deploy'
Assert-LockTest ($script:objects['test-staging_cloudbuild'].content.action -eq 'Deploy') 'lock records action and operator instance'
$failed = $false
try { Enter-ReleaseMutationLock '' $stage 'PauseIssuance' | Out-Null } catch { $failed=$true }
Assert-LockTest ($failed -and $script:objects['test-staging_cloudbuild'].generation -eq $first.generation) 'second operator cannot replace a held lock'
$other = Enter-ReleaseMutationLock '' $prod 'Deploy'
Assert-LockTest ($script:objects.Count -eq 2) 'independent environments can operate concurrently'
$before = $script:requestCount
$failed = $false
try { Exit-ReleaseMutationLock '' $prod $first } catch { $failed=$true }
Assert-LockTest ($failed -and $script:requestCount -eq $before) 'wrong environment cannot release a lock'
Exit-ReleaseMutationLock '' $stage $first
$replacement = Enter-ReleaseMutationLock '' $stage 'Deploy'
$failed = $false
try { Exit-ReleaseMutationLock '' $stage $first } catch { $failed=$true }
Assert-LockTest ($failed -and $script:objects['test-staging_cloudbuild'].generation -eq $replacement.generation) 'stale cleanup cannot delete a replacement lock'
try { throw 'simulated deployment failure' } catch { } finally { Exit-ReleaseMutationLock '' $stage $replacement }
Assert-LockTest (-not $script:objects.ContainsKey('test-staging_cloudbuild')) 'finally releases the owned lock after failure'
Exit-ReleaseMutationLock '' $prod $other
Assert-LockTest ($script:objects.Count -eq 0) 'successful operators release only their own generations'
$script:cutoverRecord = $null
function Invoke-ReleaseLockRequest {
  param($Root, $Method, $Uri, $Body='', [switch]$AllowNotFound)
  if ($Method -eq 'Get') {
    if (-not $script:cutoverRecord) { return $null }
    if ($Uri -match 'alt=media') { return $script:cutoverRecord.content }
    return $script:cutoverRecord
  }
  if ($Method -eq 'Post') {
    if ($script:cutoverRecord -or -not $Uri.EndsWith('&ifGenerationMatch=0')) { throw 'Conflict' }
    $script:cutoverRecord = [pscustomobject]@{bucket='test-staging_cloudbuild';name='_release/cutover.json';generation='20';content=($Body | ConvertFrom-Json)}
    return $script:cutoverRecord
  }
  if ($Method -ne 'Delete' -or -not $Uri.EndsWith("?ifGenerationMatch=$($script:cutoverRecord.generation)")) { throw 'Wrong generation' }
  $script:cutoverRecord=$null
}
$digest='a'*64
$failed=$false
try { Assert-ReleaseCutoverOwner '' $stage $digest | Out-Null } catch { $failed=$true }
Assert-LockTest $failed 'deploy cannot adopt an unclaimed cutover'
$cutover = Assert-ReleaseCutoverOwner '' $stage $digest -Claim
Assert-LockTest ($cutover.sourceDigest -eq $digest) 'pause claims the prepared source'
$resumed = Assert-ReleaseCutoverOwner '' $stage $digest -Claim
Assert-LockTest ($resumed.generation -eq $cutover.generation) 'same candidate can resume across commands and operators'
$failed=$false
try { Assert-ReleaseCutoverOwner '' $stage ('b'*64) -Claim | Out-Null } catch { $failed=$true }
Assert-LockTest ($failed -and $script:cutoverRecord.content.sourceDigest -eq $digest) 'different candidate cannot interleave during maintenance'
$script:cutoverRecord.generation='21'
$failed=$false
try { Complete-ReleaseCutover '' $stage $cutover } catch { $failed=$true }
Assert-LockTest ($failed -and $null -ne $script:cutoverRecord) 'changed ownership generation blocks stale cleanup'
$script:cutoverRecord.generation='20'
Complete-ReleaseCutover '' $stage $cutover
Assert-LockTest ($null -eq $script:cutoverRecord) 'verified resume can clear its candidate record'
Write-Host "$script:passed release-lock checks passed; no cloud commands executed."
