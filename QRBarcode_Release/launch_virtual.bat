@echo off
cd /d "%~dp0"

:: Set environment variables for virtual environment
set "FLUTTER_WINDOWS_VIRTUAL_DISPLAY=true"
set "FLUTTER_DISABLE_GPU=1"
set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"

:: Create local app data directory
set "APP_DATA_DIR=%LOCALAPPDATA%\QRBarcode"
if not exist "%APP_DATA_DIR%" mkdir "%APP_DATA_DIR%"

echo Starting QRBarcode in virtual environment mode...
echo.
echo If the application window doesn't appear:
echo 1. Try moving your mouse to different screen edges
echo 2. Check if the window appears in the taskbar
echo 3. Press Windows + Tab to see if the window is in another desktop
echo.

:: Launch with different window creation flags
start "" /HIGH "%~dp0qrbarcode.exe" --disable-gpu --enable-software-rendering

:: Wait a moment and check if process is running
timeout /t 5 /nobreak > nul
tasklist /FI "IMAGENAME eq qrbarcode.exe" /FO LIST

echo.
echo If you see qrbarcode.exe in the process list above but no window:
echo - Try pressing Alt+Tab
echo - Check the taskbar for a hidden window
echo - Right-click the taskbar icon and select "Maximize"
echo.
pause 