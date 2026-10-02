Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "profile_tests.ps1")

function Get-ReleaseComponentFamily {
  param([string]$Component)
  if ($Component -like "functions-*") { return "node" }
  if ($Component -eq "validator-checks") { return "dart" }
  return "flutter"
}

function Invoke-ReleaseComponent {
  param([string]$Root, [string]$Component, [string]$LogDirectory, [int]$ShardIndex = 0, [int]$ShardCount = 1)
  $log = Join-Path $LogDirectory "$Component.log"
  switch ($Component) {
    "functions-checks" {
      Remove-ReleaseOutput $Root "functions/lib_test"
      Invoke-ReleaseCommand corepack @("pnpm", "--dir", "functions", "test") $Root $log | Out-Null
    }
    "functions-build" {
      Remove-ReleaseOutput $Root "functions/lib"
      Invoke-ReleaseCommand corepack @("pnpm", "--dir", "functions", "build") $Root $log | Out-Null
    }
    "client-checks" {
      if ($ShardIndex -eq 0) {
        foreach ($directory in @("lib", "test", "test_driver")) {
          if (Test-Path -LiteralPath (Join-Path $Root $directory)) {
            Invoke-ReleaseCommand dart @("analyze", $directory) $Root $log | Out-Null
          }
        }
      }
      $report = Join-Path $LogDirectory "client-tests-$ShardIndex.jsonl"
      Invoke-ReleaseCommand flutter @("test", "--no-pub", "--exclude-tags=integration",
        "--total-shards=$ShardCount", "--shard-index=$ShardIndex", "--file-reporter=json:$report") $Root $log | Out-Null
      Get-ReleaseTestTimings @($report) | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $LogDirectory "slow-tests-$ShardIndex.json") -Encoding utf8
    }
    "client-build" {
      Invoke-ReleaseCommand flutter @("build", "web", "--release", "--no-pub") $Root $log | Out-Null
    }
    "validator-checks" {
      $directory = Join-Path $Root "services/replay_validator"
      Invoke-ReleaseCommand dart @("analyze") $directory $log | Out-Null
      Invoke-ReleaseCommand dart @("test", "test") $directory $log | Out-Null
      $probe = Join-Path $LogDirectory "aot_protocol_probe.exe"
      Invoke-ReleaseCommand dart @("compile", "exe", "tool/aot_protocol_probe.dart", "-o", $probe) $directory $log | Out-Null
      Invoke-ReleaseCommand $probe @() $directory $log | Out-Null
    }
    "content-freshness" {
      Invoke-ReleaseCommand dart @("run", "tool/generate_chunk_runtime_data.dart", "--dry-run") $Root $log | Out-Null
    }
    default {
      $package = switch ($Component) {
        "core-checks" { "runner_core" }; "protocol-checks" { "run_protocol" }
        "content-checks" { "runner_content_pipeline" }; "terrain-checks" { "terrain_materials" }
        default { throw "Unknown component: $Component" }
      }
      $directory = Join-Path $Root "packages/$package"
      Invoke-ReleaseCommand dart @("analyze") $directory $log | Out-Null
      Invoke-ReleaseCommand dart @("test", "test") $directory $log | Out-Null
    }
  }
}

