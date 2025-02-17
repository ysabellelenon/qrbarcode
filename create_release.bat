@echo off
:: ==========================================================
:: QRBarcode Release Creation Script
:: ==========================================================
:: Usage:
::   create_release.bat [flags]
::
:: Flags:
::   --clean     : Force clean build (removes build files and triggers pub get)
::   --pub-get   : Force flutter pub get (update dependencies)
::   --force     : Force update release files
::
:: Examples:
::   create_release.bat              : Normal build (fastest)
::   create_release.bat --clean      : Clean build
::   create_release.bat --pub-get    : Update dependencies only
::   create_release.bat --force      : Force update release files
::   create_release.bat --clean --force : Clean build and force update
::
:: Notes:
::   - By default, clean and pub get are skipped for faster builds
::   - pub get runs automatically if pubspec.yaml was modified
::   - --clean flag automatically triggers pub get
:: ==========================================================

setlocal enabledelayedexpansion

:: Parse flags
set "FLAGS="
:parse_args
if "%1"=="" goto end_parse
if "%1"=="--clean" set "FLAGS=!FLAGS! --clean"
if "%1"=="--pub-get" set "FLAGS=!FLAGS! --pub-get"
if "%1"=="--force" set "FLAGS=!FLAGS! --force"
shift
goto parse_args
:end_parse

:: Get version from pubspec.yaml and clean it
for /f "tokens=2 delims=: " %%a in ('findstr /C:"version:" pubspec.yaml') do (
    set "full_version=%%a"
    set "full_version=!full_version:"=!"
    :: Extract the version number before the plus sign
    for /f "tokens=1 delims=+" %%b in ("!full_version!") do set "version=%%b"
)

echo Creating release for version %version%...

:: First run the existing release build with any passed flags
call release.bat%FLAGS%
if errorlevel 1 (
    echo Error during build. Aborting release creation.
    exit /b 1
)

:: Create release directory with clean version number
set "release_dir=releases\v%version%"
if not exist "%release_dir%" mkdir "%release_dir%"

:: Create release package
echo Creating release package...
set "release_zip=%release_dir%\qrbarcode-windows-v%version%.zip"
powershell -Command "Compress-Archive -Path 'QRBarcode_Release\*' -DestinationPath '%release_zip%' -Force"

:: Create release notes template
set "notes_file=%release_dir%\release_notes.md"
echo # QRBarcode v%version% > "%notes_file%"
echo. >> "%notes_file%"
echo ## Release Information >> "%notes_file%"
echo Release Date: %date% >> "%notes_file%"
echo Build Version: %version% >> "%notes_file%"
echo. >> "%notes_file%"
echo ## What's New >> "%notes_file%"
echo. >> "%notes_file%"
echo ## System Requirements >> "%notes_file%"
echo. >> "%notes_file%"
echo - Windows 10 or later >> "%notes_file%"
echo - Visual C++ Redistributable 2015-2022 >> "%notes_file%"
echo. >> "%notes_file%"
echo ## Installation >> "%notes_file%"
echo. >> "%notes_file%"
echo 1. Download the release package: [qrbarcode-windows-v%version%.zip](qrbarcode-windows-v%version%.zip) >> "%notes_file%"
echo 2. Extract the ZIP file to your desired location >> "%notes_file%"
echo 3. Run qrbarcode.exe >> "%notes_file%"
echo. >> "%notes_file%"
echo ## SHA-256 Checksum >> "%notes_file%"
echo. >> "%notes_file%"
echo ```plaintext >> "%notes_file%"
powershell -Command "Get-FileHash '%release_zip%' -Algorithm SHA256 | ForEach-Object {$_.Hash + '  ' + (Split-Path $_.Path -Leaf)}" >> "%notes_file%"
echo ``` >> "%notes_file%"

echo.
echo Release package created in %release_dir%
echo =====================================
echo.
echo Next steps:
echo 1. Review and edit the release notes in %notes_file%
echo 2. Create a new release on GitHub:
echo    - Tag: v%version%
echo    - Title: QRBarcode v%version%
echo    - Upload %release_zip%
echo    - Copy the contents of %notes_file% as the release description
echo.
echo Done!