@echo off
echo Starting release build process...
echo.

:: Kill any running instances of qrbarcode
echo Checking for running instances...
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
if errorlevel 1 (
    echo No running instances found
) else (
    echo Closed running instances
)
timeout /t 2 /nobreak >nul

echo Cleaning build directory...
call flutter clean
if errorlevel 1 (
    echo Error during clean. Press any key to exit.
    pause
    exit /b 1
)

echo.
echo Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo Error getting dependencies. Press any key to exit.
    pause
    exit /b 1
)

echo.
echo Building Windows release...
:: Check if running on ARM
wmic computersystem get manufacturer | findstr /i "Parallels" >nul
if not errorlevel 1 (
    echo Detected Parallels ARM environment
    echo Building with ARM64 optimizations...
    
    :: Set environment variables for ARM build
    set "FLUTTER_TARGET_PLATFORM=windows-arm64"
    set "FLUTTER_WINDOWS_DEBUG=true"
    set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
    set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"
    
    :: Clean any existing build files
    if exist "build\windows" rd /s /q "build\windows"
    
    :: Create ARM64 build directory
    mkdir "build\windows\arm64\runner\Release" 2>nul
    
    :: Build with ARM64 configuration
    call flutter build windows --release ^
        --dart-define=FLUTTER_ARM=true ^
        --dart-define=FLUTTER_FORCE_SOFTWARE_RENDERING=true ^
        --dart-define=FLUTTER_WINDOW_FORCE_DCOMP=true
    
    :: Set the build directory for ARM64
    set "BUILD_DIR=build\windows\arm64\runner\Release"
) else (
    call flutter build windows --release
    set "BUILD_DIR=build\windows\x64\runner\Release"
)
if errorlevel 1 (
    echo Error during build. Press any key to exit.
    pause
    exit /b 1
)

echo.
echo Creating QRBarcode_Release directory if it doesn't exist...
if not exist "QRBarcode_Release" (
    mkdir QRBarcode_Release
    echo Created new QRBarcode_Release directory
)

echo.
echo Updating application files...
echo Copying core application files...

:: First, verify source files exist
if not exist "%BUILD_DIR%\qrbarcode.exe" (
    echo Error: Build files not found in %BUILD_DIR%
    echo Please ensure the build completed successfully.
    pause
    exit /b 1
)

:: Core executable and DLLs
copy /Y "%BUILD_DIR%\qrbarcode.exe" "QRBarcode_Release\" >nul
copy /Y "%BUILD_DIR%\flutter_windows.dll" "QRBarcode_Release\" >nul
copy /Y "%BUILD_DIR%\window_size_plugin.dll" "QRBarcode_Release\" >nul
copy /Y "%BUILD_DIR%\printing_plugin.dll" "QRBarcode_Release\" >nul
copy /Y "%BUILD_DIR%\pdfium.dll" "QRBarcode_Release\" >nul

:: Copy SQLite DLL from Flutter cache or download if needed
set "SQLITE_SOURCE=%LOCALAPPDATA%\flutter\cache\artifacts\engine\windows-x64\sqlite3.dll"
if exist "%SQLITE_SOURCE%" (
    copy /Y "%SQLITE_SOURCE%" "QRBarcode_Release\" >nul
    echo [√] Copied sqlite3.dll from Flutter cache
) else (
    echo Downloading sqlite3.dll...
    powershell -Command "& { $webClient = New-Object System.Net.WebClient; $url = 'https://www.sqlite.org/2023/sqlite-dll-win64-x64-3430200.zip'; $zipPath = '%TEMP%\sqlite.zip'; $webClient.DownloadFile($url, $zipPath); Expand-Archive -Path $zipPath -DestinationPath '%TEMP%\sqlite' -Force; Copy-Item '%TEMP%\sqlite\sqlite3.dll' 'QRBarcode_Release\' -Force; Remove-Item -Path '%TEMP%\sqlite' -Recurse -Force; Remove-Item $zipPath }"
)

:: Update data directory
if exist "QRBarcode_Release\data" (
    echo Updating data directory...
    rd /s /q "QRBarcode_Release\data"
)
xcopy /E /I /Y "%BUILD_DIR%\data" "QRBarcode_Release\data\"

