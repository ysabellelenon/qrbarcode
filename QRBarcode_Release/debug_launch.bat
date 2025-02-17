@echo off
echo Starting QRBarcode in debug mode...
echo.

:: Create log directory if it doesn't exist
if not exist "logs" mkdir logs

:: Set the log file path
set "LOG_FILE=logs\startup_%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"
set "LOG_FILE=%LOG_FILE: =0%"

:: Set environment variables that might be needed
set "FLUTTER_WINDOWS_DEBUG=true"
set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"

echo Logging startup to: %LOG_FILE%
echo.

:: Check if all required DLLs exist
echo Checking required DLLs...
set MISSING_DLLS=0
if not exist "sqlite3.dll" (
    echo [MISSING] sqlite3.dll
    set /a MISSING_DLLS+=1
)
if not exist "flutter_windows.dll" (
    echo [MISSING] flutter_windows.dll
    set /a MISSING_DLLS+=1
)
if not exist "window_size_plugin.dll" (
    echo [MISSING] window_size_plugin.dll
    set /a MISSING_DLLS+=1
)
if not exist "MSVCP140.dll" (
    echo [MISSING] MSVCP140.dll
    set /a MISSING_DLLS+=1
)
if not exist "VCRUNTIME140.dll" (
    echo [MISSING] VCRUNTIME140.dll
    set /a MISSING_DLLS+=1
)
if not exist "VCRUNTIME140_1.dll" (
    echo [MISSING] VCRUNTIME140_1.dll
    set /a MISSING_DLLS+=1
)

if %MISSING_DLLS% GTR 0 (
    echo.
    echo WARNING: %MISSING_DLLS% required DLLs are missing!
    echo This might cause the application to fail.
    echo.
)

:: Check if data directory exists
if not exist "data" (
    echo [MISSING] data directory
    echo This will cause the application to fail.
    echo.
)

echo Starting application with verbose logging...
echo ----------------------------------------
echo.

:: Run the application with error capture
qrbarcode.exe --verbose > "%LOG_FILE%" 2>&1

:: Check the error level
set ERROR_CODE=%errorlevel%
echo Application exited with code: %ERROR_CODE%
echo.

if %ERROR_CODE% NEQ 0 (
    echo Application failed to start properly.
    echo.
    echo Last few lines of the log file:
    echo -------------------------------
    powershell -Command "Get-Content '%LOG_FILE%' -Tail 20"
    echo.
    echo Full log has been saved to: %LOG_FILE%
)

echo.
echo Press any key to exit...
pause > nul 