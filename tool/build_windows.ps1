param(
  [switch]$Dev,
  [switch]$SkipWebView2Sdk,
  [string]$WebView2SdkVersion = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$ReleaseDir = Join-Path $ProjectRoot "build/release"
$AppName = "zerobox"

function Require-Command($Name) {
  if (!(Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Get-PubspecVersion {
  $Pubspec = Join-Path $ProjectRoot "pubspec.yaml"
  $Line = Select-String -Path $Pubspec -Pattern '^version:\s*([^+]+)(?:\+(\d+))?' | Select-Object -First 1
  if (!$Line) {
    throw "Could not read version from pubspec.yaml"
  }
  return @{
    BaseVersion = $Line.Matches[0].Groups[1].Value.Trim()
    BuildNumber = if ($Line.Matches[0].Groups[2].Success) { $Line.Matches[0].Groups[2].Value } else { "1" }
  }
}

Require-Command "git"
Require-Command "flutter"

$VersionInfo = Get-PubspecVersion
$GitHash = (git -C $ProjectRoot rev-parse --short=7 HEAD 2>$null)
if ([string]::IsNullOrWhiteSpace($GitHash)) {
  $GitHash = "nogit"
}

git -C $ProjectRoot update-index --refresh *> $null
$Dirty = $false
git -C $ProjectRoot diff-index --quiet HEAD -- *> $null
if ($LASTEXITCODE -ne 0) {
  $Dirty = $true
}
$Untracked = git -C $ProjectRoot ls-files --others --exclude-standard
if ($Untracked) {
  $Dirty = $true
}

$Version = $VersionInfo.BaseVersion
if ($Dev) {
  if ($Dirty) {
    $Version = "$($VersionInfo.BaseVersion).dirty.$GitHash"
  } else {
    $Version = "$($VersionInfo.BaseVersion).git.$GitHash"
  }
} elseif ($Dirty) {
  throw "Git working tree is dirty. Commit or stash changes first, or use -Dev."
}

if (!$SkipWebView2Sdk) {
  $InstallWebView2 = Join-Path $ProjectRoot "windows/scripts/install_webview2_sdk.ps1"
  if (Test-Path $InstallWebView2) {
    if ([string]::IsNullOrWhiteSpace($WebView2SdkVersion)) {
      & $InstallWebView2
    } else {
      & $InstallWebView2 -Version $WebView2SdkVersion
    }
  }
}

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

Write-Host "[INFO] Building Windows release package for version $Version"
flutter build windows --release --obfuscate --split-debug-info=symbols\windows --build-name=$Version --build-number=$($VersionInfo.BuildNumber) --dart-define=APP_VERSION=$Version --dart-define=GIT_COMMIT_HASH=$GitHash

$BundleDir = Join-Path $ProjectRoot "build/windows/x64/runner/Release"
$ExePath = Join-Path $BundleDir "$AppName.exe"
if (!(Test-Path $ExePath)) {
  throw "Windows build output not found: $BundleDir"
}

$Output = Join-Path $ReleaseDir "$AppName-$Version-windows-amd64.zip"
if (Test-Path $Output) {
  Remove-Item -Force $Output
}
Compress-Archive -Path (Join-Path $BundleDir "*") -DestinationPath $Output -Force
Write-Host "[INFO] Produced $Output"

$SymbolsDir = Join-Path $ProjectRoot "symbols/windows"
$SymbolsOutput = Join-Path $ReleaseDir "$AppName-$Version-windows-amd64.symbols.zip"
if (Test-Path $SymbolsDir) {
  if (Test-Path $SymbolsOutput) {
    Remove-Item -Force $SymbolsOutput
  }
  Compress-Archive -Path (Join-Path $SymbolsDir "*") -DestinationPath $SymbolsOutput -Force
  Write-Host "[INFO] Produced $SymbolsOutput"
} else {
  Write-Host "[WARN] Symbols directory not found; skipped symbols package: $SymbolsDir"
}

Write-Host "[INFO] Windows build complete"
