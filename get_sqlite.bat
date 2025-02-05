@echo off
setlocal EnableDelayedExpansion

echo Downloading SQLite DLL...
echo.

:: Create temp directory if it doesn't exist
set "TEMP_DIR=%TEMP%\SQLite_Download"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Latest SQLite version URLs (as of 2024)
set "URLS=https://www.sqlite.org/2024/sqlite-dll-win64-x64-3450100.zip https://www.sqlite.org/2024/sqlite-dll-win64-x64-3450000.zip https://www.sqlite.org/2024/sqlite-dll-win64-x64-3440200.zip https://www.sqlite.org/2023/sqlite-dll-win64-x64-3440000.zip"

set "SUCCESS=0"
for %%U in (%URLS%) do (
    if !SUCCESS!==0 (
        echo Trying %%U...
        powershell -Command "& { try { $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile('%%U', '%TEMP_DIR%\sqlite.zip'); Write-Output 'success' } catch { Write-Output $_.Exception.Message } }" > "%TEMP_DIR%\result.txt"
        set /p RESULT=<"%TEMP_DIR%\result.txt"
        if "!RESULT!"=="success" (
            echo Download successful!
            powershell -Command "Expand-Archive -Path '%TEMP_DIR%\sqlite.zip' -DestinationPath '%TEMP_DIR%' -Force"
            if exist "%TEMP_DIR%\sqlite3.dll" (
                copy /Y "%TEMP_DIR%\sqlite3.dll" "." >nul
                set "SUCCESS=1"
                echo SQLite DLL has been downloaded and extracted successfully.
            )
        )
    )
)

if !SUCCESS!==0 (
    echo Failed to download from SQLite.org
    echo.
    echo Checking Windows System directories...
    
    if exist "C:\Windows\System32\sqlite3.dll" (
        copy /Y "C:\Windows\System32\sqlite3.dll" "." >nul
        echo Copied sqlite3.dll from System32
        set "SUCCESS=1"
    ) else if exist "C:\Windows\SysWOW64\sqlite3.dll" (
        copy /Y "C:\Windows\SysWOW64\sqlite3.dll" "." >nul
        echo Copied sqlite3.dll from SysWOW64
        set "SUCCESS=1"
    )
)

if !SUCCESS!==0 (
    echo.
    echo Unable to obtain sqlite3.dll automatically.
    echo Please download it manually from:
    echo https://www.sqlite.org/download.html
    echo Look for "Precompiled Binaries for Windows" and download the DLL package.
) else (
    echo.
    echo sqlite3.dll is now available in the current directory.
)

:: Clean up
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"

pause 