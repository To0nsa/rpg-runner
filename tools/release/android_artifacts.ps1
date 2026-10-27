# Native release evidence is independent of the cached web build. Inspect the
# delivered file, including resources and every prepared navigation graph.
function Get-AndroidSdkTools {
  param([string]$Root)
  $sdk = $env:ANDROID_HOME
  if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
  if (-not $sdk) {
    $properties = Get-Content -LiteralPath (Join-Path $Root 'android/local.properties')
    $sdk = (($properties | Where-Object { $_ -like 'sdk.dir=*' }) -replace '^sdk.dir=', '').Replace('\\', '\').Replace('\:', ':')
  }
  if (-not $sdk) { throw 'Set ANDROID_HOME to the installed Android SDK.' }
  $windows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  $binary = if ($windows) { '.exe' } else { '' }
  $script = if ($windows) { '.bat' } else { '' }
  $result = @{
    analyzer = Join-Path $sdk "cmdline-tools/latest/bin/apkanalyzer$script"
    signer = Join-Path $sdk "build-tools/36.0.0/apksigner$script"
    align = Join-Path $sdk "build-tools/36.0.0/zipalign$binary"
  }
  foreach ($path in $result.Values) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required Android SDK tool is missing: $path" }
  }
  return $result
}

function Get-AndroidBundletool {
  param([string]$Root)
  $directory = Join-Path (Get-ReleaseCommonRoot $Root) '.tmp/tools'
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $path = Join-Path $directory 'bundletool-all-1.18.3.jar'
  if (-not (Test-Path -LiteralPath $path)) {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar' -OutFile $path
  }
  if ((Get-FileHash -LiteralPath $path).Hash -ne 'A099CFA1543F55593BC2ED16A70A7C67FE54B1747BB7301F37FDFD6D91028E29') {
    throw 'Pinned bundletool download failed its SHA-256 check.'
  }
  return $path
}

function Get-AndroidStreamHash {
  param([IO.Stream]$Stream)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash($Stream)).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Assert-AndroidElfAlignment {
  param([byte[]]$Bytes, [string]$Name)
  # ELF64 program headers define PT_LOAD alignment. Only little-endian Android
  # arm64/x86_64 binaries reach this check; reject an unknown/truncated format.
  if ($Bytes.Length -lt 64 -or [BitConverter]::ToUInt32($Bytes, 0) -ne 0x464c457f -or
      $Bytes[4] -ne 2 -or $Bytes[5] -ne 1) { throw "Invalid ELF64 library: $Name" }
  $offset = [BitConverter]::ToUInt64($Bytes, 32)
  $size = [BitConverter]::ToUInt16($Bytes, 54)
  $count = [BitConverter]::ToUInt16($Bytes, 56)
  if ($size -lt 56 -or $count -eq 0 -or $offset -gt $Bytes.Length -or
      $count * $size -gt $Bytes.Length - $offset) { throw "Invalid ELF program headers: $Name" }
  $loads = 0
  for ($index = 0; $index -lt $count; $index++) {
    $position = [int]($offset + $index * $size)
    if ([BitConverter]::ToUInt32($Bytes, $position) -eq 1) {
      $loads++
      $alignment = [BitConverter]::ToUInt64($Bytes, $position + 48)
      if ($alignment -lt 16384 -or ($alignment -band ($alignment - 1)) -ne 0) {
        throw "Native library has insufficient 16 KB PT_LOAD alignment: $Name ($alignment)"
      }
    }
  }
  if ($loads -eq 0) { throw "ELF has no loadable segments: $Name" }
}

