param([switch]$Fixture, [switch]$Build)
$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$previousRoot = $env:RUNNER_REPO_ROOT
$previousDebug = $env:DEBUG
Push-Location $repository
try {
    $env:DEBUG = $null
    $env:RUNNER_REPO_ROOT = $repository
    & corepack pnpm --dir functions build
    if ($LASTEXITCODE -ne 0) { throw 'Admin service build failed.' }
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Workspace dependency resolution failed.' }
    Set-Location $PSScriptRoot
    $arguments = if ($Build) { @('build', 'windows') } else { @('run', '-d', 'windows') }
    if ($Fixture) { $arguments += '--dart-define=ADMIN_FIXTURE=true' }
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Admin Flutter command failed.' }
} finally {
    Pop-Location
    $env:RUNNER_REPO_ROOT = $previousRoot
    $env:DEBUG = $previousDebug
}
