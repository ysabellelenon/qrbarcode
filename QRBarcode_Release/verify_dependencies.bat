@echo off
setlocal EnableDelayedExpansion

echo Checking and fixing dependencies...
echo.

:: Create temp directory
set "TEMP_DIR=%TEMP%\QRBarcode_Deps"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Check SQLite
if not exist "%~dp0sqlite3.dll" (
    echo SQLite DLL missing, downloading...
    :: Try multiple known SQLite URLs
    set "SUCCESS=0"
    
    :: Try URL 1
    if !SUCCESS!==0 (
        powershell -Command "& { try { $webClient = New-Object System.Net.WebClient; $url = 'https://www.sqlite.org/2024/sqlite-dll-win64-x64-3440200.zip'; $zipPath = '%TEMP_DIR%\sqlite.zip'; $webClient.DownloadFile($url, $zipPath); if (Test-Path $zipPath) { Write-Output 'success' } } catch { Write-Output $_.Exception.Message } }" > "%TEMP_DIR%\download_result.txt"
        set /p RESULT=<"%TEMP_DIR%\download_result.txt"
        if "!RESULT!"=="success" set "SUCCESS=1"
    )
    
    :: Try URL 2 if first failed
    if !SUCCESS!==0 (
        powershell -Command "& { try { $webClient = New-Object System.Net.WebClient; $url = 'https://www.sqlite.org/2023/sqlite-dll-win64-x64-3430200.zip'; $zipPath = '%TEMP_DIR%\sqlite.zip'; $webClient.DownloadFile($url, $zipPath); if (Test-Path $zipPath) { Write-Output 'success' } } catch { Write-Output $_.Exception.Message } }" > "%TEMP_DIR%\download_result.txt"
        set /p RESULT=<"%TEMP_DIR%\download_result.txt"
        if "!RESULT!"=="success" set "SUCCESS=1"
    )
    
    :: Process the downloaded file if successful
    if !SUCCESS!==1 (
        powershell -Command "& { Expand-Archive -Path '%TEMP_DIR%\sqlite.zip' -DestinationPath '%TEMP_DIR%' -Force }"
        if exist "%TEMP_DIR%\sqlite3.dll" (
            copy /Y "%TEMP_DIR%\sqlite3.dll" "%~dp0" >nul
            echo [√] Successfully installed sqlite3.dll
        ) else (
            echo [X] Failed to extract sqlite3.dll
        )
    ) else (
        echo [X] Failed to download SQLite. Trying alternative method...
        
        :: Try to copy from Windows System32 if available
        if exist "C:\Windows\System32\sqlite3.dll" (
            copy /Y "C:\Windows\System32\sqlite3.dll" "%~dp0" >nul
            echo [√] Copied sqlite3.dll from System32
        ) else (
            echo [X] Could not find sqlite3.dll in System32
            echo Please download sqlite3.dll manually from https://www.sqlite.org/download.html
        )
    )
)

:: Check Visual C++ Runtime DLLs
set "MISSING_VCRUNTIME=0"
for %%F in (MSVCP140.dll VCRUNTIME140.dll VCRUNTIME140_1.dll) do (
    if not exist "%~dp0%%F" (
        echo Missing %%F, copying from System32...
        if exist "C:\Windows\System32\%%F" (
            copy /Y "C:\Windows\System32\%%F" "%~dp0" >nul
            if exist "%~dp0%%F" (
                echo [√] Successfully copied %%F
            ) else (
                echo [X] Failed to copy %%F
                set "MISSING_VCRUNTIME=1"
            )
        ) else (
            echo [X] %%F not found in System32
            set "MISSING_VCRUNTIME=1"
        )
    )
)

if %MISSING_VCRUNTIME%==1 (
    echo Some Visual C++ Runtime DLLs are missing.
    echo Please install Visual C++ Redistributable from:
    echo https://aka.ms/vs/17/release/vc_redist.x64.exe
)

:: Check Flutter DLLs
if not exist "%~dp0flutter_windows.dll" (
    echo [X] Missing flutter_windows.dll
    echo This file should be part of the release build
)

:: Check data directory
if not exist "%~dp0data\flutter_assets" (
    echo [X] Missing Flutter assets directory
    echo This directory should be part of the release build
)

:: Create necessary directories
if not exist "%LOCALAPPDATA%\QRBarcode" mkdir "%LOCALAPPDATA%\QRBarcode"
if not exist "%LOCALAPPDATA%\QRBarcode\temp" mkdir "%LOCALAPPDATA%\QRBarcode\temp"

:: Set environment variables (user level only, no admin required)
echo.
echo Setting up environment variables...
powershell -Command "& { [Environment]::SetEnvironmentVariable('SQLITE3_LIBRARY_PATH', '%~dp0sqlite3.dll', 'User') }"
echo [√] Set SQLITE3_LIBRARY_PATH (user level)

:: Set PATH to include current directory for this session
set "PATH=%~dp0;%PATH%"

:: Clean up
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"

echo.
echo Dependency check complete.
echo If any errors were reported above, please fix them before running the application.
pause 