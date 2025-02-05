@echo off
echo Cleaning up QRBarcode_Release directory...
echo.

:: Create a scripts directory for batch files
if not exist "scripts" mkdir "scripts"

:: Move all batch files except the main launcher to scripts directory
for %%F in (*.bat) do (
    if /I not "%%F"=="launch_arm.bat" (
        if /I not "%%F"=="cleanup.bat" (
            move "%%F" "scripts\" >nul 2>&1
        )
    )
)

:: Move PowerShell scripts to scripts directory
move *.ps1 scripts\ >nul 2>&1

:: Clean up any temporary or log files
del /f /q *.log >nul 2>&1
del /f /q *.tmp >nul 2>&1
del /f /q *.bak >nul 2>&1

:: Verify essential files
echo Verifying essential files...
set "MISSING=0"
if not exist "qrbarcode.exe" set "MISSING=1" && echo [X] Missing qrbarcode.exe
if not exist "flutter_windows.dll" set "MISSING=1" && echo [X] Missing flutter_windows.dll
if not exist "sqlite3.dll" set "MISSING=1" && echo [X] Missing sqlite3.dll
if not exist "data\flutter_assets" set "MISSING=1" && echo [X] Missing flutter_assets directory

if "%MISSING%"=="0" (
    echo [√] All essential files are present
) else (
    echo WARNING: Some essential files are missing!
)

:: Create a minimal README if it doesn't exist
if not exist "README.txt" (
    echo Creating minimal README...
    (
        echo QRBarcode Application
        echo ====================
        echo.
        echo Quick Start:
        echo 1. Run launch_arm.bat to start the application
        echo.
        echo Troubleshooting:
        echo - Check scripts\run_with_log.bat for detailed logging
        echo - Check scripts\diagnose.bat for system diagnostics
        echo.
        echo Note: Do not move or delete any .dll files or the data directory.
    ) > "README.txt"
)

echo.
echo Cleanup complete!
echo Essential files and directories:
echo - qrbarcode.exe (main application)
echo - launch_arm.bat (main launcher)
echo - Required DLLs
echo - data\ directory
echo.
echo Support files moved to scripts\ directory
echo.
pause 