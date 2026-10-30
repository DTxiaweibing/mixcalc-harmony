# Generate HarmonyOS signing .p12 + .csr without DevEco Studio.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\init-signing.ps1
#   pwsh -File .\scripts\init-signing.ps1
#
# The password is read at runtime and is never written to disk.
# The .p12 contains a self-signed key. Upload only the .csr to AGC.

[CmdletBinding()]
param(
  [string]$OutDir = 'D:\mixcalc-sign',
  [string]$Alias = 'mixcalc',
  [string]$CommonName = 'mixcalc',
  [int]$ValidityDays = 9125,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$jdkCandidates = @(
  'C:\Program Files\Java\jdk-21\bin',
  'C:\Program Files\Java\jdk-17\bin',
  'C:\Program Files\Java\jdk-11\bin'
)

$jdk = $null
foreach ($candidate in $jdkCandidates) {
  if (Test-Path (Join-Path $candidate 'keytool.exe')) {
    $jdk = $candidate
    break
  }
}

if (-not $jdk) {
  throw 'keytool.exe not found. Install JDK 17/21 or edit $jdkCandidates.'
}

$keytool = Join-Path $jdk 'keytool.exe'
$p12 = Join-Path $OutDir "$Alias-release.p12"
$csr = Join-Path $OutDir "$Alias-release.csr"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ((Test-Path $p12) -and (-not $Force)) {
  throw "File already exists: $p12 . Use -Force to overwrite."
}

$p12Pwd = Read-Host "Enter p12 password (at least 8 characters)"
if ([string]::IsNullOrWhiteSpace($p12Pwd) -or ($p12Pwd.Length -lt 8)) {
  throw 'Password must be at least 8 characters.'
}

if (Test-Path $p12) { Remove-Item $p12 -Force }
if (Test-Path $csr) { Remove-Item $csr -Force }

Write-Host "Using keytool: $keytool" -ForegroundColor Cyan

$genArgs = @(
  '-genkeypair',
  '-alias', $Alias,
  '-keyalg', 'EC',
  '-sigalg', 'SHA256withECDSA',
  '-dname', "C=CN,O=shrimpfarm,OU=$Alias,CN=$CommonName",
  '-keystore', $p12,
  '-storetype', 'pkcs12',
  '-validity', "$ValidityDays",
  '-storepass', $p12Pwd,
  '-keypass', $p12Pwd
)

& $keytool @genArgs
if ($LASTEXITCODE -ne 0) {
  throw "keytool -genkeypair failed with exit code $LASTEXITCODE ."
}

$csrArgs = @(
  '-certreq',
  '-alias', $Alias,
  '-keystore', $p12,
  '-storetype', 'pkcs12',
  '-sigalg', 'SHA256withECDSA',
  '-file', $csr,
  '-storepass', $p12Pwd
)

& $keytool @csrArgs
if ($LASTEXITCODE -ne 0) {
  throw "keytool -certreq failed with exit code $LASTEXITCODE ."
}

Get-Item -Path $p12, $csr |
  Select-Object FullName, Length, LastWriteTime |
  Format-Table -AutoSize

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Green
Write-Host '1) AGC -> Certificates, App ID and Profile -> Certificates -> Add -> Release certificate -> upload the .csr'
Write-Host '2) Download the .cer, then create a Release Profile and download the .p7b'
Write-Host '3) Sign the release HAP with hap-sign-tool'
Write-Host ''
Write-Host 'Never upload or share the .p12 file or its password.' -ForegroundColor Yellow
