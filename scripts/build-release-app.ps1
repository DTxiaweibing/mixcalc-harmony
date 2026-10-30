# Build a signed HarmonyOS .app for AppGallery release, CLI only.
#
# Why not let hvigor sign?
#   hvigor expects an encrypted password (DevEco writes a 64-char value).
#   A plaintext password fails with error 00303116.
#   So this script builds an UNSIGNED .app and signs it with hap-sign-tool.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release-app.ps1
#
# The p12 password is typed at runtime. It is passed to hap-sign-tool only;
# it is never written into build-profile.json5.

[CmdletBinding()]
param(
  [string]$ProjectRoot = 'D:\mixcalc-harmony',
  [string]$SignDir = 'D:\mixcalc-sign',
  [string]$Alias = 'mixcalc',
  [string]$CommandLineTools = 'D:\command-line-tools\command-line-tools',
  [string]$Jdk = 'C:\Program Files\Java\jdk-21\bin',
  [switch]$SkipClean
)

$ErrorActionPreference = 'Stop'

$p12 = Join-Path $SignDir "$Alias-release.p12"
$cer = Join-Path $SignDir "$Alias-release.cer"
$chain = Join-Path $SignDir "$Alias-release-chain.pem"
$p7b = Join-Path $SignDir "$Alias-release-profileRelease.p7b"
$profilePath = Join-Path $ProjectRoot 'build-profile.json5'
$backupPath = "$profilePath.bak"
$jar = Join-Path $CommandLineTools 'sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar'
$java = Join-Path $Jdk 'java.exe'
$hvigor = Join-Path $CommandLineTools 'bin\hvigorw.bat'

if (-not (Test-Path $p7b)) {
  $candidate = Get-ChildItem -Path $SignDir -Filter '*.p7b' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($candidate) {
    $p7b = $candidate.FullName
  }
}

foreach ($file in @($p12, $cer, $p7b, $profilePath, $jar, $java, $hvigor)) {
  if (-not (Test-Path $file)) {
    throw "Missing required file: $file"
  }
}

if (-not (Test-Path $chain)) {
  $chain = $cer
}

$p12Pwd = Read-Host 'p12 password'
if ([string]::IsNullOrWhiteSpace($p12Pwd)) {
  throw 'p12 password is empty.'
}

$appJsonPath = Join-Path $ProjectRoot 'AppScope\app.json5'
$appJson = [System.IO.File]::ReadAllText($appJsonPath, [System.Text.Encoding]::UTF8)
$versionMatch = [regex]::Match($appJson, '"versionName"\s*:\s*"([^"]+)"')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { '0.0.0' }

$utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
$originalText = [System.IO.File]::ReadAllText($profilePath, [System.Text.Encoding]::UTF8)

# Comment out any active product signingConfig so hvigor produces an unsigned app.
$modified = [regex]::Replace(
  $originalText,
  "(?m)^(\s*)signingConfig:\s*'[^']+',\s*$",
  "`$1// signingConfig: removed for unsigned app build,"
)

if ($modified -match "(?m)^\s*signingConfig:\s*") {
  throw 'Failed to comment out signingConfig in build-profile.json5.'
}

$env:PATH = "$CommandLineTools\bin;$CommandLineTools\tool\node;$env:PATH"
$env:DEVECO_SDK_HOME = Join-Path $CommandLineTools 'sdk'

if (Test-Path $backupPath) {
  throw "Found $backupPath from a previous interrupted run. Inspect and remove it before retrying."
}

Copy-Item $profilePath $backupPath -Force

