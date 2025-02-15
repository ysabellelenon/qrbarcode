@echo off
echo Starting release build process...
echo.

:: Add force update flag at the start of the script
set "FORCE_UPDATE="
if "%1"=="--force" set "FORCE_UPDATE=1"

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
    
    :: Build with ARM64 configuration
    call flutter build windows --release ^
        --dart-define=FLUTTER_ARM=true ^
        --dart-define=FLUTTER_FORCE_SOFTWARE_RENDERING=true ^
        --dart-define=FLUTTER_WINDOW_FORCE_DCOMP=true
) else (
    call flutter build windows --release
)

:: Set build directory based on what actually exists
if exist "build\windows\arm64\runner\Release\qrbarcode.exe" (
    set "BUILD_DIR=build\windows\arm64\runner\Release"
) else (
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

:: First, verify source files exist and set correct build directory
if not exist "%BUILD_DIR%\qrbarcode.exe" (
    echo Warning: Build files not found in %BUILD_DIR%
    echo Trying alternate build directory...
    
    :: Try switching to x64 if we were looking in arm64, or vice versa
    if "%BUILD_DIR%"=="build\windows\arm64\runner\Release" (
        set "BUILD_DIR=build\windows\x64\runner\Release"
    ) else (
        set "BUILD_DIR=build\windows\arm64\runner\Release"
    )
    
    :: Check if the alternate directory works
    if not exist "%BUILD_DIR%\qrbarcode.exe" (
        echo Error: Build files not found in either build directory.
        echo Please ensure the build completed successfully.
        pause
        exit /b 1
    ) else (
        echo Found build files in alternate directory: %BUILD_DIR%
    )
)

:: Core executable and DLLs
echo Copying/updating core files...
if not exist "QRBarcode_Release\qrbarcode.exe" (
    copy /Y "%BUILD_DIR%\qrbarcode.exe" "QRBarcode_Release\" >nul
    echo [+] Copied new qrbarcode.exe
) else if defined FORCE_UPDATE (
    xcopy /Y /D "%BUILD_DIR%\qrbarcode.exe" "QRBarcode_Release\" >nul
    echo [*] Updated qrbarcode.exe
)

:: Only copy DLLs if they don't exist or force update is specified
for %%F in (flutter_windows.dll window_size_plugin.dll printing_plugin.dll pdfium.dll) do (
    if not exist "QRBarcode_Release\%%F" (
        copy /Y "%BUILD_DIR%\%%F" "QRBarcode_Release\" >nul
        echo [+] Copied missing file: %%F
    ) else if defined FORCE_UPDATE (
        xcopy /Y /D "%BUILD_DIR%\%%F" "QRBarcode_Release\" >nul
        echo [*] Updated: %%F
    ) else (
        echo [=] Keeping existing: %%F
    )
)

:: Copy SQLite DLL only if missing
if not exist "QRBarcode_Release\sqlite3.dll" (
    set "SQLITE_SOURCE=%LOCALAPPDATA%\flutter\cache\artifacts\engine\windows-x64\sqlite3.dll"
    if exist "%SQLITE_SOURCE%" (
        copy /Y "%SQLITE_SOURCE%" "QRBarcode_Release\" >nul
        echo [+] Copied missing sqlite3.dll from Flutter cache
    ) else (
        echo Downloading sqlite3.dll...
        powershell -Command "& { $webClient = New-Object System.Net.WebClient; $url = 'https://www.sqlite.org/2023/sqlite-dll-win64-x64-3430200.zip'; $zipPath = '%TEMP%\sqlite.zip'; $webClient.DownloadFile($url, $zipPath); Expand-Archive -Path $zipPath -DestinationPath '%TEMP%\sqlite' -Force; Copy-Item '%TEMP%\sqlite\sqlite3.dll' 'QRBarcode_Release\' -Force; Remove-Item -Path '%TEMP%\sqlite' -Recurse -Force; Remove-Item $zipPath }"
    )
)

:: Update data directory
if exist "QRBarcode_Release\data" (
    echo Updating data directory...
    rd /s /q "QRBarcode_Release\data"
)
xcopy /E /I /Y "%BUILD_DIR%\data" "QRBarcode_Release\data\"

:: Ensure Visual C++ Runtime DLLs are present
echo Copying Visual C++ Runtime DLLs...
wmic computersystem get manufacturer | findstr /i "Parallels" >nul
if not errorlevel 1 (
    :: ARM64 build - copy ARM64 DLLs
    echo Copying ARM64 Visual C++ Runtime DLLs...
    xcopy /Y /I "QRBarcode_Release\dlls\arm64\*.dll" "QRBarcode_Release\" >nul
    if errorlevel 1 (
        echo ERROR: Failed to copy ARM64 DLLs
        echo Please ensure DLLs are extracted using extract_dlls.ps1
        pause
        exit /b 1
    ) else (
        echo [+] Copied ARM64 Visual C++ Runtime DLLs
    )
) else (
    :: x64 build - copy x64 DLLs
    echo Copying x64 Visual C++ Runtime DLLs...
    xcopy /Y /I "QRBarcode_Release\dlls\x64\*.dll" "QRBarcode_Release\" >nul
    if errorlevel 1 (
        echo ERROR: Failed to copy x64 DLLs
        echo Please ensure DLLs are extracted using extract_dlls.ps1
        pause
        exit /b 1
    ) else (
        echo [+] Copied x64 Visual C++ Runtime DLLs
    )
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
echo Creating release archive...
:: Get current date and time in format YYYYMMDD_HHMM
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set ARCHIVE_NAME=QRBarcode_Release_%datetime:~0,8%_%datetime:~8,2%%datetime:~10,2%

:: Create QRBarcode_Release_ZIP directory if it doesn't exist
if not exist "QRBarcode_Release_ZIP" (
    mkdir QRBarcode_Release_ZIP
    echo Created QRBarcode_Release_ZIP directory
)

:: Move back to root directory before creating zip
cd ..

:: Create zip file using PowerShell
powershell -Command "& { Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('QRBarcode_Release', 'QRBarcode_Release_ZIP\%ARCHIVE_NAME%.zip') }"

if exist "QRBarcode_Release_ZIP\%ARCHIVE_NAME%.zip" (
    echo Successfully created archive: QRBarcode_Release_ZIP\%ARCHIVE_NAME%.zip
) else (
    echo Failed to create archive
)

echo.
echo Release build process completed!
echo Your release files have been updated in the "QRBarcode_Release" directory
echo A backup archive has been created as "QRBarcode_Release_ZIP\%ARCHIVE_NAME%.zip"
echo.
pause 