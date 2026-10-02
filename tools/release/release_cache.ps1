Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ReleaseCommonRoot {
  param([string]$Root)
  $common = Invoke-ReleaseCommand git @("rev-parse", "--path-format=absolute", "--git-common-dir") $Root
  return Split-Path ([IO.Path]::GetFullPath($common))
}

function Get-ReleaseCacheRoot {
  param([string]$Root, [string]$Override = "")
  if ($Override) { return [IO.Path]::GetFullPath($Override) }
  return Join-Path (Get-ReleaseCommonRoot $Root) ".tmp/release-cache"
}

function Get-ReleaseInputPaths {
  param([string]$Root)
  $listing = Invoke-ReleaseCommand git @("ls-files", "--cached", "--others", "--exclude-standard") $Root
  return @($listing -split '\r?\n' | Where-Object {
    $_ -and $_ -notmatch '(^|/)(node_modules|\.dart_tool|build|coverage)/' -and
    $_ -notmatch '^functions/(lib|lib_test)/' -and $_ -notmatch '\.md$' -and (Test-Path -LiteralPath (Join-Path $Root $_) -PathType Leaf)
  })
}

function Get-ReleaseInputHashes {
  param([string]$Root, [string]$ProjectId)
  $paths = Get-ReleaseInputPaths $Root
  $groups = [ordered]@{
    workspace = '^(pubspec\.(yaml|lock)$|analysis_options\.yaml$|packages/[^/]+/pubspec\.yaml$)'
    simulation = '^(packages/(runner_core|runner_content_pipeline)/(lib/|pubspec\.yaml$)|assets/authoring/|tool/)'
    protocol = '^(packages/run_protocol/(lib/|pubspec\.yaml$)|functions/src/(runs|boards|leaderboards|ghosts)/|functions/src/.*/(contracts|validators)\.ts$)'
    client = '^(lib/|web/|assets/|packages/[^/]+/(lib/|pubspec\.yaml$)|pubspec\.(yaml|lock)$)'
    functions = '^(functions/(src/|package\.json$|tsconfig\.json$)|firestore\.|firebase\.json$|package\.json$|pnpm-[^/]+\.yaml$)'
    worker = '^(services/replay_validator/(lib/|bin/|pubspec\.(yaml|lock)$|Dockerfile$|cloudbuild\.yaml$)|packages/(runner_core|run_protocol)/(lib/|pubspec\.yaml$)|\.dockerignore$|\.gcloudignore$)'
    infrastructure = '^(firebase\.json$|\.firebaserc$|tools/cloud/|services/replay_validator/configure_cloud\.ps1$)'
  }
  $result = [ordered]@{}
  foreach ($name in $groups.Keys) {
    $selected = @($paths | Where-Object { $_ -match $groups[$name] })
    if ($name -eq "client") { $selected += @($paths | Where-Object { $_ -match $groups.workspace }) }
    if ($name -in @("functions", "infrastructure")) {
      foreach ($relative in @("functions/.env", "functions/.env.$ProjectId")) {
        if (Test-Path -LiteralPath (Join-Path $Root $relative)) { $selected += $relative }
      }
    }
    $result[$name] = Get-ReleaseFileDigest $Root $selected
  }
  return [pscustomobject]$result
}