try {
  [System.IO.File]::WriteAllText($profilePath, $modified, $utf8NoBom)

  Push-Location $ProjectRoot
  try {
    if (-not $SkipClean) {
      & $hvigor clean --no-daemon
      if ($LASTEXITCODE -ne 0) {
        throw "hvigor clean failed with exit code $LASTEXITCODE"
      }
    }

    & $hvigor assembleApp -p product=default -p buildMode=release --no-daemon --no-codesign
    if ($LASTEXITCODE -ne 0) {
      Write-Host 'Retrying assembleApp with --mode project ...' -ForegroundColor Yellow
      & $hvigor assembleApp --mode project -p product=default -p buildMode=release --no-daemon --no-codesign
      if ($LASTEXITCODE -ne 0) {
        Write-Host 'Retrying without --no-codesign ...' -ForegroundColor Yellow
        & $hvigor assembleApp -p product=default -p buildMode=release --no-daemon
        if ($LASTEXITCODE -ne 0) {
          throw "hvigor assembleApp failed with exit code $LASTEXITCODE"
        }
      }
    }

    $searchRoots = @(
      (Join-Path $ProjectRoot 'entry\build'),
      (Join-Path $ProjectRoot 'build')
    ) | Where-Object { Test-Path $_ }

    $apps = @(
      Get-ChildItem -Path $searchRoots -Recurse -Filter '*.app' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    )

    if ($apps.Count -eq 0) {
      throw 'Build finished, but no .app file was found under entry\build or build.'
    }

    $unsigned = $apps | Where-Object { $_.Name -match 'unsigned' } | Select-Object -First 1
    $app = if ($unsigned) { $unsigned } else { $apps[0] }

    Write-Host "Signing APP: $($app.FullName)" -ForegroundColor Cyan

    $dist = Join-Path $ProjectRoot 'dist'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $appOut = Join-Path $dist "mixcalc-$version-release-signed.app"
    Remove-Item $appOut -Force -ErrorAction SilentlyContinue

    $signArgs = @(
      'sign-app',
      '-mode', 'localSign',
      '-keyAlias', $Alias,
      '-keyPwd', $p12Pwd,
      '-signAlg', 'SHA256withECDSA',
      '-appCertFile', $chain,
      '-profileFile', $p7b,
      '-inFile', $app.FullName,
      '-keystoreFile', $p12,
      '-keystorePwd', $p12Pwd,
      '-outFile', $appOut
    )

    & $java -jar $jar @signArgs
    if ($LASTEXITCODE -ne 0) {
      throw "hap-sign-tool sign-app failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path $appOut)) {
      throw "Signing reported success but output is missing: $appOut"
    }

    # 顺便把 entry HAP 也签一份，方便继续云调试
    $hapOut = $null
    $hapDir = Join-Path $ProjectRoot 'entry\build\default\outputs\default'
    if (Test-Path $hapDir) {
      $unsignedHap = Get-ChildItem -Path $hapDir -Filter '*unsigned.hap' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($unsignedHap) {
        $hapOut = Join-Path $dist "mixcalc-$version-release-signed.hap"
        Remove-Item $hapOut -Force -ErrorAction SilentlyContinue
        $hapArgs = @(
          'sign-app',
          '-mode', 'localSign',
          '-keyAlias', $Alias,
          '-keyPwd', $p12Pwd,
          '-signAlg', 'SHA256withECDSA',
          '-appCertFile', $chain,
          '-profileFile', $p7b,
          '-inFile', $unsignedHap.FullName,
          '-keystoreFile', $p12,
          '-keystorePwd', $p12Pwd,
          '-outFile', $hapOut
        )
        & $java -jar $jar @hapArgs
        if ($LASTEXITCODE -ne 0) {
          Write-Warning 'HAP signing failed; the .app is still available.'
          $hapOut = $null
        }
      }
    }

    Write-Host ''
    Write-Host 'BUILD OK' -ForegroundColor Green
    Write-Host "APP: $appOut"
    if ($hapOut) {
      Write-Host "HAP: $hapOut"
    }
    Write-Host ''
    Write-Host 'Upload only the .app to AppGallery. The .hap is for installation/testing.'
  }
  finally {
    Pop-Location
  }
}
finally {
  if (Test-Path $backupPath) {
    Copy-Item $backupPath $profilePath -Force
    Remove-Item $backupPath -Force
  }
}
