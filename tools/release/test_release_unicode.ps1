[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_cache.ps1')
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixtureRoot = Join-Path $workspace '.tmp/release-unicode-tests'
$fixture = Join-Path $fixtureRoot ([Guid]::NewGuid().ToString('N'))
$savedEncoding = [Console]::OutputEncoding
$job = $null
New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'assets') | Out-Null
try {
  [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(850)
  Invoke-ReleaseCommand git @('init', '--quiet') $fixture | Out-Null
  $asset = 'assets/Th' + [char]0xE9 + 'odonis.txt'
  [IO.File]::WriteAllText((Join-Path $fixture $asset), 'first', [Text.UTF8Encoding]::new($false))
  $paths = @(Get-ReleaseInputPaths $fixture)
  if ($asset -notin $paths) { throw 'Parent fingerprint omitted the Unicode asset.' }
  if ([Console]::OutputEncoding.CodePage -ne 850) { throw 'Native command changed caller encoding.' }
  $expected = Get-ReleaseComponentInputs $fixture 'client-checks'
  $job = Start-Job -ScriptBlock {
    param($Root, $Scripts, $Asset)
    [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(850)
    . (Join-Path $Scripts 'release_support.ps1')
    . (Join-Path $Scripts 'release_cache.ps1')
    [pscustomobject]@{
      hasAsset = $Asset -in @(Get-ReleaseInputPaths $Root)
      digest = Get-ReleaseComponentInputs $Root 'client-checks'
      restoredCodePage = [Console]::OutputEncoding.CodePage
    }
  } -ArgumentList $fixture, $PSScriptRoot, $asset
  $actual = $job | Wait-Job | Receive-Job -ErrorAction Stop
  if (-not $actual.hasAsset -or $actual.digest -ne $expected -or $actual.restoredCodePage -ne 850) {
    throw 'Background-job Unicode fingerprint or encoding restoration differs from parent.'
  }
  [IO.File]::WriteAllText((Join-Path $fixture $asset), 'changed', [Text.UTF8Encoding]::new($false))
  if ((Get-ReleaseComponentInputs $fixture 'client-checks') -eq $expected) {
    throw 'Unicode asset mutation did not invalidate the fingerprint.'
  }
  $failed = $false
  try { Invoke-ReleaseCommand git @('rev-parse', '--verify', 'missing-ref') $fixture | Out-Null }
  catch { $failed = $true }
  if (-not $failed -or [Console]::OutputEncoding.CodePage -ne 850) {
    throw 'Failed native command did not restore caller encoding.'
  }
  Write-Host 'PASS: Unicode assets are fingerprinted identically in OEM parent/jobs, invalidate on change, and restore encoding on success/failure.'
} finally {
  [Console]::OutputEncoding = $savedEncoding
  if ($job) { $job | Remove-Job -Force }
  $resolved = (Resolve-Path -LiteralPath $fixture).Path
  if (-not $resolved.StartsWith($fixtureRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unsafe Unicode fixture cleanup.'
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