function Invoke-ReleasePreparation {
  param([string]$Root, [string]$CacheRoot, [string[]]$Components, [string]$LogDirectory,
    [switch]$Rebuild, [int]$ShardIndex = 0, [int]$ShardCount = 1)
  New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
  if (-not $Components) { return @() }
  $sourceCommit = Invoke-ReleaseCommand git @("rev-parse", "HEAD") $Root
  $chains = @{}; $items = @(); $pending = @()
  foreach ($component in $Components) {
    $family = Get-ReleaseComponentFamily $component
    if (-not $chains.ContainsKey($family)) { $chains[$family] = Get-ReleaseToolchain $Root $family }
    $inputDigest = Get-ReleaseComponentInputs $Root $component
    $key = Get-ReleaseComponentKey $inputDigest $chains[$family]
    $cached = Get-ReleaseCachedComponent $CacheRoot $component $key
    $item = [pscustomobject]@{ component = $component; inputDigest = $inputDigest; key = $key; toolchain = $chains[$family] }
    $items += $item
    if ($cached -and -not $Rebuild) {
      Restore-ReleaseArtifact $Root $CacheRoot $component $key
      Write-Host "Reusing $component ($($key.Substring(0,12)))"
    } else { $pending += $item }
  }
  $dependencies = Join-Path $LogDirectory "dependencies.log"
  # Deployment and inventory still need the pinned Firebase CLI on cache hits.
  if (@($pending | Where-Object { $_.component -like "functions-*" }).Count -gt 0 -or
      -not (Test-Path -LiteralPath (Join-Path $Root "functions/node_modules/firebase-tools"))) {
    Invoke-ReleaseCommand corepack @("pnpm", "install", "--frozen-lockfile") $Root $dependencies | Out-Null
  }
  if (@($pending | Where-Object { $_.component -ne "validator-checks" -and $_.component -notlike "functions-*" }).Count -gt 0) {
    Invoke-ReleaseCommand flutter @("pub", "get", "--enforce-lockfile") $Root $dependencies | Out-Null
  }
  # Client generator tests compile real worker fixtures using this independent
  # package configuration, even when the validator's own checks are cached.
  if (@($pending | Where-Object { $_.component -in @("validator-checks", "client-checks") }).Count -gt 0) {
    Invoke-ReleaseCommand dart @("pub", "get", "--enforce-lockfile") (Join-Path $Root "services/replay_validator") $dependencies | Out-Null
  }
  if (@($Components | Where-Object { $_ -like "functions-*" }).Count -gt 0) {
    # Advisories change without source changes; this short network check is never cached.
    Invoke-ReleaseCommand corepack @("pnpm", "--dir", "functions", "audit", "--prod") $Root (Join-Path $LogDirectory "audit.log") | Out-Null
  }
  $jobs = @()
  $worker = {
    param($Root, $Scripts, $CacheRoot, $LogDirectory, $Items, $Commit, $ShardIndex, $ShardCount)
    . (Join-Path $Scripts "release_support.ps1")
    . (Join-Path $Scripts "release_cache.ps1")
    . (Join-Path $Scripts "prepare_release.ps1")
    foreach ($item in $Items) {
      $timer = [Diagnostics.Stopwatch]::StartNew()
      Invoke-ReleaseComponent $Root $item.component $LogDirectory $ShardIndex $ShardCount
      if ((Get-ReleaseComponentInputs $Root $item.component) -ne $item.inputDigest) { throw "Source changed during $($item.component)." }
      $artifact = switch ($item.component) { "functions-build" { Join-Path $Root "functions/lib" } "client-build" { Join-Path $Root "build/web" } default { "" } }
      Save-ReleaseCachedComponent $CacheRoot $item.component $item.key $item.inputDigest $item.toolchain $Commit (Join-Path $LogDirectory "$($item.component).log") $artifact $timer.Elapsed.TotalSeconds
      Write-Output "$($item.component) passed in $([int]$timer.Elapsed.TotalSeconds)s"
    }
  }
  try {
    # Avoid competing analyzers within the workspace and emulator/build writes
    # within Functions; independent client, Node and Dart service jobs overlap.
    foreach ($family in @("node", "flutter", "dart")) {
      $work = @($pending | Where-Object { (Get-ReleaseComponentFamily $_.component) -eq $family })
      if ($work.Count -eq 0) { continue }
      $jobs += Start-Job -Name $family -ScriptBlock $worker -ArgumentList $Root, $PSScriptRoot, $CacheRoot, $LogDirectory, $work, $sourceCommit, $ShardIndex, $ShardCount
    }
    while (@($jobs | Where-Object { $_.State -in @("Running", "NotStarted") }).Count -gt 0) {
      if (@($jobs | Where-Object { $_.State -eq "Failed" }).Count -gt 0) { break }
      $active = @($jobs | Where-Object { $_.State -in @("Running", "NotStarted") })
      Wait-Job -Job $active -Any -Timeout 5 | Out-Null
    }
    foreach ($job in $jobs) {
      Receive-Job -Job $job -ErrorAction Stop | Write-Host
      if ($job.State -ne "Completed") { throw "$($job.Name) preparation failed." }
    }
  } finally {
    $jobs | Where-Object { $_.State -eq "Running" } | Stop-Job
    $jobs | Remove-Job -Force
  }
  foreach ($item in $items) {
    if ((Get-ReleaseComponentInputs $Root $item.component) -ne $item.inputDigest) { throw "Release inputs changed during preparation." }
    Get-ReleaseCachedComponent $CacheRoot $item.component $item.key | Out-Null
  }
  return $items
}
