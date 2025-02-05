@echo off
setlocal EnableDelayedExpansion

:: Fix timestamp format to avoid space issues
set "TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "LOG_FILE=%LOCALAPPDATA%\QRBarcode\qrbarcode_log_%TIMESTAMP%.txt"

:: Create log directory if it doesn't exist
if not exist "%LOCALAPPDATA%\QRBarcode" mkdir "%LOCALAPPDATA%\QRBarcode"

:: Start logging
call :log "QRBarcode Launch Log - %date% %time%"
call :log "=================================="
call :log "System Information:"
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type" >> "%LOG_FILE%"
call :log ""

:: Kill any existing instances
call :log "Checking for existing instances..."
taskkill /F /IM qrbarcode.exe /T >nul 2>&1
timeout /t 2 /nobreak >nul

:: Set environment variables
call :log "Setting environment variables..."
set "FLUTTER_WINDOWS_FORCE_ANGLE=1"
set "FLUTTER_WINDOWS_DEBUG=true"
set "ENABLE_FLUTTER_DESKTOP_EMBEDDING=1"
set "FLUTTER_FORCE_SOFTWARE_RENDERING=true"
set "FLUTTER_WINDOW_FORCE_DCOMP=true"
set "FLUTTER_ENGINE_SWITCH_DEBUG=true"
set "VERBOSE_LOGGING=true"
set "FLUTTER_LOG_LEVEL=verbose"

:: Set and log paths
set "FLUTTER_ASSET_DIR=%~dp0data\flutter_assets"
set "FLUTTER_ROOT_DIR=%~dp0"
set "APP_DATA_DIR=%LOCALAPPDATA%\QRBarcode"

call :log "Environment Setup:"
call :log "FLUTTER_ASSET_DIR: %FLUTTER_ASSET_DIR%"
call :log "FLUTTER_ROOT_DIR: %FLUTTER_ROOT_DIR%"
call :log "APP_DATA_DIR: %APP_DATA_DIR%"
call :log "Current Directory: %CD%"
call :log ""

:: Create directories
if not exist "%APP_DATA_DIR%" mkdir "%APP_DATA_DIR%"
if not exist "%APP_DATA_DIR%\temp" mkdir "%APP_DATA_DIR%\temp"
if not exist "%APP_DATA_DIR%\logs" mkdir "%APP_DATA_DIR%\logs"

:: Check DLL files
call :log "Checking DLL files:"
for %%F in (flutter_windows.dll MSVCP140.dll VCRUNTIME140.dll VCRUNTIME140_1.dll sqlite3.dll) do (
    if exist "%~dp0%%F" (
        call :log "[√] Found %%F"
    ) else (
        call :log "[X] Missing %%F"
        if "%%F"=="sqlite3.dll" (
            call :log "Attempting to download SQLite DLL..."
            
            :: Try multiple download sources
            set "SQLITE_SUCCESS=0"
            
            :: Try downloading from SQLite.org (multiple versions)
            for %%V in (3450100 3450000 3440200 3440100 3440000) do (
                if !SQLITE_SUCCESS!==0 (
                    call :log "Trying SQLite version %%V..."
                    powershell -Command "& { try { $webClient = New-Object System.Net.WebClient; $url = 'https://www.sqlite.org/2024/sqlite-dll-win64-x64-%%V.zip'; $zipPath = '%APP_DATA_DIR%\temp\sqlite.zip'; $webClient.DownloadFile($url, $zipPath); if (Test-Path $zipPath) { Expand-Archive -Path $zipPath -DestinationPath '%APP_DATA_DIR%\temp' -Force; if (Test-Path '%APP_DATA_DIR%\temp\sqlite3.dll') { Copy-Item '%APP_DATA_DIR%\temp\sqlite3.dll' '%~dp0' -Force; Write-Output 'success' } } } catch { Write-Output $_.Exception.Message } }" > "%APP_DATA_DIR%\temp\download_result.txt"
                    set /p DOWNLOAD_RESULT=<"%APP_DATA_DIR%\temp\download_result.txt"
                    if "!DOWNLOAD_RESULT!"=="success" set "SQLITE_SUCCESS=1"
                )
            )
            
            :: If download failed, try copying from System32
            if !SQLITE_SUCCESS!==0 (
                call :log "Download failed, checking System32..."
                if exist "C:\Windows\System32\sqlite3.dll" (
                    copy /Y "C:\Windows\System32\sqlite3.dll" "%~dp0" >nul 2>&1
                    if exist "%~dp0sqlite3.dll" (
                        call :log "[√] Copied sqlite3.dll from System32"
                        set "SQLITE_SUCCESS=1"
                    )
                )
            )
            
            :: If still no success, try Windows\SysWOW64
            if !SQLITE_SUCCESS!==0 (
                if exist "C:\Windows\SysWOW64\sqlite3.dll" (
                    copy /Y "C:\Windows\SysWOW64\sqlite3.dll" "%~dp0" >nul 2>&1
                    if exist "%~dp0sqlite3.dll" (
                        call :log "[√] Copied sqlite3.dll from SysWOW64"
                        set "SQLITE_SUCCESS=1"
                    )
                )
            )
            
            :: Clean up temp files
            if exist "%APP_DATA_DIR%\temp\sqlite.zip" del /f /q "%APP_DATA_DIR%\temp\sqlite.zip"
            if exist "%APP_DATA_DIR%\temp\sqlite3.dll" del /f /q "%APP_DATA_DIR%\temp\sqlite3.dll"
            
            if !SQLITE_SUCCESS!==0 (
                call :log "[X] Failed to obtain sqlite3.dll"
                set "MISSING_DLL=1"
            ) else (
                call :log "[√] Successfully installed sqlite3.dll"
            )
        ) else (
            set "MISSING_DLL=1"
        )
    )
)

