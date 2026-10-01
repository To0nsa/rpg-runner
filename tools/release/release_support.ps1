Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-ReleaseCommand {
  param(
    [Parameter(Mandatory)][string]$Command,
    [string[]]$CommandArgs = @(),
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [string]$LogPath = ""
  )
  Get-Command $Command -ErrorAction Stop | Out-Null
  $scratch = Join-Path $WorkingDirectory ".tmp/release-stderr"
  New-Item -ItemType Directory -Force -Path $scratch | Out-Null
  $errorPath = Join-Path $scratch "$([Guid]::NewGuid().ToString('N')).log"
  Push-Location $WorkingDirectory
  $savedPreference = $ErrorActionPreference
  try {
    # Native warnings must stay out of JSON stdout and never masquerade as
    # failures under Windows PowerShell's stderr ErrorRecord conversion.
    $ErrorActionPreference = "Continue"
    $output = & $Command @CommandArgs 2> $errorPath
    $code = $LASTEXITCODE
    $diagnostics = if (Test-Path -LiteralPath $errorPath) {
      (Get-Content -Raw -LiteralPath $errorPath | Out-String).Trim()
    } else { "" }
  } finally {
    $ErrorActionPreference = $savedPreference
    Pop-Location
    if (Test-Path -LiteralPath $errorPath) { Remove-Item -LiteralPath $errorPath -Force }
  }
  $rendered = ($output | Out-String).Trim()
  if ($LogPath) {
    @($rendered, $diagnostics) | Add-Content -LiteralPath $LogPath -Encoding utf8
  }
  if ($code -ne 0) { throw "$Command failed ($code). $rendered $diagnostics" }
  if ($diagnostics -and -not $LogPath) { Write-Verbose $diagnostics }
  return $rendered
}

function Read-ReleaseEnvironment {
  param([string]$Root, [string]$ProjectId)
  $values = @{}
  foreach ($relative in @("functions/.env", "functions/.env.$ProjectId")) {
    $path = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $path)) { continue }
    foreach ($line in Get-Content -LiteralPath $path) {
      if ($line -match '^\s*([A-Z][A-Z0-9_]*)\s*=\s*(.*?)\s*$') {
        $values[$Matches[1]] = $Matches[2].Trim("'").Trim('"')
      }
    }
  }
  return $values
}

function Get-ReleaseContract {
  param([string]$Root, [string]$ProjectId)
  $client = Get-Content -Raw -LiteralPath (Join-Path $Root "lib/ui/state/app/app_state.dart")
  $backend = Get-Content -Raw -LiteralPath (Join-Path $Root "functions/src/runs/compatibility.ts")
  $boards = Get-Content -Raw -LiteralPath (Join-Path $Root "functions/src/boards/provisioning.ts")
  $worker = Get-Content -Raw -LiteralPath (Join-Path $Root "services/replay_validator/lib/src/validator_worker.dart")
  $clientMatch = [regex]::Match($client, "_defaultGameCompatVersion\s*=\s*'([^']+)'")
  $backendMatch = [regex]::Match($backend, 'currentGameCompatVersion\s*=\s*"([^"]+)"')
  if (-not $clientMatch.Success -or -not $backendMatch.Success) {
    throw "Cannot identify client/backend compatibility constants."
  }
  $version = $clientMatch.Groups[1].Value
  if ($version -ne $backendMatch.Groups[1].Value) { throw "Client/backend gameplay versions differ." }
  $contract = [ordered]@{ gameCompatVersion = $version }
  foreach ($entry in @(
    @("gameCompatVersion", "GameCompat", ""),
    @("rulesetVersion", "Ruleset", "Ruleset"),
    @("scoreVersion", "Score", "Score"),
    @("ghostVersion", "Ghost", "Ghost")
  )) {
    $match = [regex]::Match($worker, "_supported$($entry[1])Versions\s*=\s*<String>\{\s*'([^']+)'\s*\}")
    if (-not $match.Success) { throw "Worker must declare one supported $($entry[0]) for coordinated release." }
    $value = $match.Groups[1].Value
    if ($entry[2]) {
      $pattern = 'default{0}Version\s*=\s*"([^"]+)"' -f $entry[2]
      $boardMatch = [regex]::Match($boards, $pattern)
      if (-not $boardMatch.Success -or $boardMatch.Groups[1].Value -ne $value) {
        throw "Board/worker $($entry[0]) versions differ."
      }
      $contract[$entry[0]] = $value
    } elseif ($value -ne $version) { throw "Worker/client gameplay versions differ." }
  }
  $environment = Read-ReleaseEnvironment $Root $ProjectId
  $expected = @{
    RUN_SUPPORTED_GAME_COMPAT_VERSIONS = $contract.gameCompatVersion
    RUN_BOARD_GAME_COMPAT_VERSION = $contract.gameCompatVersion
    RUN_BOARD_RULESET_VERSION = $contract.rulesetVersion
    RUN_BOARD_SCORE_VERSION = $contract.scoreVersion
    RUN_BOARD_GHOST_VERSION = $contract.ghostVersion
  }
  foreach ($key in $expected.Keys) {
    if ($environment.ContainsKey($key) -and $environment[$key] -and $environment[$key] -ne $expected[$key]) {
      throw "Stale Functions override: $key. Remove it or align it with source."
    }
  }
  return $contract
}

