param(
  [int]$Runs = 4,
  [int]$WarmupTicks = 300,
  [int]$Ticks = 4000,
  [int]$SubpixelScale = 1024,
  [double]$MaxOverheadPct = 10.0
)

$ErrorActionPreference = "Stop"

$outDir = "test/integration_test/core-fixed-point/perf"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$noTrackJson = Join-Path $outDir "fixed_point_core_${stamp}_no_track.json"
$noTrackTxt = Join-Path $outDir "fixed_point_core_${stamp}_no_track.txt"
$trackJson = Join-Path $outDir "fixed_point_core_${stamp}_track_autoscroll.json"
$trackTxt = Join-Path $outDir "fixed_point_core_${stamp}_track_autoscroll.txt"

Write-Host "Running strict no-track benchmark..."
dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart `
  --runs=$Runs `
  --warmup-ticks=$WarmupTicks `
  --ticks=$Ticks `
  --subpixel-scale=$SubpixelScale `
  --strict `
  --max-overhead-pct=$MaxOverheadPct `
  --json-out=$noTrackJson | Tee-Object -FilePath $noTrackTxt

if ($LASTEXITCODE -ne 0) {
  throw "No-track strict benchmark failed (exit code $LASTEXITCODE)."
}

Write-Host "Running track+autoscroll benchmark..."
dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart `
  --runs=$Runs `
  --warmup-ticks=$WarmupTicks `
  --ticks=$Ticks `
  --subpixel-scale=$SubpixelScale `
  --track `
  --autoscroll `
  --json-out=$trackJson | Tee-Object -FilePath $trackTxt

if ($LASTEXITCODE -ne 0) {
  throw "Track+autoscroll benchmark failed (exit code $LASTEXITCODE)."
}

Write-Host ""
Write-Host "Artifacts:"
Write-Host "  $noTrackJson"
Write-Host "  $noTrackTxt"
Write-Host "  $trackJson"
Write-Host "  $trackTxt"
