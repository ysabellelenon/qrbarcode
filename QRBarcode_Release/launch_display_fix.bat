@echo off
cd /d "%~dp0"

:: Kill any existing instances
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
timeout /t 2 /nobreak >nul

:: Set common environment variables
set "APP_DATA_DIR=%LOCALAPPDATA%\QRBarcode"
if not exist "%APP_DATA_DIR%" mkdir "%APP_DATA_DIR%"

echo Testing different display configurations...
echo This script will try multiple methods to make the window appear.
echo.

:: Method 1: Basic software rendering
echo Method 1: Basic software rendering...
set "FLUTTER_FORCE_SOFTWARE_RENDERING=true"
start "" /WAIT qrbarcode.exe --disable-gpu
timeout /t 5 /nobreak
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
timeout /t 2 /nobreak

:: Method 2: ANGLE rendering
echo Method 2: ANGLE rendering...
set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
set "ANGLE_DEFAULT_PLATFORM=swiftshader"
start "" /WAIT qrbarcode.exe --disable-gpu --use-angle=swiftshader
timeout /t 5 /nobreak
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
timeout /t 2 /nobreak

:: Method 3: DirectComposition
echo Method 3: DirectComposition...
set "FLUTTER_WINDOW_FORCE_DCOMP=true"
set "ENABLE_DIRECT_COMPOSITION=1"
start "" /WAIT qrbarcode.exe --enable-direct-composition
timeout /t 5 /nobreak
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
timeout /t 2 /nobreak

:: Method 4: Combined approach
echo Method 4: Combined approach (recommended)...
set "FLUTTER_FORCE_SOFTWARE_RENDERING=true"
set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
set "FLUTTER_WINDOW_FORCE_DCOMP=true"
set "ENABLE_DIRECT_COMPOSITION=1"
set "FLUTTER_WINDOWS_DEBUG=true"
set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"

echo.
echo Starting with all optimizations...
echo If the window appears with this method, please use these settings in the future.
echo.
start "" /WAIT qrbarcode.exe --disable-gpu --enable-software-rendering --force-dcomp --no-sandbox

echo.
echo If none of the methods worked:
echo 1. Check if the process is running in Task Manager
echo 2. Try moving your mouse to different screen edges
echo 3. Press Alt+Tab to check for hidden windows
echo 4. Try running the application as administrator
echo.
pause 