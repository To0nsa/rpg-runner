Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-ReleaseCheckout {
  param([string]$Root, [string]$Commit)
  $sha = Invoke-ReleaseCommand git @("rev-parse", "--verify", "$Commit^{commit}") $Root
  if ($sha -notmatch '^[a-f0-9]{40}$') { throw "Invalid release commit." }
  $directory = Join-Path (Get-ReleaseCommonRoot $Root) ".tmp/release-checkouts/$sha"
  if (Test-Path -LiteralPath $directory) {
    if ((Invoke-ReleaseCommand git @("rev-parse", "HEAD") $directory) -ne $sha -or
        (Invoke-ReleaseCommand git @("status", "--porcelain") $directory)) { throw "Existing release checkout differs from its frozen commit." }
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $directory) | Out-Null
    Invoke-ReleaseCommand git @("-c", "core.autocrlf=false", "worktree", "add", "--detach", $directory, $sha) $Root | Write-Host
  }
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Root "functions") -Filter ".env*" -File) {
    if ($file.Name -eq ".env" -or $file.Name -eq ".env.$((Get-Content -Raw (Join-Path $Root '.firebaserc') | ConvertFrom-Json).projects.default)") {
      Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $directory "functions/$($file.Name)") -Force
    }
  }
  Write-Host "Frozen release checkout: $directory"
  Write-Output $directory
}

function Assert-ReleaseCIRun {
  param([object]$Run, [string]$Repository, [string]$Commit)
  if ($Run.path -ne ".github/workflows/release-preparation.yml" -or $Run.status -ne "completed" -or
      $Run.conclusion -ne "success" -or $Run.head_sha -ne $Commit -or
      $Run.head_repository.full_name -ne $Repository -or $Run.repository.full_name -ne $Repository -or
      $Run.event -notin @("push", "workflow_dispatch")) {
    throw "CI bundle requires a successful trusted release-preparation run for this exact commit; fork and PR artifacts are not accepted."
  }
}

function Import-ReleaseCI {
  param([string]$Root, [string]$CacheRoot, [long]$RunId)
  if ($RunId -le 0) { throw "ImportCI requires -RunId from the successful release-preparation workflow." }
  $origin = Invoke-ReleaseCommand git @("remote", "get-url", "origin") $Root
  $match = [regex]::Match($origin, 'github\.com[:/]([^/\s]+/[^/\s]+?)(?:\.git)?$')
  if (-not $match.Success) { throw "CI import requires a GitHub origin." }
  # GitHub redirects renamed origins; run metadata uses the canonical full name.
  $repository = Invoke-ReleaseCommand gh @("api", "repos/$($match.Groups[1].Value)", "--jq", ".full_name") $Root
  if ($repository -notmatch '^[^/\s]+/[^/\s]+$') { throw "Cannot resolve canonical GitHub repository." }
  $commit = Invoke-ReleaseCommand git @("rev-parse", "HEAD") $Root
  if (Invoke-ReleaseCommand git @("status", "--porcelain") $Root) { throw "ImportCI requires a clean frozen commit." }
  $run = Invoke-ReleaseCommand gh @("api", "repos/$repository/actions/runs/$RunId") $Root | ConvertFrom-Json
  Assert-ReleaseCIRun $run $repository $commit
  $download = Join-Path $CacheRoot "imports/$RunId-$([Guid]::NewGuid().ToString('N'))"
  Invoke-ReleaseCommand gh @("run", "download", "$RunId", "--repo", $repository, "--name", "release-bundle", "--dir", $download) $Root | Out-Null
  $manifest = Get-Content -Raw -LiteralPath (Join-Path $download "bundle.json") | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1 -or $manifest.sourceCommit -ne $commit -or $manifest.runId -ne $RunId) { throw "CI bundle provenance mismatch." }
  foreach ($component in Get-ReleaseComponents "Coordinated") {
    $entry = @($manifest.components | Where-Object { $_.component -eq $component })
    if ($entry.Count -ne 1) { throw "CI bundle is missing unique evidence for $component." }
    $inputDigest = Get-ReleaseComponentInputs $Root $component
    $chain = Get-ReleaseToolchain $Root (Get-ReleaseComponentFamily $component)
    $key = Get-ReleaseComponentKey $inputDigest $chain
    if ($entry[0].key -ne $key) { throw "CI $component inputs/toolchain differ. Use the pinned CI SDKs or local Prepare." }
    $record = Get-ReleaseCachedComponent $download $component $key
    if (-not $record -or $record.sourceCommit -ne $commit -or $record.inputDigest -ne $inputDigest -or $record.toolchain -ne $chain) { throw "Invalid CI component evidence: $component" }
    $artifact = if ($record.artifactDigest) { Join-Path $download "components/$component/$key/artifact" } else { "" }
    Save-ReleaseCachedComponent $CacheRoot $component $key $inputDigest $chain $commit (Join-Path $download "components/$component/$key/validation.log") $artifact $record.durationSeconds
  }
  Write-Host "Imported verified CI components from $repository run $RunId. Run Prepare to restore artifacts and audit current dependencies."
}

function Merge-ReleaseCIBundle {
  param([string]$Downloads, [string]$Destination, [string]$Commit, [long]$RunId)
  $records = @()
  foreach ($component in Get-ReleaseComponents "Coordinated") {
    $fragments = if ($component -eq "client-checks") { @(0..3 | ForEach-Object { "release-client-checks-$_" }) } else { @("release-$component") }
    $reference = $null
    foreach ($fragment in $fragments) {
      $files = @(Get-ChildItem -LiteralPath (Join-Path $Downloads $fragment) -Filter component.json -Recurse -File)
      if ($files.Count -ne 1) { throw "Incomplete CI fragment: $fragment" }
      $record = Get-Content -Raw -LiteralPath $files[0].FullName | ConvertFrom-Json
      if ($record.sourceCommit -ne $Commit -or $record.component -ne $component) { throw "CI fragment source/component mismatch." }
      if ($reference -and ($reference.key -ne $record.key -or $reference.toolchain -ne $record.toolchain -or $reference.inputDigest -ne $record.inputDigest)) { throw "Client shards used different inputs/toolchains." }
      if ($component -eq "client-checks") {
        if ($record.shardCount -ne 4 -or $fragment -ne "release-client-checks-$($record.shardIndex)" -or -not $record.passed) { throw "Incomplete client shard coverage." }
      } else {
        Get-ReleaseCachedComponent (Join-Path $Downloads $fragment) $component $record.key | Out-Null
      }
      if (-not $reference) { $reference = $record; $referenceDirectory = Split-Path $files[0].FullName }
    }
    $target = Join-Path $Destination "components/$component/$($reference.key)"
    Copy-ReleaseTree $referenceDirectory $target
    if ($component -eq "client-checks") {
      $reference.PSObject.Properties.Remove("shardCount")
      $reference.PSObject.Properties.Remove("shardIndex")
      $reference | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target "component.json") -Encoding utf8
    }
    $records += @{ component = $component; key = $reference.key }
  }
  @{ schemaVersion = 1; sourceCommit = $Commit; runId = $RunId; components = $records } |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Destination "bundle.json") -Encoding utf8
}
