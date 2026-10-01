[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Component,
  [Parameter(Mandatory)][string]$CacheDirectory,
  [int]$ShardIndex = 0,
  [int]$ShardCount = 1
)
. (Join-Path $PSScriptRoot "release_support.ps1")
. (Join-Path $PSScriptRoot "release_cache.ps1")
. (Join-Path $PSScriptRoot "prepare_release.ps1")
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
if ($Component -notin @(Get-ReleaseComponents "Coordinated") -or $ShardCount -lt 1 -or $ShardIndex -lt 0 -or $ShardIndex -ge $ShardCount) { throw "Invalid component/shard." }
if ($Component -ne "client-checks" -and $ShardCount -ne 1) { throw "Only client tests can be sharded." }
$cacheRoot = [IO.Path]::GetFullPath($CacheDirectory)
$logs = Join-Path $root ".tmp/ci-logs/$Component-$ShardIndex"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$inputDigest = Get-ReleaseComponentInputs $root $Component
$chain = Get-ReleaseToolchain $root (Get-ReleaseComponentFamily $Component)
$key = Get-ReleaseComponentKey $inputDigest $chain
$commit = Invoke-ReleaseCommand git @("rev-parse", "HEAD") $root
$timer = [Diagnostics.Stopwatch]::StartNew()
if ($ShardCount -eq 1 -and (Get-ReleaseCachedComponent $cacheRoot $Component $key)) {
  if ($ShardCount -ne 1) { throw "Sharded CI checks require a fresh isolated component directory." }
  Write-Host "Reusing verified $Component"
  $path = Join-Path $cacheRoot "components/$Component/$key/component.json"
  $record = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
  $record.sourceCommit = $commit
  $record | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
} else {
  Invoke-ReleaseComponent $root $Component $logs $ShardIndex $ShardCount
  if ((Get-ReleaseComponentInputs $root $Component) -ne $inputDigest) { throw "CI inputs changed during validation." }
  $artifact = switch ($Component) { "functions-build" { Join-Path $root "functions/lib" } "client-build" { Join-Path $root "build/web" } default { "" } }
  Save-ReleaseCachedComponent $cacheRoot $Component $key $inputDigest $chain $commit (Join-Path $logs "$Component.log") $artifact $timer.Elapsed.TotalSeconds
  if ($ShardCount -gt 1) {
    $path = Join-Path $cacheRoot "components/$Component/$key/component.json"
    $record = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    $record | Add-Member shardIndex $ShardIndex
    $record | Add-Member shardCount $ShardCount
    $record | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
  }
}
