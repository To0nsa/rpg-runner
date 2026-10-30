Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReleaseImageDigest {
  param([object]$Build, [string]$ImageTag)
  if ($Build.status -ne 'SUCCESS') { throw "Cloud Build failed: $($Build.status)." }
  $images = @($Build.results.images | Where-Object { $_.name -eq $ImageTag })
  if ($images.Count -ne 1 -or $images[0].digest -notmatch '^sha256:[0-9a-f]{64}$') {
    throw 'Cloud Build did not report exactly one expected immutable image.'
  }
  $steps = if ($Build.PSObject.Properties.Name -contains 'steps') { @($Build.steps) } else { @() }
  $benchmarks = @($steps | Where-Object { $_.PSObject.Properties.Name -contains 'id' -and $_.id -eq 'benchmark-release-image' })
  $expected = @('run','--rm','--cpus=1','--memory=512m',$ImageTag,'benchmark','--ticks=36000','--strict')
  if ($benchmarks.Count -ne 1 -or $benchmarks[0].status -ne 'SUCCESS' -or
      $benchmarks[0].name -ne 'gcr.io/cloud-builders/docker' -or
      ($benchmarks[0].args -join "`n") -cne ($expected -join "`n")) {
    throw 'Cloud Build lacks the successful strict final-image benchmark.'
  }
  return $images[0].digest
}

function Get-ReleaseReusableImage {
  param([string]$Root, [string]$CacheRoot, [object]$Source, [string]$WorkerInputs)
  $path = Join-Path $CacheRoot "images/$($Source.projectId)/$($Source.region)/$WorkerInputs.json"
  if (-not (Test-Path -LiteralPath $path)) {
    throw 'No matching source image evidence. Finish BuildImage and ImageStatus in the source environment first.'
  }
  $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  $prefix = "$($Source.region)-docker.pkg.dev/$($Source.projectId)/replay/replay-validator"
  if ($record.workerInputs -ne $WorkerInputs -or
      $record.imageTag -notmatch "^$([regex]::Escape($prefix)):release-[a-zA-Z0-9-]+$" -or
      $record.imageUri -notmatch "^$([regex]::Escape($prefix))@sha256:[0-9a-f]{64}$") {
    throw 'Source image evidence does not match worker inputs or source environment.'
  }
  $build = Invoke-ReleaseCommand gcloud @('builds','describe',$record.buildId,
    "--project=$($Source.projectId)",'--region=global','--format=json') $Root | ConvertFrom-Json
  $digest = Get-ReleaseImageDigest $build $record.imageTag
  if ($record.imageUri -cne "$prefix@$digest") { throw 'Source image digest differs from live build evidence.' }
  return [pscustomobject]@{projectId=$Source.projectId;buildId=$record.buildId;
    workerInputs=$WorkerInputs;imageUri=$record.imageUri;digest=$digest}
}

function Get-ReleaseNavigationSeed {
  param([string]$Root, [string]$CacheRoot, [object]$Definition, [object]$Baseline)
  if ($null -eq $Baseline) { return $null }
  if ($Baseline.projectId -ne $Definition.projectId -or $Baseline.region -ne $Definition.region) {
    throw 'Navigation seed baseline belongs to another environment.'
  }
  # Worker code can change without changing graph keys. Reuse the previous
  # benchmarked pack; the current producer still validates exact keys/bytes and
  # regenerates only missing, changed or corrupt pieces for the current routes.
  $seed = Get-ReleaseReusableImage $Root $CacheRoot $Definition $Baseline.inputs.worker
  if ($seed.imageUri -cne $Baseline.workerImage) {
    throw 'Navigation seed differs from the verified deployment baseline.'
  }
  return $seed
}

function Write-ReleaseImageCopyConfig {
  param([string]$Path, [string]$SourceImage, [string]$TargetImage)
  # Copy immutable bytes into the destination registry; no source upload,
  # compilation or navigation generation. Keep its own final-image benchmark.
  [ordered]@{
    timeout='1800s'
    steps=@(
      @{name='gcr.io/cloud-builders/docker';args=@('pull',$SourceImage)}
      @{name='gcr.io/cloud-builders/docker';args=@('tag',$SourceImage,$TargetImage)}
      @{name='gcr.io/cloud-builders/docker';id='benchmark-release-image';
        args=@('run','--rm','--cpus=1','--memory=512m',$TargetImage,'benchmark','--ticks=36000','--strict')}
    )
    images=@($TargetImage)
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
}
