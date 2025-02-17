@echo off
:: ==========================================================
:: QRBarcode Release Build Script
:: ==========================================================
:: Usage:
::   release.bat [flags]
::
:: Flags:
::   --clean     : Force clean build (removes build files and triggers pub get)
::   --pub-get   : Force flutter pub get (update dependencies)
::   --force     : Force update release files
::
:: Notes:
::   - This script is typically called by create_release.bat
::   - Can be run directly for testing build process
::   - By default, clean and pub get are skipped for faster builds
::   - pub get runs automatically if pubspec.yaml was modified
::   - --clean flag automatically triggers pub get
:: ==========================================================

echo Starting release build process...
echo.

:: Add flags at the start of the script
set "FORCE_UPDATE="
set "DO_CLEAN="
set "DO_PUB_GET="

:parse_args
if "%1"=="" goto end_parse
if "%1"=="--force" set "FORCE_UPDATE=1"
if "%1"=="--clean" set "DO_CLEAN=1"
if "%1"=="--pub-get" set "DO_PUB_GET=1"
shift
goto parse_args
:end_parse

:: Kill any running instances of qrbarcode
echo Checking for running instances...
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
if errorlevel 1 (
    echo No running instances found
) else (
    echo Closed running instances
)
timeout /t 2 /nobreak >nul

:: Only clean if --clean flag is provided
if defined DO_CLEAN (
    echo Cleaning build directory...
    call flutter clean
    if errorlevel 1 (
        echo Error during clean. Press any key to exit.
        pause
        exit /b 1
    )
    :: Force pub get after clean
    set "DO_PUB_GET=1"
) else (
    echo Skipping clean ^(use --clean to force clean^)
)

:: Check if pub get is needed
set "NEED_PUB_GET="
if defined DO_PUB_GET (
    set "NEED_PUB_GET=1"
) else if exist ".dart_tool\package_config.json" (
    :: Check if pubspec.yaml is newer than package_config.json
    for /f %%i in ('dir /b /o:d ".dart_tool\package_config.json" "pubspec.yaml" ^| find "pubspec.yaml"') do (
        set "NEED_PUB_GET=1"
        echo Detected changes in pubspec.yaml, will run pub get
    )
)

