# Upload keys are separate from Google Play's distribution signing keys.
# Secret payloads stay in memory; the workstation recovery copy uses Windows DPAPI.
function Get-AndroidSigningDirectory {
  param([string]$Root, [string]$Environment)
  if ($Environment -notin @('staging','prod')) { throw 'Upload signing requires staging or prod.' }
  $commonRoot = [IO.Path]::GetFullPath((Get-ReleaseCommonRoot $Root))
  $location = if ($env:LOTHRINGEN_SECRETS_DIR) { $env:LOTHRINGEN_SECRETS_DIR }
    else { Join-Path (Split-Path $commonRoot -Parent) 'lothringen-secrets' }
  if (-not [IO.Path]::IsPathRooted($location)) { throw 'LOTHRINGEN_SECRETS_DIR must be an absolute directory outside the repository.' }
  $directory = [IO.Path]::GetFullPath($location).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  foreach ($checkout in @($commonRoot, [IO.Path]::GetFullPath($Root))) {
    $boundary = $checkout.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ($directory.Equals($boundary, [StringComparison]::OrdinalIgnoreCase) -or
        $directory.StartsWith(($boundary + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Local signing secrets must remain outside the repository and release checkout.'
    }
  }
  return Join-Path $directory $Environment
}

function Assert-AndroidSigningPayload {
  param([object]$Payload, [object]$Definition, [string]$Environment)
  if ($Payload.schemaVersion -ne 1 -or $Payload.projectId -ne $Definition.projectId -or
      $Payload.environment -ne $Environment -or $Payload.keyAlias -ne 'upload' -or
      -not $Payload.password -or -not $Payload.keystoreBase64 -or
      $Payload.keystoreSha256 -notmatch '^[A-F0-9]{64}$') {
    throw 'Upload-signing payload does not match the selected environment.'
  }
  $bytes = [Convert]::FromBase64String($Payload.keystoreBase64)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $digest = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
  finally { $sha.Dispose() }
  if ($digest -ne $Payload.keystoreSha256) { throw 'Upload keystore integrity check failed.' }
}

function Read-AndroidSigningPayload {
  param([string]$Root, [object]$Definition, [string]$Environment)
  try {
    $json = Invoke-ReleaseCommand gcloud @('secrets','versions','access','latest',
      '--secret=android-upload-signing',"--project=$($Definition.projectId)", '--quiet') $Root
    $payload = $json | ConvertFrom-Json
    Assert-AndroidSigningPayload $payload $Definition $Environment
    return $payload
  } catch { throw 'Cannot load verified upload signing from the selected project Secret Manager.' }
  finally { $json = $null }
}

function Initialize-AndroidUploadSigning {
  param([string]$Root, [object]$Definition, [string]$Environment)
  if ($Environment -notin @('staging','prod')) { throw 'Dev retains its existing debug signing identity.' }
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Initial upload-key creation requires the Windows operator DPAPI recovery store.'
  }
  $project = $Definition.projectId
  $secrets = Invoke-ReleaseCommand gcloud @('secrets','list',"--project=$project",'--format=json') $Root | ConvertFrom-Json
  $exists = @($secrets | Where-Object { $_ -and ($_.name -split '/')[-1] -eq 'android-upload-signing' }).Count -gt 0
  $versions = if ($exists) {
    Invoke-ReleaseCommand gcloud @('secrets','versions','list','android-upload-signing',"--project=$project",'--format=json') $Root | ConvertFrom-Json
  } else { @() }
  if (@($versions | Where-Object { $_ -and $_.state -eq 'ENABLED' }).Count -gt 0) {
    $payload = Read-AndroidSigningPayload $Root $Definition $Environment
  } else {
    $directory = Get-AndroidSigningDirectory $Root $Environment
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $backup = Join-Path $directory 'upload-signing.dpapi'
    $keystore = Join-Path $directory 'upload.jks'
    $certificate = Join-Path $directory 'upload.der'
    $savedPassword = $env:LOTHRINGEN_UPLOAD_KEY_PASSWORD
    try {
      if (Test-Path -LiteralPath $backup) {
        $secure = ConvertTo-SecureString (Get-Content -Raw -LiteralPath $backup).Trim()
        $json = [Net.NetworkCredential]::new('', $secure).Password
        $payload = $json | ConvertFrom-Json
        Assert-AndroidSigningPayload $payload $Definition $Environment
      } else {
        if (Test-Path -LiteralPath $keystore) { throw 'An unfinished upload key exists; recover it rather than replacing it.' }
        $random = New-Object byte[] 32
        $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $generator.GetBytes($random) } finally { $generator.Dispose() }
        $env:LOTHRINGEN_UPLOAD_KEY_PASSWORD = [Convert]::ToBase64String($random)
        Invoke-ReleaseCommand keytool @('-genkeypair','-keystore',$keystore,'-storetype','JKS',
          '-alias','upload','-keyalg','RSA','-keysize','4096','-validity','10000',
          '-dname',"CN=Lothringen Long Run $Environment Upload, O=Lothringen, C=FI",
          '-storepass:env','LOTHRINGEN_UPLOAD_KEY_PASSWORD',
          '-keypass:env','LOTHRINGEN_UPLOAD_KEY_PASSWORD','-noprompt') $Root | Out-Null
        $payload = [pscustomobject][ordered]@{schemaVersion=1;environment=$Environment;projectId=$project;keyAlias='upload';
          password=$env:LOTHRINGEN_UPLOAD_KEY_PASSWORD;
          keystoreBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore));
          keystoreSha256=(Get-FileHash -LiteralPath $keystore -Algorithm SHA256).Hash;
          certificateSha1='';certificateSha256=''}
        $json = $payload | ConvertTo-Json -Compress
        ConvertTo-SecureString $json -AsPlainText -Force | ConvertFrom-SecureString |
          Set-Content -LiteralPath $backup -Encoding ascii
      }
      # Recreate from the protected copy on retry, including a previous failure
      # between key creation and certificate export or cloud backup.
      [IO.File]::WriteAllBytes($keystore, [Convert]::FromBase64String($payload.keystoreBase64))
      $env:LOTHRINGEN_UPLOAD_KEY_PASSWORD = $payload.password
      Invoke-ReleaseCommand keytool @('-exportcert','-keystore',$keystore,'-alias','upload',
        '-storepass:env','LOTHRINGEN_UPLOAD_KEY_PASSWORD','-file',$certificate) $Root | Out-Null
      $payload.certificateSha1 = (Get-FileHash -LiteralPath $certificate -Algorithm SHA1).Hash
      $payload.certificateSha256 = (Get-FileHash -LiteralPath $certificate -Algorithm SHA256).Hash
      $json = $payload | ConvertTo-Json -Compress
      ConvertTo-SecureString $json -AsPlainText -Force | ConvertFrom-SecureString |
        Set-Content -LiteralPath $backup -Encoding ascii
      if (-not $exists) {
        Invoke-ReleaseCommand gcloud @('secrets','create','android-upload-signing',
          "--project=$project",'--replication-policy=automatic','--quiet') $Root | Out-Null
      }
      # stdin avoids both a plaintext JSON file and passwords in process arguments.
      $json | & gcloud secrets versions add android-upload-signing "--project=$project" --data-file=- --quiet 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) { throw 'Upload-key backup failed; the DPAPI recovery copy is retained.' }
      $restored = Read-AndroidSigningPayload $Root $Definition $Environment
      if ($restored.keystoreSha256 -ne $payload.keystoreSha256) { throw 'Cloud upload-key readback mismatch.' }
    } catch {
      throw 'Upload signing initialization failed. Inspect selected-project access and the protected local recovery copy; no existing key was rotated.'
    } finally {
      $env:LOTHRINGEN_UPLOAD_KEY_PASSWORD = $savedPassword
      $json = $null; $secure = $null; $restored = $null
      # Delete the temporary keystore only after its protected recovery copy exists.
      if ((Test-Path -LiteralPath $backup) -and (Test-Path -LiteralPath $keystore)) {
        Remove-Item -LiteralPath $keystore -Force
      }
    }
  }
  [pscustomobject]@{environment=$Environment;projectId=$project;secret='android-upload-signing';
    certificateSha1=$payload.certificateSha1;certificateSha256=$payload.certificateSha256;
    kind='upload certificate; Google Play distribution certificate is separate'} | ConvertTo-Json
  $payload = $null
}

