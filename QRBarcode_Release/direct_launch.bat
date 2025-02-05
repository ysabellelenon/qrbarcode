@echo off
setlocal EnableDelayedExpansion

:: Store the original directory
set "ORIGINAL_DIR=%CD%"
cd /d "%~dp0"

:: Set up environment
set "APP_DIR=%~dp0"
set "APP_DATA=%LOCALAPPDATA%\QRBarcode"
set "ASSET_DIR=%APP_DIR%data\flutter_assets"
set "DLL_DIR=%APP_DIR%"

:: Add current directory to PATH
set "PATH=%APP_DIR%;%PATH%"

:: Create data directory if it doesn't exist
if not exist "%APP_DATA%" mkdir "%APP_DATA%"

:: Verify critical files
set "MISSING_FILES=0"
if not exist "%APP_DIR%qrbarcode.exe" set /a "MISSING_FILES+=1"
if not exist "%APP_DIR%flutter_windows.dll" set /a "MISSING_FILES+=1"
if not exist "%ASSET_DIR%" set /a "MISSING_FILES+=1"

if %MISSING_FILES% neq 0 (
    echo Error: Missing required files
    echo Please ensure all files are present in the application directory
    pause
    exit /b 1
)

:: Launch the application
echo Starting QRBarcode...
start "" /B "%APP_DIR%qrbarcode.exe" --working-directory="%APP_DIR%" --local-storage-path="%APP_DATA%"

:: Return to original directory
cd /d "%ORIGINAL_DIR%" 