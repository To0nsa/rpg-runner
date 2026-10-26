. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_environments.ps1')
. (Join-Path $PSScriptRoot 'android_signing.ps1')
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture = Join-Path $workspace ".tmp/release-tests/signing-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$definition = Get-ReleaseEnvironmentDefinition $workspace 'staging'
$bytes = [Text.Encoding]::UTF8.GetBytes('non-secret test fixture, not a real keystore')
$sha = [Security.Cryptography.SHA256]::Create()
try { $digest = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
finally { $sha.Dispose() }
$global:signingTestPayload = [pscustomobject]@{schemaVersion=1;projectId=$definition.projectId;environment='staging';
  keyAlias='upload';password='test-fixture';keystoreBase64=[Convert]::ToBase64String($bytes);keystoreSha256=$digest}
$script:passed = 0
function Assert-SigningTest {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:passed++; Write-Host "PASS: $Message"
}
function Read-AndroidSigningPayload { return $global:signingTestPayload }
$oldPassword = $env:LOTHRINGEN_STAGING_STORE_PASSWORD
$oldPath = $env:LOTHRINGEN_STAGING_KEYSTORE
try {
  Assert-AndroidSigningPayload $global:signingTestPayload $definition staging
  Assert-SigningTest $true 'own environment and keystore digest are accepted'
  $failed = $false
  try { Assert-AndroidSigningPayload $global:signingTestPayload (Get-ReleaseEnvironmentDefinition $workspace prod) prod }
  catch { $failed = $true }
  Assert-SigningTest $failed 'another environment signing key is rejected'
  $global:signingTestPayload.keystoreBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('tampered'))
  $failed = $false
  try { Assert-AndroidSigningPayload $global:signingTestPayload $definition staging } catch { $failed = $true }
  Assert-SigningTest $failed 'tampered keystore bytes are rejected'
  $global:signingTestPayload.keystoreBase64 = [Convert]::ToBase64String($bytes)
  $env:LOTHRINGEN_STAGING_STORE_PASSWORD = 'preexisting-fixture'
  $env:LOTHRINGEN_STAGING_KEYSTORE = 'preexisting-path'
  $failed = $false
  try {
    Invoke-WithAndroidUploadSigning $fixture $definition staging {
      Assert-SigningTest ((Test-Path -LiteralPath $env:LOTHRINGEN_STAGING_KEYSTORE) -and
        $env:LOTHRINGEN_STAGING_STORE_PASSWORD -eq 'test-fixture') 'build gets only temporary signing inputs'
      throw 'Expected build failure'
    }
  } catch { $failed = $_.Exception.Message -eq 'Expected build failure' }
  Assert-SigningTest $failed 'build failures propagate'
  Assert-SigningTest ($env:LOTHRINGEN_STAGING_STORE_PASSWORD -eq 'preexisting-fixture' -and
    $env:LOTHRINGEN_STAGING_KEYSTORE -eq 'preexisting-path') 'environment restored after failed build'
  Assert-SigningTest (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.tmp/release-signing') -Filter '*.jks').Count -eq 0) 'temporary keystore removed after failed build'
  Invoke-WithAndroidUploadSigning $fixture $definition dev { Assert-SigningTest $true 'dev uses no cloud upload-signing key' }
  Write-Host "$script:passed signing checks passed; no cloud credentials used."
} finally {
  $env:LOTHRINGEN_STAGING_STORE_PASSWORD = $oldPassword
  $env:LOTHRINGEN_STAGING_KEYSTORE = $oldPath
  $global:signingTestPayload = $null
  $allowed = [IO.Path]::GetFullPath((Join-Path $workspace '.tmp/release-tests')).TrimEnd('\') + '\'
  $resolved = [IO.Path]::GetFullPath($fixture)
  if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