function Invoke-WithAndroidUploadSigning {
  param([string]$Root, [object]$Definition, [string]$Environment, [scriptblock]$Build)
  if ($Environment -eq 'dev') { & $Build; return }
  $directory = Get-AndroidSigningDirectory $Root $Environment
  $payload = Read-AndroidSigningPayload $Root $Definition $Environment
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $keystore = Join-Path $directory "$([guid]::NewGuid().ToString('N')).jks"
  $prefix = "LOTHRINGEN_$($Environment.ToUpperInvariant())_"
  $values = @{KEYSTORE=$keystore;STORE_PASSWORD=$payload.password;KEY_ALIAS=$payload.keyAlias;KEY_PASSWORD=$payload.password}
  $saved = @{}
  try {
    [IO.File]::WriteAllBytes($keystore, [Convert]::FromBase64String($payload.keystoreBase64))
    foreach ($suffix in $values.Keys) {
      $saved[$suffix] = [Environment]::GetEnvironmentVariable("$prefix$suffix", 'Process')
      [Environment]::SetEnvironmentVariable("$prefix$suffix", $values[$suffix], 'Process')
    }
    & $Build
  } finally {
    foreach ($suffix in $saved.Keys) {
      [Environment]::SetEnvironmentVariable("$prefix$suffix", $saved[$suffix], 'Process')
    }
    if (Test-Path -LiteralPath $keystore) { Remove-Item -LiteralPath $keystore -Force }
    $payload = $null; $values = $null
  }
}