:: Ensure Visual C++ Runtime DLLs are present (ARM64 versions if needed)
echo Checking Visual C++ Runtime DLLs...
wmic computersystem get manufacturer | findstr /i "Parallels" >nul
if not errorlevel 1 (
    :: ARM64 DLLs
    if exist "C:\Windows\System32\arm64\MSVCP140.dll" (
        copy /Y "C:\Windows\System32\arm64\MSVCP140.dll" "QRBarcode_Release\" >nul
        copy /Y "C:\Windows\System32\arm64\VCRUNTIME140.dll" "QRBarcode_Release\" >nul
        copy /Y "C:\Windows\System32\arm64\VCRUNTIME140_1.dll" "QRBarcode_Release\" >nul
    ) else (
        echo WARNING: ARM64 Visual C++ Runtime DLLs not found
        echo Please install the ARM64 Visual C++ Redistributable
    )
) else (
    :: x64 DLLs
    copy /Y "C:\Windows\System32\MSVCP140.dll" "QRBarcode_Release\" >nul
    copy /Y "C:\Windows\System32\VCRUNTIME140.dll" "QRBarcode_Release\" >nul
    copy /Y "C:\Windows\System32\VCRUNTIME140_1.dll" "QRBarcode_Release\" >nul
)

:: Ensure launch scripts are present and updated
echo Updating launch scripts...

:: Create the ARM-specific launch script
echo Creating ARM-optimized launch script...
(
echo @echo off
echo cd /d "%%~dp0"
echo.
echo :: Set environment variables for ARM/Parallels compatibility
echo set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
echo set "FLUTTER_WINDOWS_DEBUG=true"
echo set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"
echo set "FLUTTER_FORCE_SOFTWARE_RENDERING=true"
echo set "FLUTTER_WINDOW_FORCE_DCOMP=true"
echo.
echo :: Create required directories
echo set "APP_DATA_DIR=%%LOCALAPPDATA%%\QRBarcode"
echo if not exist "%%APP_DATA_DIR%%" mkdir "%%APP_DATA_DIR%%"
echo.
echo echo Starting QRBarcode with ARM optimizations...
echo echo Please wait while the application initializes...
echo.
echo :: Launch with optimized flags
echo start "" /WAIT "%%~dp0qrbarcode.exe" --disable-gpu --enable-software-rendering --force-dcomp --no-sandbox
echo.
echo if errorlevel 1 ^(
echo     echo Application failed to start. Please check the logs.
echo     pause
echo ^)
) > "QRBarcode_Release\launch_arm.bat"

copy /Y "run_with_log.bat" "QRBarcode_Release\" >nul
copy /Y "launch_virtual.bat" "QRBarcode_Release\" >nul
copy /Y "check_logs.ps1" "QRBarcode_Release\" >nul

:: Create README if it doesn't exist
if not exist "QRBarcode_Release\README.txt" (
    echo Creating README file...
    echo QRBarcode Windows Application > "QRBarcode_Release\README.txt"
    echo ========================== >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo For ARM/Parallels users: >> "QRBarcode_Release\README.txt"
    echo - First try: launch_arm.bat (recommended for ARM systems) >> "QRBarcode_Release\README.txt"
    echo - Alternative: launch_virtual.bat >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo If the window doesn't appear: >> "QRBarcode_Release\README.txt"
    echo 1. Try pressing Alt+Tab to switch windows >> "QRBarcode_Release\README.txt"
    echo 2. Check the taskbar for hidden windows >> "QRBarcode_Release\README.txt"
    echo 3. Try running with different launch scripts >> "QRBarcode_Release\README.txt"
    echo 4. Make sure Visual C++ Redistributable is installed >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Troubleshooting: >> "QRBarcode_Release\README.txt"
    echo - Run check_logs.ps1 for diagnostics >> "QRBarcode_Release\README.txt"
    echo - Use run_with_log.bat for detailed logging >> "QRBarcode_Release\README.txt"
)

echo.
echo Verifying required files...
cd QRBarcode_Release
echo Checking for required files:
set MISSING_FILES=0
if exist qrbarcode.exe (echo [√] Found qrbarcode.exe) else (echo [X] Missing qrbarcode.exe && set MISSING_FILES=1)
if exist flutter_windows.dll (echo [√] Found flutter_windows.dll) else (echo [X] Missing flutter_windows.dll && set MISSING_FILES=1)
if exist sqlite3.dll (echo [√] Found sqlite3.dll) else (echo [X] Missing sqlite3.dll && set MISSING_FILES=1)
if exist MSVCP140.dll (echo [√] Found MSVCP140.dll) else (echo [X] Missing MSVCP140.dll && set MISSING_FILES=1)
if exist VCRUNTIME140.dll (echo [√] Found VCRUNTIME140.dll) else (echo [X] Missing VCRUNTIME140.dll && set MISSING_FILES=1)
if exist VCRUNTIME140_1.dll (echo [√] Found VCRUNTIME140_1.dll) else (echo [X] Missing VCRUNTIME140_1.dll && set MISSING_FILES=1)
if exist data\flutter_assets (echo [√] Found flutter_assets) else (echo [X] Missing flutter_assets && set MISSING_FILES=1)

echo.
if %MISSING_FILES%==1 (
    echo WARNING: Some required files are missing!
) else (
    echo All required files are present!
)

echo.
echo Release build process completed!
echo Your release files have been updated in the "QRBarcode_Release" directory
echo.
cd ..
pause 