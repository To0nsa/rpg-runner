. (Join-Path $PSScriptRoot 'release_support.ps1')
. (Join-Path $PSScriptRoot 'release_cache.ps1')
. (Join-Path $PSScriptRoot 'release_environments.ps1')
. (Join-Path $PSScriptRoot 'android_artifacts.ps1')
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixture = Join-Path $workspace ".tmp/release-tests/android-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$script:passed = 0
function Assert-AndroidTest {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  $script:passed++; Write-Host "PASS: $Message"
}
function Assert-AndroidThrows {
  param([scriptblock]$Operation, [string]$Pattern)
  $caught = $null
  try { & $Operation | Out-Null } catch { $caught = $_ }
  Assert-AndroidTest ($caught -and $caught.Exception.Message -like "*$Pattern*") $Pattern
}
try {
  $definition = Get-ReleaseEnvironmentDefinition $workspace dev
  [xml]$manifest = '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example.rpg_runner.dev" android:versionCode="12" android:versionName="1.0-dev"><uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/><uses-permission android:name="android.permission.INTERNET"/><application/></manifest>'
  $result = Assert-AndroidManifest $manifest $definition 12
  Assert-AndroidTest ($result.targetSdk -eq 36 -and $result.permissions.Count -eq 1) 'native identity and permissions read from manifest'
  Assert-AndroidThrows { Assert-AndroidManifest $manifest (Get-ReleaseEnvironmentDefinition $workspace prod) 12 } 'package/version'
  Assert-AndroidThrows { Assert-AndroidManifest $manifest $definition 13 } 'package/version'
  $ns = 'http://schemas.android.com/apk/res/android'
  $manifest.manifest.'uses-sdk'.SetAttribute('targetSdkVersion', $ns, '35') | Out-Null
  Assert-AndroidThrows { Assert-AndroidManifest $manifest $definition 12 } 'target SDK'
  $manifest.manifest.'uses-sdk'.SetAttribute('targetSdkVersion', $ns, '36') | Out-Null
  $manifest.SelectSingleNode('/manifest/application').SetAttribute('debuggable', $ns, 'true') | Out-Null
  Assert-AndroidThrows { Assert-AndroidManifest $manifest $definition 12 } 'Debug/test-only'
  $elf = New-Object byte[] 120
  [BitConverter]::GetBytes([uint32]0x464c457f).CopyTo($elf,0); $elf[4]=2; $elf[5]=1
  [BitConverter]::GetBytes([uint64]64).CopyTo($elf,32)
  [BitConverter]::GetBytes([uint16]56).CopyTo($elf,54)
  [BitConverter]::GetBytes([uint16]1).CopyTo($elf,56)
  [BitConverter]::GetBytes([uint32]1).CopyTo($elf,64)
  [BitConverter]::GetBytes([uint64]16384).CopyTo($elf,112)
  Assert-AndroidElfAlignment $elf fixture.so
  Assert-AndroidTest $true 'ELF64 16 KB load segments accepted'
  [BitConverter]::GetBytes([uint64]4096).CopyTo($elf,112)
  Assert-AndroidThrows { Assert-AndroidElfAlignment $elf fixture.so } 'insufficient 16 KB'
  [BitConverter]::GetBytes([uint64]32768).CopyTo($elf,112)
  [BitConverter]::GetBytes([uint16]2).CopyTo($elf,56)
  Assert-AndroidThrows { Assert-AndroidElfAlignment $elf fixture.so } 'Invalid ELF program headers'
  [BitConverter]::GetBytes([uint16]1).CopyTo($elf,56)
  $source = Join-Path $fixture 'archive'
  New-Item -ItemType Directory -Force -Path (Join-Path $source 'assets/flutter_assets/assets/navigation') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'assets/navigation') | Out-Null
  $graph = [Text.Encoding]::UTF8.GetBytes('navigation graph fixture')
  $stream = [IO.MemoryStream]::new($graph)
  try { $hash = Get-AndroidStreamHash $stream } finally { $stream.Dispose() }
  $json = @{version=1;entries=@{fixture=@($hash,$graph.Length)}} | ConvertTo-Json -Depth 4 -Compress
  [IO.File]::WriteAllText((Join-Path $fixture 'assets/navigation/manifest.json'),$json)
  [IO.File]::WriteAllText((Join-Path $source 'assets/flutter_assets/assets/navigation/manifest.json'),$json)
  [IO.File]::WriteAllBytes((Join-Path $source 'assets/flutter_assets/assets/navigation/fixture.rng'),$graph)
  foreach ($abi in @('armeabi-v7a','arm64-v8a','x86_64')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $source "lib/$abi") | Out-Null
    foreach ($name in @('libapp.so','libflutter.so')) { [IO.File]::WriteAllBytes((Join-Path $source "lib/$abi/$name"),$elf) }
  }
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $artifact = Join-Path $fixture 'fixture.apk'
  $zip = [IO.Compression.ZipFile]::Open($artifact,[IO.Compression.ZipArchiveMode]::Create)
  try {
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
      $name = $file.FullName.Substring($source.Length+1).Replace('\','/')
      [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$name) | Out-Null
    }
  } finally { $zip.Dispose() }
  $result = Assert-AndroidArchive $fixture $artifact
  Assert-AndroidTest ($result.navigationGraphs -eq 1 -and $result.nativeLibraries -eq 6) 'all navigation bytes and Flutter native ABIs inspected'
  $zip = [IO.Compression.ZipFile]::Open($artifact,[IO.Compression.ZipArchiveMode]::Update)
  try { $zip.GetEntry('assets/flutter_assets/assets/navigation/fixture.rng').Delete() } finally { $zip.Dispose() }
  Assert-AndroidThrows { Assert-AndroidArchive $fixture $artifact } 'Missing/truncated navigation'
  $zip = [IO.Compression.ZipFile]::Open($artifact,[IO.Compression.ZipArchiveMode]::Update)
  try { $zip.CreateEntry('upload.jks') | Out-Null } finally { $zip.Dispose() }
  Assert-AndroidThrows { Assert-AndroidArchive $fixture $artifact } 'credential file'
  Write-Host "$script:passed Android artifact checks passed; synthetic artifacts only."
} finally {
  $allowed = [IO.Path]::GetFullPath((Join-Path $workspace '.tmp/release-tests')).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  $resolved = [IO.Path]::GetFullPath($fixture)
  if (-not $resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
