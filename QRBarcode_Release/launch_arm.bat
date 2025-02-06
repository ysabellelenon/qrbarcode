@echo off
cd /d "%~dp0"

:: Set environment variables for ARM/Parallels compatibility
set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
set "FLUTTER_WINDOWS_DEBUG=true"
set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"
set "FLUTTER_FORCE_SOFTWARE_RENDERING=true"
set "FLUTTER_WINDOW_FORCE_DCOMP=true"

:: Create required directories
set "APP_DATA_DIR=%LOCALAPPDATA%\QRBarcode"
if not exist "%APP_DATA_DIR%" mkdir "%APP_DATA_DIR%"

echo Starting QRBarcode with ARM optimizations...
echo Please wait while the application initializes...

:: Launch with optimized flags
start "" /WAIT "%~dp0qrbarcode.exe" --disable-gpu --enable-software-rendering --force-dcomp --no-sandbox

if errorlevel 1 (
    echo Application failed to start. Please check the logs.
    pause
)