function Assert-AndroidArchive {
  param([string]$Root, [string]$Artifact, [switch]$Bundle)
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead($Artifact)
  $prefix = if ($Bundle) { 'base/' } else { '' }
  try {
    $names = @($zip.Entries.FullName)
    if (@($names | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count) { throw 'Duplicate archive paths.' }
    if (@($names | Where-Object { $_ -match '(^|/)(\.env[^/]*|[^/]*\.(jks|keystore|pem|p12))$|(^|/)key\.properties$' }).Count) {
      throw 'Unexpected credential file in Android artifact.'
    }
    $manifestPath = 'assets/navigation/manifest.json'
    $entry = $zip.GetEntry("${prefix}assets/flutter_assets/$manifestPath")
    if (-not $entry) { throw 'Android artifact is missing prepared navigation.' }
    $stream = $entry.Open()
    try { $manifestHash = Get-AndroidStreamHash $stream } finally { $stream.Dispose() }
    if ($manifestHash -ne (Get-FileHash -LiteralPath (Join-Path $Root $manifestPath)).Hash.ToLowerInvariant()) {
      throw 'Packaged navigation manifest differs from prepared source.'
    }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $Root $manifestPath) | ConvertFrom-Json
    $graphs = @($manifest.entries.PSObject.Properties)
    if ($graphs.Count -eq 0) { throw 'Prepared navigation manifest is empty.' }
    foreach ($graph in $graphs) {
      $entry = $zip.GetEntry("${prefix}assets/flutter_assets/assets/navigation/$($graph.Name).rng")
      if (-not $entry -or $entry.Length -ne $graph.Value[1]) { throw "Missing/truncated navigation graph: $($graph.Name)" }
      $stream = $entry.Open()
      try { $hash = Get-AndroidStreamHash $stream } finally { $stream.Dispose() }
      if ($hash -ne $graph.Value[0]) { throw "Corrupt navigation graph: $($graph.Name)" }
    }
    $abis = @(); $libraries = 0
    foreach ($entry in $zip.Entries) {
      if ($entry.FullName -notmatch '^(base/)?lib/([^/]+)/([^/]+\.so)$') { continue }
      $abi = $Matches[2]; $abis += $abi; $libraries++
      if ($abi -in @('arm64-v8a', 'x86_64')) {
        $stream = $entry.Open(); $memory = [IO.MemoryStream]::new()
        try { $stream.CopyTo($memory); Assert-AndroidElfAlignment $memory.ToArray() $entry.FullName }
        finally { $stream.Dispose(); $memory.Dispose() }
      }
    }
    foreach ($abi in @('armeabi-v7a', 'arm64-v8a', 'x86_64')) {
      foreach ($library in @('libapp.so', 'libflutter.so')) {
        if (-not $zip.GetEntry("${prefix}lib/$abi/$library")) { throw "Required Flutter ABI/library absent: $abi/$library" }
      }
    }
    return [pscustomobject]@{ navigationManifestSha256=$manifestHash; navigationGraphs=$graphs.Count;
      abis=@($abis | Sort-Object -Unique); nativeLibraries=$libraries; elf64PageAlignment=16384 }
  } finally { $zip.Dispose() }
}

function Assert-AndroidManifest {
  param([xml]$Manifest, [object]$Definition, [int]$VersionCode)
  $ns = 'http://schemas.android.com/apk/res/android'
  if ($Manifest.manifest.package -ne $Definition.androidPackage -or
      $Manifest.manifest.GetAttribute('versionCode', $ns) -ne "$VersionCode") { throw 'Android package/version does not match release selection.' }
  $sdk = $Manifest.manifest.'uses-sdk'
  if ([int]$sdk.GetAttribute('targetSdkVersion', $ns) -lt 36) { throw 'Android target SDK is below Play API 36 requirement.' }
  $application = $Manifest.SelectSingleNode('/manifest/application')
  if (-not $application) { throw 'Android manifest has no application.' }
  if ($application.GetAttribute('debuggable', $ns) -eq 'true' -or
      $application.GetAttribute('testOnly', $ns) -eq 'true') { throw 'Debug/test-only Android artifact cannot be released.' }
  return [pscustomobject]@{package=$Manifest.manifest.package;versionCode=$VersionCode;
    versionName=$Manifest.manifest.GetAttribute('versionName', $ns);
    minSdk=[int]$sdk.GetAttribute('minSdkVersion', $ns);targetSdk=[int]$sdk.GetAttribute('targetSdkVersion', $ns);
    permissions=@($Manifest.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $ns) })}
}