:: Run pub get only if needed
if defined NEED_PUB_GET (
    echo.
    echo Getting dependencies...
    call flutter pub get
    if errorlevel 1 (
        echo Error getting dependencies. Press any key to exit.
        pause
        exit /b 1
    )
) else (
    echo Skipping pub get ^(use --pub-get to force pub get^)
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
for %%F in (
    flutter_windows.dll 
    window_size_plugin.dll 
    printing_plugin.dll 
    pdfium.dll 
    screen_retriever_plugin.dll 
    window_manager_plugin.dll
) do (
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

:: Ensure DLLs directory structure is maintained
echo Organizing DLLs...
if not exist "QRBarcode_Release\dlls" mkdir "QRBarcode_Release\dlls"
if not exist "QRBarcode_Release\dlls\x64" mkdir "QRBarcode_Release\dlls\x64"
if not exist "QRBarcode_Release\dlls\x86" mkdir "QRBarcode_Release\dlls\x86"
if not exist "QRBarcode_Release\dlls\arm64" mkdir "QRBarcode_Release\dlls\arm64"

:: Move existing DLLs to architecture-specific folders
echo Moving DLLs to architecture folders...
:: x64 DLLs
for %%F in (msvcp140.dll vcruntime140.dll vcruntime140_1.dll) do (
    if exist "QRBarcode_Release\%%F" (
        move /Y "QRBarcode_Release\%%F" "QRBarcode_Release\dlls\x64\" >nul
        echo [+] Moved %%F to x64 folder
    )
)

:: Copy setup_dlls.bat
echo Adding DLL setup script...
copy /Y "setup_dlls.bat" "QRBarcode_Release\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy setup_dlls.bat
    echo Please ensure the file exists and is not locked
    pause
    exit /b 1
) else (
    echo [+] Added setup_dlls.bat
)

:: Update README to include information about setup_dlls.bat
echo Updating README...
echo. >> "QRBarcode_Release\README.txt"
echo DLL Setup >> "QRBarcode_Release\README.txt"
echo ========= >> "QRBarcode_Release\README.txt"
echo If you encounter any DLL-related issues: >> "QRBarcode_Release\README.txt"
echo 1. Run setup_dlls.bat as administrator >> "QRBarcode_Release\README.txt"
echo 2. This script will automatically detect your system architecture >> "QRBarcode_Release\README.txt"
echo 3. It will install the appropriate Visual C++ Runtime DLLs >> "QRBarcode_Release\README.txt"
echo. >> "QRBarcode_Release\README.txt"

:: Ensure Visual C++ Runtime DLLs are present
echo Copying Visual C++ Runtime DLLs...
wmic os get caption | findstr "ARM" >nul
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
    echo Thank you for using QRBarcode! This document contains important information about installing, running, and maintaining your application. >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Installation >> "QRBarcode_Release\README.txt"
    echo ----------- >> "QRBarcode_Release\README.txt"
    echo 1. Extract the ZIP file to your desired location >> "QRBarcode_Release\README.txt"
    echo    - You can place the folder anywhere on your system >> "QRBarcode_Release\README.txt"
    echo    - IMPORTANT: Once you run the application and create a database, DO NOT move the application folder >> "QRBarcode_Release\README.txt"
    echo    - The database will be created in a 'databases' folder outside the application directory >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo 2. First-Time Setup: >> "QRBarcode_Release\README.txt"
    echo    - Run setup_dlls.bat as administrator ^(if you encounter any DLL-related issues^) >> "QRBarcode_Release\README.txt"
    echo    - The script will automatically detect your system architecture and install appropriate DLLs >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Running the Application >> "QRBarcode_Release\README.txt"
    echo --------------------- >> "QRBarcode_Release\README.txt"
    echo 1. Regular Systems: >> "QRBarcode_Release\README.txt"
    echo    - Double-click qrbarcode.exe to start the application >> "QRBarcode_Release\README.txt"
    echo    - First run will create necessary database files >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo 2. ARM Systems: >> "QRBarcode_Release\README.txt"
    echo    - Use launch_arm.bat for optimal performance >> "QRBarcode_Release\README.txt"
    echo    - This script includes special optimizations for ARM processors >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Database Location >> "QRBarcode_Release\README.txt"
    echo --------------- >> "QRBarcode_Release\README.txt"
    echo IMPORTANT: The application creates and maintains a SQLite database in: >> "QRBarcode_Release\README.txt"
    echo %%LOCALAPPDATA%%\QRBarcode\databases\ >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo - DO NOT move the application folder after database creation >> "QRBarcode_Release\README.txt"
    echo - Database contains all your QR code data and settings >> "QRBarcode_Release\README.txt"
    echo - If you need to move the application: >> "QRBarcode_Release\README.txt"
    echo   1. Export any important data first >> "QRBarcode_Release\README.txt"
    echo   2. Close the application >> "QRBarcode_Release\README.txt"
    echo   3. Move the folder to the new location >> "QRBarcode_Release\README.txt"
    echo   4. Run the application ^(it will create a new database^) >> "QRBarcode_Release\README.txt"
    echo   5. Import your data back >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Updates >> "QRBarcode_Release\README.txt"
    echo ------- >> "QRBarcode_Release\README.txt"
    echo 1. Automatic Updates: >> "QRBarcode_Release\README.txt"
    echo    - The application will check for updates automatically >> "QRBarcode_Release\README.txt"
    echo    - When available, an update notification will appear in the About screen >> "QRBarcode_Release\README.txt"
    echo    - Click "Check for Updates" to manually check >> "QRBarcode_Release\README.txt"
    echo    - Follow the prompts to download and install updates >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo 2. Manual Updates: >> "QRBarcode_Release\README.txt"
    echo    - Download the latest version from the releases page >> "QRBarcode_Release\README.txt"
    echo    - Extract to a new location >> "QRBarcode_Release\README.txt"
    echo    - Copy your database from the old installation if needed >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Troubleshooting >> "QRBarcode_Release\README.txt"
    echo -------------- >> "QRBarcode_Release\README.txt"
    echo 1. DLL Issues: >> "QRBarcode_Release\README.txt"
    echo    - Run setup_dlls.bat as administrator >> "QRBarcode_Release\README.txt"
    echo    - This script will automatically fix most DLL-related problems >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo 2. Display Issues: >> "QRBarcode_Release\README.txt"
    echo    - For ARM systems, use launch_arm.bat >> "QRBarcode_Release\README.txt"
    echo    - Try pressing Alt+Tab if the window doesn't appear >> "QRBarcode_Release\README.txt"
    echo    - Check the taskbar for hidden windows >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo 3. Database Issues: >> "QRBarcode_Release\README.txt"
    echo    - Ensure the application has write permissions to %%LOCALAPPDATA%%\QRBarcode >> "QRBarcode_Release\README.txt"
    echo    - Do not modify the databases folder manually >> "QRBarcode_Release\README.txt"
    echo    - Keep regular backups of important data >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo System Requirements >> "QRBarcode_Release\README.txt"
    echo ------------------ >> "QRBarcode_Release\README.txt"
    echo - Windows 10 or later >> "QRBarcode_Release\README.txt"
    echo - Visual C++ Redistributable 2015-2022 >> "QRBarcode_Release\README.txt"
    echo - Minimum 4GB RAM recommended >> "QRBarcode_Release\README.txt"
    echo - 100MB free disk space for installation >> "QRBarcode_Release\README.txt"
    echo - Additional space for database ^(varies with usage^) >> "QRBarcode_Release\README.txt"
    echo. >> "QRBarcode_Release\README.txt"
    echo Note: Keep this README file for future reference. It contains important information about your installation and troubleshooting steps. >> "QRBarcode_Release\README.txt"
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