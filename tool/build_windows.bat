@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "RELEASE_DIR=%PROJECT_ROOT%\build\release"
set "APP_NAME=zerobox"
set "DEV_MODE=false"

:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--dev" (
  set "DEV_MODE=true"
  shift
  goto parse_args
)
if "%~1"=="-h" goto show_help
if "%~1"=="--help" goto show_help
echo [ERROR] Unknown option: %~1 1>&2
goto show_help_error

:show_help
echo Usage: build_windows.bat [options]
echo.
echo Options:
echo   --dev       Allow a dirty worktree and append git metadata to the package version
echo   -h, --help  Show this help
exit /b 0

:show_help_error
echo Usage: build_windows.bat [options] 1>&2
echo Options: --dev, -h, --help 1>&2
exit /b 1

:args_done
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$m = Select-String -Path '%PROJECT_ROOT%\pubspec.yaml' -Pattern '^version:\s*([^+]+)(?:\+(\d+))?' | Select-Object -First 1; if (-not $m) { exit 1 }; $m.Matches[0].Groups[1].Value.Trim()"`) do set "BASE_VERSION=%%V"
if not defined BASE_VERSION (
  echo [ERROR] Could not read version from pubspec.yaml 1>&2
  exit /b 1
)

for /f "usebackq delims=" %%B in (`powershell -NoProfile -Command "$m = Select-String -Path '%PROJECT_ROOT%\pubspec.yaml' -Pattern '^version:\s*([^+]+)(?:\+(\d+))?' | Select-Object -First 1; if ($m -and $m.Matches[0].Groups[2].Success) { $m.Matches[0].Groups[2].Value } else { '1' }"`) do set "BUILD_NUMBER=%%B"

for /f "usebackq delims=" %%H in (`git -C "%PROJECT_ROOT%" rev-parse --short^=7 HEAD 2^>NUL`) do set "GIT_HASH=%%H"
if not defined GIT_HASH set "GIT_HASH=nogit"

set "DIRTY=false"
git -C "%PROJECT_ROOT%" update-index --refresh >NUL 2>NUL
git -C "%PROJECT_ROOT%" diff-index --quiet HEAD -- >NUL 2>NUL
if errorlevel 1 set "DIRTY=true"
for /f "usebackq delims=" %%U in (`git -C "%PROJECT_ROOT%" ls-files --others --exclude-standard 2^>NUL`) do set "DIRTY=true"

set "VERSION=%BASE_VERSION%"
if "%DEV_MODE%"=="true" (
  if "%DIRTY%"=="true" (
    set "VERSION=%BASE_VERSION%.dirty.%GIT_HASH%"
  ) else (
    set "VERSION=%BASE_VERSION%.git.%GIT_HASH%"
  )
) else (
  if "%DIRTY%"=="true" (
    echo [ERROR] Git working tree is dirty. Commit or stash changes first, or use --dev. 1>&2
    exit /b 1
  )
)

where flutter >NUL 2>NUL
if errorlevel 1 (
  echo [ERROR] Required command not found: flutter 1>&2
  exit /b 1
)

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

echo [INFO] Building Windows release package for version %VERSION%
echo [INFO] Running: flutter build windows --release
flutter build windows --release --obfuscate --split-debug-info=symbols\windows --build-name=%VERSION% --build-number=%BUILD_NUMBER% --dart-define=APP_VERSION=%VERSION% --dart-define=GIT_COMMIT_HASH=%GIT_HASH% "--dart-define=BUILD_USER=%USERNAME%"
if errorlevel 1 exit /b 1

set "BUNDLE_DIR=%PROJECT_ROOT%\build\windows\x64\runner\Release"
if not exist "%BUNDLE_DIR%\%APP_NAME%.exe" (
  echo [ERROR] Windows build output not found: %BUNDLE_DIR% 1>&2
  exit /b 1
)

set "OUTPUT=%RELEASE_DIR%\%APP_NAME%-%VERSION%-windows-amd64.zip"
if exist "%OUTPUT%" del /f /q "%OUTPUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%BUNDLE_DIR%\*' -DestinationPath '%OUTPUT%' -Force"
if errorlevel 1 exit /b 1

echo [INFO] Produced %OUTPUT%

set "SYMBOLS_DIR=%PROJECT_ROOT%\symbols\windows"
set "SYMBOLS_OUTPUT=%RELEASE_DIR%\%APP_NAME%-%VERSION%-windows-amd64.symbols.zip"
if exist "%SYMBOLS_DIR%" (
  if exist "%SYMBOLS_OUTPUT%" del /f /q "%SYMBOLS_OUTPUT%"
  powershell -NoProfile -Command "Compress-Archive -Path '%SYMBOLS_DIR%\*' -DestinationPath '%SYMBOLS_OUTPUT%' -Force"
  if errorlevel 1 exit /b 1
  echo [INFO] Produced %SYMBOLS_OUTPUT%
) else (
  echo [WARN] Symbols directory not found; skipped symbols package: %SYMBOLS_DIR%
)

echo [INFO] Windows build complete
