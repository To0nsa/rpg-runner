Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root    = (Resolve-Path ".").Path
$bundle  = Join-Path $root "tools/output/src-bundle-flutter.txt"
$treeOut = Join-Path $root "tools/output/tree.txt"
$assetsOut = Join-Path $root "tools/output/assets-list.txt"
$outputDir = Join-Path $root "tools/output"
New-Item -ItemType Directory -Force -Path $outputDir

# Prefer git: deterministic + ignores build junk by default
git rev-parse --is-inside-work-tree *> $null

$commit = (git rev-parse HEAD).Trim()
$when   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Tracked files only (best signal/noise)
$files = git ls-files | Sort-Object

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
$skipPathRegex = '\\(\.dart_tool|build|\.idea)\\|(^|/)(ios/Pods|ios/\.symlinks|android/\.gradle)(/|$)'

# Header
@(
  "REPO: $root"
  "COMMIT: $commit"
  "DATE: $when"
  ""
) | Set-Content -Encoding utf8 $bundle

# Collect asset paths (so we still know what exists)
$assetPaths = New-Object System.Collections.Generic.List[string]

foreach ($rel in $files) {
  if ($rel -match $skipPathRegex) { continue }

  $full = Join-Path $root $rel
  if (-not (Test-Path $full -PathType Leaf)) { continue }

  $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()

  if ($skipExt -contains $ext) {
    # keep a list (very useful for Flame asset wiring)
    if ($rel -like "assets/*" -or $rel -like "resources/*") { $assetPaths.Add($rel) }
    continue
  }

  Add-Content -Encoding utf8 $bundle ""
  Add-Content -Encoding utf8 $bundle "===== FILE: $rel ====="
  Add-Content -Encoding utf8 $bundle (Get-Content -Raw -Encoding utf8 $full)
}

$assetPaths | Sort-Object | Set-Content -Encoding utf8 $assetsOut
