. (Join-Path $PSScriptRoot 'release_image.ps1')
$script:imagePassed = 0
function Assert-ImageTest {
  param([bool]$Value, [string]$Name)
  if (-not $Value) { throw "FAIL: $Name" }
  $script:imagePassed++; Write-Host "PASS: $Name"
}
function Assert-ImageThrows {
  param([scriptblock]$Operation, [string]$Pattern)
  $caught = $null
  try { & $Operation | Out-Null } catch { $caught = $_ }
  Assert-ImageTest ($null -ne $caught -and $caught.Exception.Message -like "*$Pattern*") $Pattern
}
$imageWorkspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$imageFixture = Join-Path $imageWorkspace ".tmp/release-tests/$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $imageFixture | Out-Null
try {
  $imageTag = 'europe-west1-docker.pkg.dev/test-project/replay/replay-validator:release-candidate'
  $digest = "sha256:$('a' * 64)"
  $build = [pscustomobject]@{status='SUCCESS';results=[pscustomobject]@{images=@([pscustomobject]@{name=$imageTag;digest=$digest})};
    steps=@([pscustomobject]@{name='gcr.io/cloud-builders/docker'},
      [pscustomobject]@{id='benchmark-release-image';status='SUCCESS';name='gcr.io/cloud-builders/docker';
        args=@('run','--rm','--cpus=1','--memory=512m',$imageTag,'benchmark','--ticks=36000','--strict')})}
  Assert-ImageTest ((Get-ReleaseImageDigest $build $imageTag) -eq $digest) 'successful exact-image benchmark supplies digest'
  $build.status = 'FAILURE'
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'Cloud Build failed'
  $build.status = 'SUCCESS'
  Assert-ImageThrows { Get-ReleaseImageDigest $build "$imageTag-other" } 'expected immutable image'
  $benchmark = $build.steps[1]
  $benchmark.status = 'FAILURE'
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'strict final-image benchmark'
  $benchmark.status = 'SUCCESS'
  $benchmark.args[3] = '--memory=1g'
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'strict final-image benchmark'
  $benchmark.args[3] = '--memory=512m'
  $benchmark.args[4] = 'another-image'
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'strict final-image benchmark'
  $benchmark.args[4] = $imageTag
  $benchmark.args[6] = '--ticks=3600'
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'strict final-image benchmark'
  $benchmark.args[6] = '--ticks=36000'
  # Missing/duplicate benchmark records cannot borrow a successful build status.
  $build.steps = @()
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'strict final-image benchmark'
  $build.steps = @($benchmark,$benchmark)
  Assert-ImageThrows { Get-ReleaseImageDigest $build $imageTag } 'strict final-image benchmark'
  $build.steps = @($benchmark)
  $source = [pscustomobject]@{projectId='test-project';region='europe-west1'}
  $recordPath = Join-Path $imageFixture 'images/test-project/europe-west1/inputs.json'
  $sourceUri = $imageTag.Split(':')[0] + "@$digest"
  Assert-ImageThrows { Get-ReleaseReusableImage $imageFixture $imageFixture $source 'inputs' } 'No matching source image evidence'
  New-Item -ItemType Directory -Force -Path (Split-Path $recordPath) | Out-Null
  $record = @{workerInputs='different';buildId='source-build';imageTag=$imageTag;imageUri=$sourceUri}
  $record | ConvertTo-Json | Set-Content $recordPath
  Assert-ImageThrows { Get-ReleaseReusableImage $imageFixture $imageFixture $source 'inputs' } 'does not match worker inputs'
  $record.workerInputs = 'inputs'
  $record.imageUri = $sourceUri.Replace('test-project','foreign-project')
  $record | ConvertTo-Json | Set-Content $recordPath
  Assert-ImageThrows { Get-ReleaseReusableImage $imageFixture $imageFixture $source 'inputs' } 'source environment'
  $record.imageUri = $sourceUri
  $record | ConvertTo-Json | Set-Content $recordPath
  $seedBaseline = [pscustomobject]@{projectId='test-project';region='europe-west1';
    workerImage=$sourceUri;inputs=[pscustomobject]@{worker='inputs'}}
  Assert-ImageTest ($null -eq (Get-ReleaseNavigationSeed $imageFixture $imageFixture $source $null)) 'first deployment has no navigation seed'
  $seedBaseline.projectId = 'other-project'
  Assert-ImageThrows { Get-ReleaseNavigationSeed $imageFixture $imageFixture $source $seedBaseline } 'another environment'
  $seedBaseline.projectId = 'test-project'
  & {
    function Invoke-ReleaseCommand {
      param($Command,$CommandArgs,$WorkingDirectory)
      if ($Command -ne 'gcloud' -or $CommandArgs -notcontains '--project=test-project' -or
          $CommandArgs -notcontains 'source-build') { throw 'Wrong source cloud request' }
      return $build | ConvertTo-Json -Depth 10
    }
    $result = Get-ReleaseReusableImage $imageFixture $imageFixture $source 'inputs'
    Assert-ImageTest ($result.imageUri -eq $sourceUri -and $result.digest -eq $digest) 'source fingerprint and live immutable build agree'
    $seed = Get-ReleaseNavigationSeed $imageFixture $imageFixture $source $seedBaseline
    Assert-ImageTest ($seed.imageUri -eq $sourceUri -and $seed.workerInputs -eq 'inputs') 'navigation seed uses previous verified worker independently of new worker inputs'
    $seedBaseline.workerImage = $sourceUri.Replace(('a' * 64), ('b' * 64))
    Assert-ImageThrows { Get-ReleaseNavigationSeed $imageFixture $imageFixture $source $seedBaseline } 'differs from the verified deployment baseline'
    $seedBaseline.workerImage = $sourceUri
    $build.steps[0].status = 'FAILURE'
    Assert-ImageThrows { Get-ReleaseNavigationSeed $imageFixture $imageFixture $source $seedBaseline } 'strict final-image benchmark'
    $build.steps[0].status = 'SUCCESS'
    $build.results.images[0].digest = "sha256:$('b' * 64)"
    Assert-ImageThrows { Get-ReleaseReusableImage $imageFixture $imageFixture $source 'inputs' } 'differs from live build evidence'
  }
  $seedBaseline.inputs.worker = 'missing'
  Assert-ImageThrows { Get-ReleaseNavigationSeed $imageFixture $imageFixture $source $seedBaseline } 'No matching source image evidence'
  $configPath = Join-Path $imageFixture 'copy.json'
  Write-ReleaseImageCopyConfig $configPath $sourceUri 'destination-image'
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
  Assert-ImageTest ($config.steps.Count -eq 3 -and $config.steps[0].args[0] -eq 'pull' -and
    $config.steps[0].args[1] -eq $sourceUri -and $config.steps[1].args[0] -eq 'tag' -and
    $config.images[0] -eq 'destination-image') 'copy recipe preserves immutable source and avoids compilation'
  $build.results.images[0].name = 'destination-image'
  $build.steps = @($config.steps[2] | Select-Object *, @{Name='status';Expression={'SUCCESS'}})
  Assert-ImageTest ((Get-ReleaseImageDigest $build 'destination-image') -eq "sha256:$('b' * 64)") 'copied image keeps strict benchmark limits'
  Write-Host "$script:imagePassed image reuse checks passed; mocked cloud evidence only."
} finally {
  $allowed = [IO.Path]::GetFullPath((Join-Path $imageWorkspace '.tmp/release-tests')).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  if (-not [IO.Path]::GetFullPath($imageFixture).StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path' }
  Remove-Item -LiteralPath $imageFixture -Recurse -Force
}