function Get-ReleaseComponentInputs {
  param([string]$Root, [string]$Component)
  $paths = Get-ReleaseInputPaths $Root
  $workspace = 'pubspec\.(yaml|lock)$|analysis_options\.yaml$|packages/[^/]+/pubspec\.yaml$'
  $runtime = 'packages/[^/]+/lib/'
  $pattern = switch ($Component) {
    "functions-build" { '^(functions/(src/|package\.json$|tsconfig\.json$)|package\.json$|pnpm-[^/]+\.yaml$)' }
    "functions-checks" { '^(functions/(src/|test/|tool/|package\.json$|tsconfig.*\.json$)|firebase\.test\.json$|firestore\.|package\.json$|pnpm-[^/]+\.yaml$|packages/run_protocol/lib/)' }
    "client-build" { "^($workspace|lib/|web/|assets/|$runtime)" }
    "client-checks" { "^($workspace|lib/|web/|assets/|test/|test_driver/|tool/|services/replay_validator/(lib/|bin/|test/|pubspec\.(yaml|lock)$)|$runtime)" }
    "core-checks" { "^($workspace|packages/runner_core/|assets/authoring/)" }
    "protocol-checks" { "^($workspace|packages/run_protocol/)" }
    "content-checks" { "^($workspace|packages/runner_content_pipeline/|packages/runner_core/lib/|assets/authoring/)" }
    "terrain-checks" { "^($workspace|packages/terrain_materials/)" }
    "validator-checks" { '^(services/replay_validator/|packages/(runner_core|run_protocol)/(lib/|pubspec\.yaml$)|analysis_options\.yaml$)' }
    "content-freshness" { "^($workspace|tool/|assets/authoring/|$runtime)" }
    default { throw "Unknown release component: $Component" }
  }
  $selected = @($paths | Where-Object { $_ -match $pattern })
  # Recipe changes invalidate evidence without invalidating it for prose edits.
  $selected += @($paths | Where-Object { $_ -match '^(tools/release/(release_support|release_cache|prepare_release|profile_tests|validate_release|release_ci)\.ps1|\.github/workflows/release-preparation\.yml)$' })
  return Get-ReleaseFileDigest $Root $selected
}

function Get-ReleaseToolchain {
  param([string]$Root, [string]$Family)
  switch ($Family) {
    "node" {
      return "node=$(Invoke-ReleaseCommand node @('--version') $Root);pnpm=$(Invoke-ReleaseCommand corepack @('pnpm','--version') $Root)"
    }
    "flutter" {
      $sdk = Invoke-ReleaseCommand flutter @("--version", "--machine") $Root | ConvertFrom-Json
      return "flutter=$($sdk.frameworkRevision);engine=$($sdk.engineRevision);dart=$($sdk.dartSdkVersion)"
    }
    "dart" {
      $sdk = Invoke-ReleaseCommand dart @("--version") $Root
      $version = [regex]::Match($sdk, 'Dart SDK version: ([^\s]+)').Groups[1].Value
      if (-not $version) { throw "Cannot identify Dart version." }
      return "dart=$version"
    }
    default { throw "Unknown toolchain family: $Family" }
  }
}

function Get-ReleaseComponentKey {
  param([string]$InputDigest, [string]$Toolchain)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("cache-v1`n$InputDigest`n$Toolchain")))).Replace("-", "").ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-ReleaseComponents {
  param([string]$Scope)
  switch ($Scope) {
    "None" { return @() }
    "Hosting" { return @("client-checks", "client-build") }
    "Backend" { return @("functions-checks", "functions-build") }
    "Coordinated" { return @("functions-checks", "functions-build", "client-checks", "client-build", "core-checks", "protocol-checks", "content-checks", "terrain-checks", "validator-checks", "content-freshness") }
    default { throw "Unknown release scope: $Scope" }
  }
}

function Read-ReleaseBaseline {
  param([string]$CacheRoot, [string]$ProjectId, [string]$Region)
  $path = Join-Path $CacheRoot "deployments/$ProjectId/$Region.json"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $baseline = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
  if ($baseline.schemaVersion -ne 2 -or $baseline.projectId -ne $ProjectId -or $baseline.region -ne $Region -or
      -not $baseline.verifiedAt -or -not $baseline.workerImage -or -not $baseline.webSha256 -or -not $baseline.functionsIdentity) {
    throw "Deployment baseline is incomplete; inspect production before replacing it."
  }
  foreach ($name in @("simulation", "protocol", "client", "functions", "worker", "infrastructure")) {
    if ($baseline.inputs.$name -notmatch '^[a-f0-9]{64}$') { throw "Invalid deployment baseline input: $name" }
  }
  return $baseline
}

