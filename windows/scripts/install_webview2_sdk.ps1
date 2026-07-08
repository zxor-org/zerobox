param(
  [string]$Version = "",
  [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WindowsDir = Split-Path -Parent $ScriptDir
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $WindowsDir "packages"
}

$PackageId = "microsoft.web.webview2"
$PackageName = "Microsoft.Web.WebView2"

if ([string]::IsNullOrWhiteSpace($Version)) {
  $IndexUrl = "https://api.nuget.org/v3-flatcontainer/$PackageId/index.json"
  Write-Host "[INFO] Fetching WebView2 SDK version index"
  $Index = Invoke-RestMethod -Uri $IndexUrl
  $Version = $Index.versions |
    Where-Object { $_ -notmatch "-" } |
    Select-Object -Last 1
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  throw "Could not resolve a WebView2 SDK version."
}

$PackageRoot = Join-Path $OutputDirectory "$PackageName.$Version"
$HeaderPath = Join-Path $PackageRoot "build/native/include/WebView2.h"
if (Test-Path $HeaderPath) {
  Write-Host "[INFO] WebView2 SDK already installed: $PackageRoot"
  exit 0
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$NupkgPath = Join-Path $OutputDirectory "$PackageName.$Version.nupkg"
$ZipPath = Join-Path $OutputDirectory "$PackageName.$Version.zip"
$DownloadUrl = "https://api.nuget.org/v3-flatcontainer/$PackageId/$Version/$PackageId.$Version.nupkg"

Write-Host "[INFO] Downloading $PackageName $Version"
Invoke-WebRequest -Uri $DownloadUrl -OutFile $NupkgPath

if (Test-Path $PackageRoot) {
  Remove-Item -Recurse -Force $PackageRoot
}
Copy-Item $NupkgPath $ZipPath -Force
Expand-Archive -Path $ZipPath -DestinationPath $PackageRoot -Force
Remove-Item $ZipPath -Force

if (!(Test-Path $HeaderPath)) {
  throw "WebView2 SDK was downloaded but WebView2.h was not found at $HeaderPath"
}

Write-Host "[INFO] Installed WebView2 SDK: $PackageRoot"
