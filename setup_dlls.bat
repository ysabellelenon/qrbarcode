@echo off
setlocal enabledelayedexpansion

echo QRBarcode DLL Setup
echo ==================
echo.

:: Check if running with admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges
) else (
    echo Warning: Not running with administrator privileges
    echo Some operations might fail if DLLs are locked
    echo.
)

:: Detect system architecture
set "ARCH=x64"
set "IS_ARM=0"

echo Detecting system architecture...
wmic os get osarchitecture | findstr "64-bit" >nul
if %errorLevel% == 0 (
    :: Further check if it's ARM64
    wmic os get caption | findstr "ARM" >nul
    if %errorLevel% == 0 (
        set "ARCH=arm64"
        set "IS_ARM=1"
        echo Detected ARM64 architecture
    ) else (
        echo Detected x64 architecture
    )
) else (
    set "ARCH=x86"
    echo Detected x86 architecture
)

:: Set source and destination paths
set "SCRIPT_DIR=%~dp0"
set "DLL_SOURCE=%SCRIPT_DIR%dlls\%ARCH%"
set "DLL_DEST=%SCRIPT_DIR%"

:: Verify source directory exists
if not exist "%DLL_SOURCE%" (
    echo ERROR: DLL source directory not found: %DLL_SOURCE%
    echo Please ensure the dlls directory is present with the correct architecture subdirectories.
    pause
    exit /b 1
)

echo.
echo Setting up DLLs for %ARCH% architecture...
echo Source: %DLL_SOURCE%
echo Destination: %DLL_DEST%
echo.

:: Try to stop any running instances of the application
echo Checking for running instances...
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
if %errorLevel% == 0 (
    echo Stopped running instance of QRBarcode
    timeout /t 2 /nobreak >nul
) else (
    echo No running instances found
)

:: Copy DLLs
echo.
echo Copying DLLs...
for %%F in ("%DLL_SOURCE%\*.dll") do (
    set "FILENAME=%%~nxF"
    if exist "%DLL_DEST%\!FILENAME!" (
        echo Updating: !FILENAME!
        del /F /Q "%DLL_DEST%\!FILENAME!" >nul 2>&1
    ) else (
        echo Installing: !FILENAME!
    )
    copy /Y "%%F" "%DLL_DEST%" >nul
    if !errorLevel! neq 0 (
        echo ERROR: Failed to copy !FILENAME!
        echo Please ensure the file is not in use and you have sufficient permissions.
    )
)

echo.
echo Verifying DLL installation...
set "MISSING_FILES=0"
for %%F in (msvcp140.dll vcruntime140.dll) do (
    if not exist "%DLL_DEST%\%%F" (
        echo ERROR: Missing required DLL: %%F
        set /a MISSING_FILES+=1
    )
)

if %ARCH%==x64 (
    if not exist "%DLL_DEST%\vcruntime140_1.dll" (
        echo ERROR: Missing required DLL: vcruntime140_1.dll
        set /a MISSING_FILES+=1
    )
)

if %ARCH%==arm64 (
    if not exist "%DLL_DEST%\vcruntime140_1.dll" (
        echo ERROR: Missing required DLL: vcruntime140_1.dll
        set /a MISSING_FILES+=1
    )
)

echo.
if %MISSING_FILES% gtr 0 (
    echo WARNING: Some required DLLs are missing. The application may not work correctly.
    echo Please ensure all necessary Visual C++ Redistributable DLLs are present.
) else (
    echo DLL setup completed successfully!
)

:: Set up additional configuration for ARM systems
if %IS_ARM%==1 (
    echo.
    echo Setting up ARM-specific configuration...
    echo Setting environment variables for ARM compatibility...
    setx FLUTTER_WINDOWS_FORCE_ANGLE 1 >nul
    setx FLUTTER_WINDOWS_DEBUG true >nul
    setx ENABLE_FLUTTER_DESKTOP_EMBEDDING 1 >nul
    setx FLUTTER_FORCE_SOFTWARE_RENDERING true >nul
    setx FLUTTER_WINDOW_FORCE_DCOMP true >nul
    echo ARM configuration completed
)

echo.
echo Setup complete! You can now run qrbarcode.exe
if %IS_ARM%==1 (
    echo Note: On ARM systems, use launch_arm.bat for optimal performance
)
echo.
pause 