function Resolve-ReleaseScope {
  param([object]$Inputs, [object]$Contract, [object]$Baseline, [string]$Requested = "Auto")
  $resolved = "Coordinated"
  if ($null -ne $Baseline) {
    $tupleChanged = ($Contract | ConvertTo-Json -Compress) -ne ($Baseline.contract | ConvertTo-Json -Compress)
    $sharedChanged = @("simulation", "protocol", "worker", "infrastructure") | Where-Object { $Inputs.$_ -ne $Baseline.inputs.$_ }
    $clientChanged = $Inputs.client -ne $Baseline.inputs.client
    $backendChanged = $Inputs.functions -ne $Baseline.inputs.functions
    if (-not $tupleChanged -and @($sharedChanged).Count -eq 0) {
      if ($clientChanged -and $backendChanged) { $resolved = "Coordinated" }
      elseif ($clientChanged) { $resolved = "Hosting" }
      elseif ($backendChanged) { $resolved = "Backend" }
      else { $resolved = "None" }
    }
    if ($Inputs.simulation -ne $Baseline.inputs.simulation -and $Contract.gameCompatVersion -eq $Baseline.contract.gameCompatVersion) {
      throw "Deterministic gameplay changed without a new gameCompatVersion. Bump the matching client/backend/worker tuple before release."
    }
  }
  if ($Requested -eq "Coordinated") { return "Coordinated" }
  if ($Requested -ne "Auto" -and $Requested -ne $resolved) {
    throw "Requested $Requested scope cannot satisfy $resolved changes. A verified matching production baseline is required for scoped deployment."
  }
  return $resolved
}