function Get-ReleaseFileDigest {
  param([string]$Root, [string[]]$RelativePaths)
  $unique = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($relative in $RelativePaths) { $unique.Add($relative.Replace('\', '/')) | Out-Null }
  $sorted = [string[]]@($unique)
  [Array]::Sort($sorted, [StringComparer]::Ordinal)
  $records = foreach ($relative in $sorted) {
    $path = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Release input missing: $relative" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    "$relative $hash"
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-ReleaseSourceDigest {
  param([string]$Root, [string]$ProjectId)
  $listing = Invoke-ReleaseCommand git @("ls-files", "--cached", "--others", "--exclude-standard") $Root
  $paths = @($listing -split '\r?\n' | Where-Object {
    $_ -match '^(assets|lib|web|test|test_driver|packages|functions|services/replay_validator|tool|tools/cloud|tools/release|\.github/workflows)/' -or
    $_ -match '^(\.dockerignore|\.gcloudignore|\.firebaserc|firebase\.json|firestore\..+|pubspec\..+|package\.json|pnpm-.+\.yaml|analysis_options\.yaml)$'
  } | Where-Object { $_ -notmatch '^functions/(lib|lib_test|node_modules)/' -and (Test-Path -LiteralPath (Join-Path $Root $_) -PathType Leaf) })
  foreach ($relative in @("functions/.env", "functions/.env.$ProjectId")) {
    if (Test-Path -LiteralPath (Join-Path $Root $relative)) { $paths += $relative }
  }
  return Get-ReleaseFileDigest $Root $paths
}

function Get-ReleaseTreeDigest {
  param([string]$Directory)
  if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw "Release artifact directory missing: $Directory" }
  $absolute = (Resolve-Path -LiteralPath $Directory).Path.TrimEnd('\', '/')
  $paths = @(Get-ChildItem -LiteralPath $absolute -Recurse -File -Force |
    ForEach-Object { $_.FullName.Substring($absolute.Length + 1).Replace('\', '/') })
  if ($paths.Count -eq 0) { throw "Release artifact directory is empty: $Directory" }
  return Get-ReleaseFileDigest $absolute $paths
}

function Assert-ReleasePrepared {
  param([object]$State, [string]$SourceDigest, [string]$ProjectId, [string]$Region, [string]$Root)
  if ($State.schemaVersion -ne 2 -or $State.projectId -ne $ProjectId -or $State.region -ne $Region -or
      $State.sourceDigest -ne $SourceDigest -or $State.prepared -ne $true -or $State.scope -notin @("Hosting", "Backend", "Coordinated", "None")) {
    throw "No matching successful preparation. Run Prepare."
  }
  foreach ($entry in @(@("functionsDigest", "functions/lib"), @("webDigest", "build/web"))) {
    $digest = $State.($entry[0])
    if ($digest -and $digest -ne (Get-ReleaseTreeDigest (Join-Path $Root $entry[1]))) {
      throw "Prepared build artifacts changed. Run Prepare -Rebuild."
    }
  }
  if (($State.scope -in @("Backend", "Coordinated") -and -not $State.functionsDigest) -or
      ($State.scope -in @("Hosting", "Coordinated") -and -not $State.webDigest)) {
    throw "Required prepared build artifacts missing. Run Prepare."
  }
}

function Assert-ReleaseDrained {
  param([object]$Inventory)
  if ($Inventory.readOnly -ne $true) { throw "Expected read-only production inventory." }
  $terminal = @("validated", "rejected", "expired", "cancelled", "internal_error")
  foreach ($property in $Inventory.runs.sessionStateCounts.PSObject.Properties) {
    if ($property.Name -notin $terminal -and [long]$property.Value -gt 0) {
      throw "Cutover blocked: $($property.Value) sessions in $($property.Name)."
    }
  }
  foreach ($property in $Inventory.runs.rewardGrantStateCounts.PSObject.Properties) {
    if ($property.Name -eq "settlement_pending" -and [long]$property.Value -gt 0) {
      throw "Cutover blocked: unsettled reward grants."
    }
  }
  if ($Inventory.runs.quarantinedSettlementCount -gt 0) {
    throw "Cutover blocked: quarantined settlement needs operator review."
  }
}

function Assert-ReleaseImage {
  param([object]$State, [string]$ProjectId, [string]$Region)
  $prefix = "$Region-docker.pkg.dev/$ProjectId/replay/replay-validator"
  if ($State.imageUri -notmatch "^$([regex]::Escape($prefix))@sha256:[0-9a-f]{64}$" -or $State.imageVerified -ne $true) {
    throw "No matching benchmarked immutable image. Run BuildImage."
  }
}