if defined MISSING_DLL (
    call :log "ERROR: Missing required DLLs. Please ensure all files are present."
    goto :error
)

:: Set SQLite path explicitly
set "PATH=%~dp0;%PATH%"
set "SQLITE3_LIBRARY_PATH=%~dp0sqlite3.dll"

:: Check Flutter assets
call :log "Checking Flutter assets:"
if exist "%FLUTTER_ASSET_DIR%" (
    call :log "[√] Flutter assets directory found"
    dir "%FLUTTER_ASSET_DIR%" >> "%LOG_FILE%"
) else (
    call :log "[X] Flutter assets directory missing"
    goto :error
)

:: Launch application with output redirection
call :log "Launching application..."
call :log "Command: qrbarcode.exe with flags"

:: Capture both stdout and stderr
(
    "%~dp0qrbarcode.exe" ^
        --disable-gpu ^
        --enable-software-rendering ^
        --force-dcomp ^
        --no-sandbox ^
        --working-directory="%CD%" ^
        --flutter-assets-dir="%FLUTTER_ASSET_DIR%" ^
        --local-storage-path="%APP_DATA_DIR%" ^
        --verbose-logging
) > "%APP_DATA_DIR%\stdout.log" 2> "%APP_DATA_DIR%\stderr.log"

set EXIT_CODE=%errorlevel%

:: Check process and window status
call :log "Process Status:"
powershell -Command "Get-Process qrbarcode -ErrorAction SilentlyContinue | Format-List Id, ProcessName, StartTime, CPU, WorkingSet, MainWindowTitle, MainWindowHandle" >> "%LOG_FILE%"

:: Check if process is running but window is not visible
powershell -Command "$p = Get-Process qrbarcode -ErrorAction SilentlyContinue; if($p -and $p.MainWindowHandle -eq 0) { Write-Output 'WARNING: Process is running but window handle is 0 (window might be hidden)' }" >> "%LOG_FILE%"

:: Append stdout and stderr to main log
call :log "Standard Output:"
type "%APP_DATA_DIR%\stdout.log" >> "%LOG_FILE%"
call :log "Standard Error:"
type "%APP_DATA_DIR%\stderr.log" >> "%LOG_FILE%"

if %EXIT_CODE% neq 0 goto :error

call :log "Application launched with exit code: %EXIT_CODE%"
call :log "If window is not visible:"
call :log "1. Check Task Manager (Apps section)"
call :log "2. Press Alt+Tab"
call :log "3. Press Win+Tab to check virtual desktops"
call :log "4. Move mouse to screen edges"
goto :end

:error
call :log "Error occurred. Exit code: %EXIT_CODE%"
call :log "Please check the log file for details: %LOG_FILE%"

:end
echo Log file created at: %LOG_FILE%
echo Please check the log file for detailed information.
pause
exit /b

:log
echo %~1
echo %~1 >> "%LOG_FILE%"
goto :eof 