function Get-ReleaseArtifactFiles {
  param([string]$Directory)
  $pending = [Collections.Generic.Stack[string]]::new()
  $pending.Push($Directory)
  while ($pending.Count -gt 0) {
    $path = $pending.Pop()
    if (((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Release artifact contains a directory link." }
    foreach ($entry in Get-ChildItem -LiteralPath $path -Force) {
      if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Release artifact contains a link: $($entry.Name)" }
      if ($entry.PSIsContainer) { $pending.Push($entry.FullName) } else { $entry }
    }
  }
}

function Copy-ReleaseTree {
  param([string]$Source, [string]$Destination)
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  foreach ($file in Get-ReleaseArtifactFiles $Source) {
    $relative = $file.FullName.Substring($Source.TrimEnd('\', '/').Length + 1)
    $target = Join-Path $Destination $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
  }
}

function Get-ReleaseCachedComponent {
  param([string]$CacheRoot, [string]$Component, [string]$Key)
  if ($Component -notin @(Get-ReleaseComponents "Coordinated") -or $Key -notmatch '^[a-f0-9]{64}$') { throw "Invalid component cache path." }
  $directory = Join-Path $CacheRoot "components/$Component/$Key"
  $path = Join-Path $directory "component.json"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $record = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
  if ($record.schemaVersion -ne 1 -or $record.component -ne $Component -or $record.key -ne $Key -or $record.passed -ne $true) {
    throw "Invalid cached evidence for $Component. Remove that cache entry and rerun Prepare."
  }
  if ($record.PSObject.Properties.Name -contains "shardCount") { throw "Partial client shard evidence cannot be reused as complete validation." }
  if ((Get-ReleaseComponentKey $record.inputDigest $record.toolchain) -ne $Key) { throw "Cache input/toolchain key mismatch." }
  if ($record.artifactDigest) {
    Get-ReleaseArtifactFiles (Join-Path $directory "artifact") | Out-Null
    if ($record.artifactDigest -ne (Get-ReleaseTreeDigest (Join-Path $directory "artifact"))) {
      throw "Cached $Component artifact was modified. Remove that cache entry and rerun Prepare."
    }
  }
  return $record
}

function Save-ReleaseCachedComponent {
  param([string]$CacheRoot, [string]$Component, [string]$Key, [string]$InputDigest,
    [string]$Toolchain, [string]$SourceCommit, [string]$Log, [string]$Artifact = "", [double]$DurationSeconds = 0)
  $directory = Join-Path $CacheRoot "components/$Component/$Key"
  if (Test-Path -LiteralPath (Join-Path $directory "component.json")) {
    $existing = Get-ReleaseCachedComponent $CacheRoot $Component $Key
    if ($Artifact -and (Get-ReleaseTreeDigest $Artifact) -ne $existing.artifactDigest) { throw "Rebuilt $Component bytes differ for identical inputs/toolchain. Investigate before replacing verified artifacts." }
    return
  }
  # Publish a complete entry atomically; interrupted copies never become evidence.
  Get-ReleaseCachedComponent $CacheRoot $Component $Key | Out-Null
  $parent = Split-Path $directory
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $staging = Join-Path $parent "staging-$([Guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $staging | Out-Null
  $artifactDigest = ""
  if ($Artifact) {
    Copy-ReleaseTree $Artifact (Join-Path $staging "artifact")
    $artifactDigest = Get-ReleaseTreeDigest (Join-Path $staging "artifact")
  }
  if ($Log -and (Test-Path -LiteralPath $Log)) { Copy-Item -LiteralPath $Log -Destination (Join-Path $staging "validation.log") -Force }
  [ordered]@{
    schemaVersion = 1; component = $Component; key = $Key; inputDigest = $InputDigest
    toolchain = $Toolchain; sourceCommit = $SourceCommit; passed = $true
    completedAt = [DateTime]::UtcNow.ToString("o"); durationSeconds = $DurationSeconds
    platform = [Environment]::OSVersion.Platform.ToString(); artifactDigest = $artifactDigest
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $staging "component.json") -Encoding utf8
  if (Test-Path -LiteralPath $directory) { throw "Incomplete or concurrent cache entry exists: $directory. Inspect and remove that entry before retrying." }
  Move-Item -LiteralPath $staging -Destination $directory
}

function Restore-ReleaseArtifact {
  param([string]$Root, [string]$CacheRoot, [string]$Component, [string]$Key)
  $relative = switch ($Component) { "client-build" { "build/web" } "functions-build" { "functions/lib" } default { return } }
  $target = [IO.Path]::GetFullPath((Join-Path $Root $relative))
  $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Artifact target escapes the checkout." }
  $record = Get-ReleaseCachedComponent $CacheRoot $Component $Key
  if (-not $record -or -not $record.artifactDigest) { throw "No verified $Component artifact." }
  if (Test-Path -LiteralPath $target) {
    Get-ReleaseArtifactFiles $target | Out-Null
    if ((Get-ReleaseTreeDigest $target) -eq $record.artifactDigest) { return }
    Remove-ReleaseOutput $Root $relative
  }
  Copy-ReleaseTree (Join-Path $CacheRoot "components/$Component/$Key/artifact") $target
  if ((Get-ReleaseTreeDigest $target) -ne $record.artifactDigest) { throw "Restored $Component artifact differs from its cache." }
}

function Remove-ReleaseOutput {
  param([string]$Root, [string]$Relative)
  if ($Relative -notin @("functions/lib", "functions/lib_test", "build/web")) { throw "Unknown generated output path." }
  $absoluteRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $target = [IO.Path]::GetFullPath((Join-Path $absoluteRoot $Relative))
  if (-not $target.StartsWith($absoluteRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Generated output escapes checkout." }
  $ancestor = $absoluteRoot
  foreach ($part in $Relative.Split('/')) {
    $ancestor = Join-Path $ancestor $part
    if ((Test-Path -LiteralPath $ancestor) -and
        ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Generated output ancestor is a link." }
  }
  if (Test-Path -LiteralPath $target) {
    Get-ReleaseArtifactFiles $target | Out-Null
    Remove-Item -LiteralPath $target -Recurse -Force
  }
}