function Test-AndroidArtifact {
  param([string]$Root, [object]$Definition, [string]$Environment, [string]$Artifact,
    [int]$VersionCode, [string]$EvidenceDirectory, [string]$ExpectedCertificate = '')
  $sdk = Get-AndroidSdkTools $Root
  $bundle = [IO.Path]::GetExtension($Artifact) -eq '.aab'
  $archive = Assert-AndroidArchive $Root $Artifact -Bundle:$bundle
  $apk = $Artifact
  $savedDebug = $env:DEBUG
  try {
    $env:DEBUG = ''
    if ($bundle) {
      $bundletool = Get-AndroidBundletool $Root
      Invoke-ReleaseCommand java @('-jar',$bundletool,'validate',"--bundle=$Artifact") $Root | Out-Null
      $config = Invoke-ReleaseCommand java @('-jar',$bundletool,'dump','config',"--bundle=$Artifact") $Root
      if ($config -notmatch 'PAGE_ALIGNMENT_16K') { throw 'Bundle does not request 16 KB APK page alignment.' }
      $verification = Invoke-ReleaseCommand jarsigner @('-J-Duser.language=en','-verify',$Artifact) $Root
      if ($verification -notmatch 'jar verified\.' -or $verification -match 'unsigned entries') { throw 'Bundle signature does not cover the artifact.' }
      $certificate = Invoke-ReleaseCommand keytool @('-printcert','-rfc','-jarfile',$Artifact) $Root
      $matches = [regex]::Matches($certificate, '-----BEGIN CERTIFICATE-----\s*([\s\S]+?)\s*-----END CERTIFICATE-----')
      if ($matches.Count -ne 1) { throw 'Expected exactly one upload-signing certificate.' }
      $stream = [IO.MemoryStream]::new([Convert]::FromBase64String($matches[0].Groups[1].Value))
      try { $certificateHash = Get-AndroidStreamHash $stream } finally { $stream.Dispose() }
      if (-not $ExpectedCertificate -or $certificateHash -ne $ExpectedCertificate.ToLowerInvariant()) { throw 'Bundle upload certificate differs from selected project key.' }
      # This inspection-only universal APK uses bundletool's debug signature.
      # Deliver/promote the original signed AAB, never this derived APK.
      $apks = Join-Path $EvidenceDirectory 'inspection.apks'
      Invoke-ReleaseCommand java @('-jar',$bundletool,'build-apks',"--bundle=$Artifact","--output=$apks",'--mode=universal','--overwrite') $Root | Out-Null
      $zip = [IO.Compression.ZipFile]::OpenRead($apks)
      $apk = Join-Path $EvidenceDirectory 'inspection.apk'
      try { [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('universal.apk'), $apk, $true) }
      finally { $zip.Dispose() }
    } else {
      $signature = Invoke-ReleaseCommand $sdk.signer @('verify','--print-certs',$apk) $Root
      $certificateHash = [regex]::Match($signature, 'certificate SHA-256 digest:\s*([a-fA-F0-9]{64})').Groups[1].Value
      if (-not $certificateHash) { throw 'APK signature verification returned no certificate.' }
    }
    Invoke-ReleaseCommand $sdk.align @('-c','-P','16','4',$apk) $Root | Out-Null
    $xml = Invoke-ReleaseCommand $sdk.analyzer @('manifest','print',$apk) $Root
    $manifest = Assert-AndroidManifest ([xml]$xml) $Definition $VersionCode
    $xml | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'AndroidManifest.xml') -Encoding utf8
    $config = Get-Content -Raw -LiteralPath (Join-Path $Root "android/app/src/$Environment/google-services.json") | ConvertFrom-Json
    $clients = @($config.client | Where-Object { $_.client_info.android_client_info.package_name -eq $Definition.androidPackage })
    if ($config.project_info.project_id -ne $Definition.projectId -or $clients.Count -ne 1) { throw 'Firebase source configuration differs from environment.' }
    $strings = [xml](Get-Content -Raw -LiteralPath (Join-Path $Root "android/app/src/$Environment/res/values/strings.xml"))
    $server = @($strings.resources.string | Where-Object { $_.name -eq 'play_games_server_client_id' })
    if ($server.Count -ne 1 -or $server[0].InnerText -notmatch '^\d+-[a-z0-9]+\.apps\.googleusercontent\.com$') { throw 'Play Games server OAuth client is not configured.' }
    $resources = [ordered]@{project_id=$Definition.projectId;google_app_id=$clients[0].client_info.mobilesdk_app_id;
      gcm_defaultSenderId=$config.project_info.project_number;game_services_project_id=$config.project_info.project_number;
      play_games_server_client_id=$server[0].InnerText}
    if (-not $server[0].InnerText.StartsWith("$($config.project_info.project_number)-")) { throw 'Play Games server client belongs to another project.' }
    foreach ($name in $resources.Keys) {
      $actual = Invoke-ReleaseCommand $sdk.analyzer @('resources','value','--config','default','--type','string','--name',$name,$apk) $Root
      if ($actual.Trim('"') -ne $resources[$name]) { throw "Packaged Android resource mismatch: $name" }
    }
    return [pscustomobject]@{manifest=$manifest;resources=$resources;archive=$archive;
      certificateSha256=$certificateHash;sha256=(Get-FileHash -LiteralPath $Artifact).Hash.ToLowerInvariant();
      sizeBytes=(Get-Item -LiteralPath $Artifact).Length;bundle=$bundle}
  } finally { $env:DEBUG = $savedDebug }
}

