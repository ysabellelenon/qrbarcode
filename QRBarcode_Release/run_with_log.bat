@echo off
cd /d "%~dp0"
echo Starting application with verbose logging...
echo Current directory: %CD%
echo.

:: Check Windows version and display info
echo Checking System Information...
ver
echo.
echo Display Information:
powershell -Command "Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion, VideoProcessor"
echo.

:: Check if running from Program Files
echo %CD% | findstr /I "Program Files" > nul
if not errorlevel 1 (
    echo [WARNING] Running from Program Files directory may cause permission issues.
    echo Please move the application to a different location, such as:
    echo - C:\Users\%USERNAME%\AppData\Local\QRBarcode
    echo - C:\Users\%USERNAME%\Documents\QRBarcode
    echo.
    choice /C YN /M "Do you want to continue anyway"
    if errorlevel 2 goto :eof
)

:: Check for Visual C++ Redistributable
echo Checking Visual C++ Redistributable...
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Version >nul 2>&1
if errorlevel 1 (
    echo [X] Microsoft Visual C++ Redistributable 2015-2022 (x64) might be missing
    echo Please download and install from:
    echo https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo.
    choice /C YN /M "Do you want to continue anyway"
    if errorlevel 2 goto :eof
) else (
    echo [√] Visual C++ Redistributable found
)

:: Store start time for log filtering
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set START_TIME=%datetime:~0,14%

:: Create desktop shortcut if it doesn't exist
echo Checking/Creating desktop shortcut...
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\QRBarcode.lnk"
if not exist "%SHORTCUT_PATH%" (
    powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%SHORTCUT_PATH%'); $SC.TargetPath = '%~dp0qrbarcode.exe'; $SC.WorkingDirectory = '%~dp0'; $SC.Save()"
    echo Created desktop shortcut
)

echo Checking if qrbarcode.exe exists...
if not exist "%~dp0qrbarcode.exe" (
    echo [X] CRITICAL ERROR: qrbarcode.exe not found in current directory!
    echo Current directory contents:
    dir /b
    goto :error
)

echo Checking for required DLLs...
if exist MSVCP140.dll (echo [√] Found MSVCP140.dll) else (echo [X] Missing MSVCP140.dll)
if exist VCRUNTIME140.dll (echo [√] Found VCRUNTIME140.dll) else (echo [X] Missing VCRUNTIME140.dll)
if exist VCRUNTIME140_1.dll (echo [√] Found VCRUNTIME140_1.dll) else (echo [X] Missing VCRUNTIME140_1.dll)
if exist flutter_windows.dll (echo [√] Found flutter_windows.dll) else (echo [X] Missing flutter_windows.dll)
if exist pdfium.dll (echo [√] Found pdfium.dll) else (echo [X] Missing pdfium.dll)
if exist printing_plugin.dll (echo [√] Found printing_plugin.dll) else (echo [X] Missing printing_plugin.dll)
if exist window_size_plugin.dll (echo [√] Found window_size_plugin.dll) else (echo [X] Missing window_size_plugin.dll)

echo.
echo Checking data folder...
if exist data (
    echo [√] Data folder exists
    echo Contents of data folder:
    dir /b data
    echo.
    echo Contents of data\flutter_assets:
    if exist data\flutter_assets (
        dir /b data\flutter_assets
    ) else (
        echo [X] flutter_assets folder is missing!
    )
) else (
    echo [X] Data folder is missing!
)

echo.
echo Checking file permissions...
echo Testing write access to current directory...
echo test > test.tmp
if errorlevel 1 (
    echo [X] WARNING: No write permission in current directory
) else (
    echo [√] Write permission OK
    del test.tmp
)

:: Set Flutter debugging variables
set "FLUTTER_DEBUG_MODE=true"
set "FLUTTER_ENGINE_VERBOSE_LOGGING=true"
set "FLUTTER_RUNNER_DEBUG=true"

:: Create a temporary directory for app data in user's space
set "APP_DATA_DIR=%LOCALAPPDATA%\QRBarcode"
if not exist "%APP_DATA_DIR%" mkdir "%APP_DATA_DIR%"

:: Set environment variables for Flutter
set "FLUTTER_STORAGE_BASE_URL=%APP_DATA_DIR%"
set "FLUTTER_ENGINE_SWITCH_DATA_PATH=%APP_DATA_DIR%"

echo.
echo Running application with output...
echo ----------------------------------------
echo Attempting to run with debug output...

:: Try running with different methods
echo Method 1: Direct launch with wait...
start "" /wait "%~dp0qrbarcode.exe" --verbose
set EXIT_CODE=%errorlevel%
if %EXIT_CODE% NEQ 0 (
    echo Method 1 failed with exit code: %EXIT_CODE%
    echo.
    echo Method 2: Trying PowerShell launch...
    powershell -Command "Start-Process '%~dp0qrbarcode.exe' -WorkingDirectory '%~dp0' -ArgumentList '--verbose' -NoNewWindow -Wait"
    set EXIT_CODE=%errorlevel%
)

echo ----------------------------------------
echo Final Exit code: %EXIT_CODE%

if %EXIT_CODE% NEQ 0 goto :error

:: Add event log check even on success
echo.
echo Checking recent application events...
powershell -Command "Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddMinutes(-1)} | Select-Object TimeCreated, Source, Message | Format-List" 2>nul

goto :eof

:error
echo.
echo Error Analysis:
echo - Exit code %EXIT_CODE% indicates the application failed to start properly
echo - Checking system information...
echo.
echo System Information:
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type"
echo.
echo Current Directory Structure:
dir /s /b
echo.
echo Visual C++ Redistributables installed:
wmic product where "name like '%%Microsoft Visual C%%'" get name
echo.
echo Checking Event Viewer for recent errors...
echo --------------------------------------
powershell -Command "Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=(Get-Date).AddMinutes(-5)} | Select-Object TimeCreated, Source, Message | Format-List" 2>nul
echo.
echo Checking .NET Runtime errors...
echo --------------------------------------
powershell -Command "Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error','Windows Error Reporting','.NET Runtime'; StartTime=(Get-Date).AddMinutes(-5)} | Select-Object TimeCreated, Source, Message | Format-List" 2>nul
echo.
echo Would you like to try running as administrator? (Y/N)
set /p ADMIN_CHOICE=
if /i "%ADMIN_CHOICE%"=="Y" (
    echo.
    echo Attempting to run as administrator...
    powershell -Command "Start-Process '%~dp0qrbarcode.exe' -WorkingDirectory '%~dp0' -ArgumentList '--verbose' -Verb RunAs"
)
echo.
pause 