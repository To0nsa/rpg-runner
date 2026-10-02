[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot "release_support.ps1")
. (Join-Path $PSScriptRoot "release_cache.ps1")
. (Join-Path $PSScriptRoot "prepare_release.ps1")
. (Join-Path $PSScriptRoot "release_ci.ps1")
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture = Join-Path $workspace ".tmp/release-tests/$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$global:cacheTrace = [Collections.Generic.List[string]]::new()
$global:cacheFailTests = $false
$script:passed = 0

function Assert-CacheTest {
  param([bool]$Value, [string]$Name)
  if (-not $Value) { throw "FAIL: $Name" }
  $script:passed++; Write-Host "PASS: $Name"
}
function Assert-CacheThrows {
  param([scriptblock]$Operation, [string]$Pattern, [string]$Name)
  $caught = $null
  try { & $Operation | Out-Null } catch { $caught = $_ }
  Assert-CacheTest ($caught -and $caught.Exception.Message -like "*$Pattern*") $Name
}
function git {
  $global:LASTEXITCODE = 0
  if (($args -join ' ') -like 'rev-parse*') { return 'c' * 40 }
  if (($args -join ' ') -eq 'status --porcelain') { return '' }
  if (($args -join ' ') -eq 'remote get-url origin') { return 'https://github.com/owner/legacy-name.git' }
  return @(Get-ChildItem -LiteralPath $fixture -Recurse -File |
    ForEach-Object { $_.FullName.Substring($fixture.Length + 1).Replace('\','/') } |
    Where-Object { $_ -notmatch '^(\.tmp/|build/|functions/lib/)' -and $_ -notmatch '/node_modules/' })
}
function node { $global:LASTEXITCODE = 0; return 'v24.16.0' }
function corepack {
  $global:LASTEXITCODE = 0; $command = $args -join ' '; $global:cacheTrace.Add($command)
  if ($command -eq 'pnpm --version') { return '11.22.0' }
  if ($command -like '*install*') { New-Item -ItemType Directory -Force -Path (Join-Path $PWD 'functions/node_modules/firebase-tools') | Out-Null }
  if ($command -eq 'pnpm --dir functions build') {
    New-Item -ItemType Directory -Force -Path (Join-Path $PWD 'functions/lib') | Out-Null
    'compiled backend' | Set-Content -LiteralPath (Join-Path $PWD 'functions/lib/index.js')
  }
  if ($command -eq 'pnpm --dir functions test' -and $global:cacheFailTests) { $global:LASTEXITCODE = 5; return 'failed test' }
  return 'ok'
}
function flutter {
  $global:LASTEXITCODE = 0; $command = $args -join ' '; $global:cacheTrace.Add("flutter $command")
  if ($command -eq '--version --machine') { return '{"frameworkRevision":"flutter-test","engineRevision":"engine-test","dartSdkVersion":"3.13.1"}' }
  if ($command -like 'build web*') {
    New-Item -ItemType Directory -Force -Path (Join-Path $PWD 'build/web') | Out-Null
    'compiled web' | Set-Content -LiteralPath (Join-Path $PWD 'build/web/main.dart.js')
  }
  if ($command -like 'test *') {
    $report = @($args | Where-Object { $_ -like '--file-reporter=json:*' })[0].Substring('--file-reporter=json:'.Length)
    @('{"type":"testStart","time":20,"test":{"id":1,"name":"slow case"}}', '{"type":"testDone","time":120,"testID":1,"result":"success"}') | Set-Content -LiteralPath $report
  }
  return 'ok'
}
function dart { $global:LASTEXITCODE = 0; $global:cacheTrace.Add("dart " + ($args -join ' ')); return 'Dart SDK version: 3.13.1 (stable)' }
# Run the real worker recipe with fake command boundaries, preserving its
# cache publication and failure handling without launching SDK/cloud processes.
function Start-Job {
  param($Name, $ScriptBlock, $ArgumentList)
  try { $output = @(& $ScriptBlock @ArgumentList); return [pscustomobject]@{ Name=$Name; State='Completed'; Output=$output; Failure=$null } }
  catch { return [pscustomobject]@{ Name=$Name; State='Failed'; Output=@(); Failure=$_ } }
}
function Receive-Job { param($Job); if ($Job.Failure) { throw $Job.Failure }; return $Job.Output }
function Remove-Job { param([Parameter(ValueFromPipeline)]$Job, [switch]$Force); process {} }
function gh {
  $global:LASTEXITCODE = 0
  if ($args[0] -eq 'api' -and $args -contains '--jq') { return 'owner/repo' }
  if ($args[0] -eq 'api') { return $global:cacheCIRun | ConvertTo-Json -Depth 8 }
  if (($args -join ' ') -like 'run download*') {
    $destination = $args[[Array]::IndexOf($args, '--dir') + 1]
    Copy-ReleaseTree $global:cacheCIBundle $destination
    return 'downloaded mock artifact'
  }
  throw 'Unexpected gh command.'
}

try {
  foreach ($relative in @('lib/ui/menu.dart','web/index.html','assets/images/icon.txt','packages/runner_core/lib/core.dart','packages/run_protocol/lib/protocol.dart',
    'functions/src/profiles/profile.ts','functions/test/profile.test.ts','test/ui_test.dart','pubspec.yaml','pubspec.lock', 'services/replay_validator/lib/server.dart',
    'services/replay_validator/pubspec.lock','tools/release/release_support.ps1','tools/release/release_cache.ps1','tools/release/prepare_release.ps1','tools/release/profile_tests.ps1')) {
    $path = Join-Path $fixture $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    'input' | Set-Content -LiteralPath $path
  }
  $cache = Join-Path $fixture '.tmp/cache'
  $logs = Join-Path $fixture '.tmp/logs'
  $components = @('functions-checks','functions-build','client-checks','client-build')
  $items = @(Invoke-ReleasePreparation $fixture $cache $components $logs)
  Assert-CacheTest ($items.Count -eq 4 -and @($global:cacheTrace | Where-Object { $_ -like 'flutter test *' }).Count -eq 1) 'first preparation runs real recipes once'
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -eq 'dart pub get --enforce-lockfile' }).Count -eq 1) 'client checks resolve independent worker fixtures without validator checks'
  $global:cacheTrace.Clear()
  # These absolute paths are both verified beneath the isolated fixture.
  foreach ($relative in @('build/web','functions/lib')) {
    $target = [IO.Path]::GetFullPath((Join-Path $fixture $relative))
    if (-not $target.StartsWith($fixture + '\')) { throw 'Invalid fixture artifact path.' }
    Remove-Item -LiteralPath $target -Recurse -Force
  }
  Invoke-ReleasePreparation $fixture $cache $components $logs | Out-Null
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -match '^flutter (test|build)|^pnpm --dir functions (test|build)' }).Count -eq 0) 'cache hit restores both artifacts without tests or builds'
  Assert-CacheTest ((Test-Path (Join-Path $fixture 'build/web/main.dart.js')) -and (Test-Path (Join-Path $fixture 'functions/lib/index.js'))) 'complete artifacts survive checkout cleanup'
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -like '*audit --prod' }).Count -eq 1) 'cache hits still check current production dependency advisories'
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -eq 'dart pub get --enforce-lockfile' }).Count -eq 0) 'fully cached checks need no worker fixture resolution'
  $global:cacheTrace.Clear()
  'new UI' | Set-Content -LiteralPath (Join-Path $fixture 'lib/ui/menu.dart')
  Invoke-ReleasePreparation $fixture $cache $components $logs | Out-Null
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -match '^pnpm --dir functions (test|build)' }).Count -eq 0) 'UI edits reuse backend checks and build'
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -like 'flutter build web*' }).Count -eq 1) 'UI edits rebuild the client'
  Assert-CacheTest (@($global:cacheTrace | Where-Object { $_ -eq 'dart pub get --enforce-lockfile' }).Count -eq 1) 'rerun client checks resolve worker fixtures independently of cached backend checks'
  $buildInput = Get-ReleaseComponentInputs $fixture 'client-build'
  $global:cacheTrace.Clear()
  'new test' | Set-Content -LiteralPath (Join-Path $fixture 'test/ui_test.dart')
  Invoke-ReleasePreparation $fixture $cache $components $logs | Out-Null
  Assert-CacheTest ((Get-ReleaseComponentInputs $fixture 'client-build') -eq $buildInput -and @($global:cacheTrace | Where-Object { $_ -like 'flutter build web*' }).Count -eq 0) 'test-only edits rerun checks without rebuilding web'
  $checksBefore = Get-ReleaseComponentInputs $fixture 'client-checks'
  'new worker resolution' | Set-Content -LiteralPath (Join-Path $fixture 'services/replay_validator/pubspec.lock')
  Assert-CacheTest ((Get-ReleaseComponentInputs $fixture 'client-checks') -ne $checksBefore -and (Get-ReleaseComponentInputs $fixture 'client-build') -eq $buildInput) 'worker fixture dependencies invalidate client checks without rebuilding web'
  $checksBefore = Get-ReleaseComponentInputs $fixture 'client-checks'
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'tool') | Out-Null
  'new generator' | Set-Content -LiteralPath (Join-Path $fixture 'tool/generate_chunk_runtime_data.dart')
  Assert-CacheTest ((Get-ReleaseComponentInputs $fixture 'client-checks') -ne $checksBefore) 'generator edits invalidate client test evidence'
  $clientBefore = Get-ReleaseComponentInputs $fixture 'client-build'
  $workerBefore = Get-ReleaseComponentInputs $fixture 'validator-checks'
  'new physics' | Set-Content -LiteralPath (Join-Path $fixture 'packages/runner_core/lib/core.dart')
  Assert-CacheTest ((Get-ReleaseComponentInputs $fixture 'client-build') -ne $clientBefore -and (Get-ReleaseComponentInputs $fixture 'validator-checks') -ne $workerBefore) 'Core edits invalidate both client and validator evidence'
  $keyA = Get-ReleaseComponentKey $clientBefore 'sdk-a'
  Assert-CacheTest ($keyA -ne (Get-ReleaseComponentKey $clientBefore 'sdk-b')) 'SDK changes invalidate cached evidence'
  $input = Get-ReleaseComponentInputs $fixture 'functions-checks'
  'new backend test' | Set-Content -LiteralPath (Join-Path $fixture 'functions/test/profile.test.ts')
  $global:cacheFailTests = $true
  Assert-CacheThrows { Invoke-ReleasePreparation $fixture $cache @('functions-checks') $logs } 'failed (5)' 'failed validation is propagated'
  $input = Get-ReleaseComponentInputs $fixture 'functions-checks'
  $key = Get-ReleaseComponentKey $input (Get-ReleaseToolchain $fixture 'node')
  Assert-CacheTest (-not (Test-Path (Join-Path $cache "components/functions-checks/$key/component.json"))) 'failed validation never publishes success evidence'
  $global:cacheFailTests = $false
  $clientItem = @($items | Where-Object component -eq 'client-build')[0]
  'tampered' | Set-Content -LiteralPath (Join-Path $cache "components/client-build/$($clientItem.key)/artifact/main.dart.js")
  Assert-CacheThrows { Get-ReleaseCachedComponent $cache 'client-build' $clientItem.key } 'modified' 'tampered cached artifacts cannot be reused'

  $inputs = Get-ReleaseInputHashes $fixture 'test-project'
  $contract = [pscustomobject]@{ gameCompatVersion='v1'; rulesetVersion='rules-v2'; scoreVersion='score-v2'; ghostVersion='ghost-v1' }
  $baseline = [pscustomobject]@{ inputs=($inputs | ConvertTo-Json | ConvertFrom-Json); contract=$contract }
  Assert-CacheTest ((Resolve-ReleaseScope $inputs $contract $null) -eq 'Coordinated') 'first release requires coordinated deployment'
  Assert-CacheTest ((Resolve-ReleaseScope $inputs $contract $baseline) -eq 'None') 'unchanged runtime needs no deployment'
  $inputs.client = 'a' * 64
  Assert-CacheTest ((Resolve-ReleaseScope $inputs $contract $baseline) -eq 'Hosting') 'UI-only changes select Hosting'
  Assert-CacheThrows { Resolve-ReleaseScope $inputs $contract $baseline 'Backend' } 'cannot satisfy' 'an explicit narrow scope cannot bypass changed inputs'
  $inputs.client = $baseline.inputs.client; $inputs.functions = 'b' * 64
  Assert-CacheTest ((Resolve-ReleaseScope $inputs $contract $baseline) -eq 'Backend') 'profile-only changes select Backend'
  $inputs.simulation = 'd' * 64
  Assert-CacheThrows { Resolve-ReleaseScope $inputs $contract $baseline } 'gameCompatVersion' 'Core changes cannot reuse the deployed gameplay version'
  $nextContract = [pscustomobject]@{ gameCompatVersion='v2'; rulesetVersion='rules-v2'; scoreVersion='score-v2'; ghostVersion='ghost-v1' }
  Assert-CacheTest ((Resolve-ReleaseScope $inputs $nextContract $baseline) -eq 'Coordinated') 'gameplay changes with new tuple select coordinated cutover'
  $run = [pscustomobject]@{path='.github/workflows/release-preparation.yml';status='completed';conclusion='success';head_sha=('c'*40);event='push';head_repository=@{full_name='owner/repo'};repository=@{full_name='owner/repo'} }
  Assert-ReleaseCIRun $run 'owner/repo' ('c'*40)
  Assert-CacheTest $true 'exact successful repository CI run is accepted'
  $run.head_repository.full_name='fork/repo'
  Assert-CacheThrows { Assert-ReleaseCIRun $run 'owner/repo' ('c'*40) } 'trusted' 'fork CI artifacts are rejected'
  $run.head_repository.full_name='owner/repo'; $run.event='pull_request'
  Assert-CacheThrows { Assert-ReleaseCIRun $run 'owner/repo' ('c'*40) } 'trusted' 'PR CI artifacts are rejected for deployment'
  $run.event='push'; $run.conclusion='failure'
  Assert-CacheThrows { Assert-ReleaseCIRun $run 'owner/repo' ('c'*40) } 'trusted' 'failed CI runs cannot provide release evidence'
  $timings = @(Get-ReleaseTestTimings @((Join-Path $logs 'client-tests-0.jsonl')))
  Assert-CacheTest ($timings[0].milliseconds -eq 100 -and $timings[0].name -eq 'slow case') 'test profiling uses reported elapsed time'

  $downloads = Join-Path $fixture '.tmp/ci-downloads'
  foreach ($component in Get-ReleaseComponents 'Coordinated') {
    $input = Get-ReleaseComponentInputs $fixture $component
    $chain = Get-ReleaseToolchain $fixture (Get-ReleaseComponentFamily $component)
    $key = Get-ReleaseComponentKey $input $chain
    $fragments = if ($component -eq 'client-checks') { @(0..3 | ForEach-Object { "release-client-checks-$_" }) } else { @("release-$component") }
    foreach ($fragment in $fragments) {
      $partCache = Join-Path $downloads $fragment
      $artifact = switch ($component) { 'client-build' { Join-Path $fixture 'build/web' }; 'functions-build' { Join-Path $fixture 'functions/lib' }; default { '' } }
      Save-ReleaseCachedComponent $partCache $component $key $input $chain ('c'*40) '' $artifact
      if ($component -eq 'client-checks') {
        $path = Join-Path $partCache "components/$component/$key/component.json"
        $record = Get-Content -Raw $path | ConvertFrom-Json
        $record | Add-Member shardCount 4
        $record | Add-Member shardIndex ([int]($fragment -split '-')[-1])
        $record | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
        Assert-CacheThrows { Get-ReleaseCachedComponent $partCache $component $key } 'Partial' "client shard $($record.shardIndex) cannot count as full validation"
      }
    }
  }
  $global:cacheCIBundle = Join-Path $fixture '.tmp/ci-bundle'
  Merge-ReleaseCIBundle $downloads $global:cacheCIBundle ('c'*40) 123
  $manifest = Get-Content -Raw (Join-Path $global:cacheCIBundle 'bundle.json') | ConvertFrom-Json
  Assert-CacheTest ($manifest.components.Count -eq 10) 'CI bundle contains all ten components and complete client coverage'
  $global:cacheCIRun = [pscustomobject]@{path='.github/workflows/release-preparation.yml';status='completed';conclusion='success';head_sha=('c'*40);event='push';head_repository=@{full_name='owner/repo'};repository=@{full_name='owner/repo'} }
  $importCache = Join-Path $fixture '.tmp/imported-cache'
  Import-ReleaseCI $fixture $importCache 123
  $build = @($manifest.components | Where-Object component -eq 'client-build')[0]
  Restore-ReleaseArtifact $fixture $importCache 'client-build' $build.key
  Assert-CacheTest ((Get-ReleaseCachedComponent $importCache 'client-build' $build.key).passed) 'trusted bundle imports through a renamed origin and restores hashed artifacts'
  $clientFragments = @(Get-ChildItem (Join-Path $downloads 'release-client-checks-3') -Filter component.json -Recurse -File)
  $fragmentRecord = Get-Content -Raw $clientFragments[0].FullName | ConvertFrom-Json
  $fragmentRecord.shardIndex=2
  $fragmentRecord | ConvertTo-Json | Set-Content -LiteralPath $clientFragments[0].FullName -Encoding utf8
  Assert-CacheThrows { Merge-ReleaseCIBundle $downloads (Join-Path $fixture '.tmp/bad-bundle') ('c'*40) 123 } 'coverage' 'duplicate/missing CI client shard coverage blocks bundle publication'
  $global:cacheCIRun.head_sha='d'*40
  Assert-CacheThrows { Import-ReleaseCI $fixture $importCache 123 } 'trusted' 'CI import rejects evidence from another commit'
  Write-Host "$script:passed cache/scope/provenance checks passed; no SDK or cloud commands executed."
} finally {
  $resolved = (Resolve-Path $fixture).Path
  if (-not $resolved.StartsWith((Join-Path $workspace '.tmp/release-tests').TrimEnd('\') + '\')) { throw 'Unsafe fixture cleanup.' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
  Remove-Variable cacheTrace,cacheFailTests,cacheCIRun,cacheCIBundle -Scope Global -ErrorAction SilentlyContinue
}