function Invoke-AndroidReleaseBuild {
  param([string]$Root, [object]$Definition, [string]$Environment, [int]$VersionCode,
    [string]$EvidenceDirectory, [object]$Contract, [string]$SourceDigest)
  if ($VersionCode -le 0) { throw 'BuildAndroid requires a positive -AndroidVersionCode allocated from Play history.' }
  $dirty = Invoke-ReleaseCommand git @('status','--porcelain','--untracked-files=normal') $Root
  if ($dirty) { throw 'BuildAndroid requires a clean frozen checkout. Commit the candidate and use Checkout first.' }
  $commit = Invoke-ReleaseCommand git @('rev-parse','HEAD') $Root
  $inputDigest = Get-ReleaseComponentInputs $Root 'android-build'
  $directory = Join-Path $EvidenceDirectory "android/$Environment/$VersionCode"
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $recordPath = Join-Path $directory 'android.json'
  if (Test-Path -LiteralPath $recordPath) { throw 'This version already has Android evidence. Reuse the recorded artifact or allocate a new version; do not overwrite it.' }
  $savedDebug = $env:DEBUG
  try {
    $env:DEBUG = ''
    $gradle = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'android/gradlew.bat' } else { 'android/gradlew' }
    $toolchain = [ordered]@{flutter=(Get-ReleaseToolchain $Root 'flutter');java=(Invoke-ReleaseCommand java @('--version') $Root);
      gradle=(Invoke-ReleaseCommand (Join-Path $Root $gradle) @('--version') (Join-Path $Root 'android'));buildTools='36.0.0'}
    $type = if ($Environment -eq 'dev') { 'apk' } else { 'appbundle' }
    # Cached Prepare restores the web artifact, not ignored source-side graphs.
    # Materialize Android inputs even in a fresh checkout with all cache hits.
    $preparationLog = Join-Path $directory 'preparation.log'
    Invoke-ReleaseCommand flutter @('pub','get','--enforce-lockfile') $Root $preparationLog | Out-Null
    Invoke-ReleaseCommand dart @('run','packages/runner_core/tool/prepare_navigation.dart','--client') $Root $preparationLog | Out-Null
    $certificate = if ($Environment -eq 'dev') { '' } else { (Read-AndroidSigningPayload $Root $Definition $Environment).certificateSha256 }
    Invoke-WithAndroidUploadSigning $Root $Definition $Environment {
      # Flutter 3.47 skips release-mode plugin regeneration with --no-pub;
      # that can retain test-only plugins in GeneratedPluginRegistrant.java.
      # Prepare resolved the lockfile, and the post-build source check rejects drift.
      Invoke-ReleaseCommand flutter @('build',$type,'--flavor',$Environment,'--release',"--build-number=$VersionCode",
        "--split-debug-info=$directory/symbols") $Root (Join-Path $directory 'build.log') | Out-Null
    }
    $built = if ($type -eq 'apk') { "build/app/outputs/flutter-apk/app-$Environment-release.apk" } else { "build/app/outputs/bundle/${Environment}Release/app-$Environment-release.aab" }
    $artifact = Join-Path $directory ([IO.Path]::GetFileName($built))
    Copy-Item -LiteralPath (Join-Path $Root $built) -Destination $artifact
    $inspection = Test-AndroidArtifact $Root $Definition $Environment $artifact $VersionCode $directory $certificate
    if ((Get-ReleaseSourceDigest $Root $Definition.projectId) -ne $SourceDigest -or
        (Get-ReleaseComponentInputs $Root 'android-build') -ne $inputDigest) { throw 'Source changed during Android build; artifact is not release evidence.' }
    if (@(Get-ChildItem -LiteralPath (Join-Path $directory 'symbols') -Filter '*.symbols').Count -lt 3) { throw 'Missing release Dart symbols.' }
    if ($Environment -ne 'dev') {
      Invoke-ReleaseCommand corepack @('pnpm','--dir','functions','exec','firebase','crashlytics:symbols:upload',
        "--project=$($Definition.projectId)","--app=$($inspection.resources.google_app_id)",(Join-Path $directory 'symbols')) $Root (Join-Path $directory 'symbols-upload.log') | Out-Null
    }
    $mapping = Join-Path $Root "build/app/outputs/mapping/${Environment}Release/mapping.txt"
    if (Test-Path -LiteralPath $mapping) { Copy-Item -LiteralPath $mapping -Destination (Join-Path $directory 'mapping.txt') }
    [ordered]@{schemaVersion=1;environment=$Environment;projectId=$Definition.projectId;sourceCommit=$commit;
      sourceDigest=$SourceDigest;inputDigest=$inputDigest;contract=$Contract;toolchain=$toolchain;
      artifact=[IO.Path]::GetFileName($artifact);inspection=$inspection;symbolsUploaded=($Environment -ne 'dev');completedAt=[DateTime]::UtcNow.ToString('o')} |
      ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding utf8
    Write-Host "Android artifact verified: $recordPath"
  } finally { $env:DEBUG = $savedDebug }
}
