Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root    = (Resolve-Path ".").Path
$outputDir = Join-Path $root "tools/output"
New-Item -ItemType Directory -Force -Path $outputDir

# Prefer git: deterministic + ignores build junk by default
git rev-parse --is-inside-work-tree *> $null

$commit = (git rev-parse --short=12 HEAD).Trim()
$when   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Bundle filenames
$bundleCommit = Join-Path $outputDir ("src-bundle-flutter-$commit.txt")
$bundleLatest = Join-Path $outputDir "src-bundle-flutter.txt"

$treeOut   = Join-Path $outputDir "tree.txt"
$assetsOut = Join-Path $outputDir "assets-list.txt"

# Tracked files only (best signal/noise)
$files = git ls-files -- lib | Sort-Object

# Write tree
$files | Set-Content -Encoding utf8 $treeOut

# Binary / huge extensions (skip in bundle)
$skipExt = @(
  ".png",".jpg",".jpeg",".webp",".gif",".bmp",".ico",
  ".mp3",".wav",".ogg",".mp4",
  ".ttf",".otf",
  ".zip",".7z",".rar",".pdf",
  ".exe",".dll",".so",".dylib"
)

# Also skip known generated folders even if tracked accidentally
# Use forward-slash paths (git ls-files outputs '/')
$skipPathRegex = '(/|^)(\.dart_tool|build|\.idea)(/|$)|(^|/)(ios/Pods|ios/\.symlinks|android/\.gradle)(/|$)'

# Header lines
$header = @(
  "REPO: $root"
  "COMMIT: $commit"
  "DATE: $when"
  ""
)

# Start fresh (explicit)
$header | Set-Content -Encoding utf8 $bundleCommit
$header | Set-Content -Encoding utf8 $bundleLatest

# Collect asset paths (so we still know what exists)
$assetPaths = New-Object System.Collections.Generic.List[string]

foreach ($rel in $files) {
  if ($rel -match $skipPathRegex) { continue }

  $full = Join-Path $root $rel
  if (-not (Test-Path $full -PathType Leaf)) { continue }

  $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()

  if ($skipExt -contains $ext) {
    if ($rel -like "assets/*" -or $rel -like "resources/*") { $assetPaths.Add($rel) }
    continue
  }

  foreach ($out in @($bundleCommit, $bundleLatest)) {
    try {
      Add-Content -Path $out -Value "" -Encoding utf8 -Force
      Add-Content -Path $out -Value "===== FILE: $rel =====" -Encoding utf8 -Force
      Add-Content -Path $out -Value (Get-Content -Raw -Encoding utf8 $full) -Encoding utf8 -Force
    }
    catch {
      Write-Warning "Failed to write to $out`: $_"
      # Ensure the file is not locked by recreating it
      Remove-Item -Path $out -Force -ErrorAction SilentlyContinue
      $header | Set-Content -Encoding utf8 $out
      Add-Content -Path $out -Value "" -Encoding utf8 -Force
      Add-Content -Path $out -Value "===== FILE: $rel =====" -Encoding utf8 -Force
      Add-Content -Path $out -Value (Get-Content -Raw -Encoding utf8 $full) -Encoding utf8 -Force
    }
  }
}

$assetPaths | Sort-Object | Set-Content -Encoding utf8 $assetsOut

Write-Host "Wrote bundle: $bundleCommit"
Write-Host "Wrote latest: $bundleLatest"
