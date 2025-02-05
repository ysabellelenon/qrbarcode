@echo off
cd /d "%~dp0"

:: Set minimal required environment
set "LOCALAPPDATA_DIR=%LOCALAPPDATA%\QRBarcode"
if not exist "%LOCALAPPDATA_DIR%" mkdir "%LOCALAPPDATA_DIR%"

:: Try to run with shell execute
powershell -Command "Start-Process '%~dp0qrbarcode.exe' -WorkingDirectory '%~dp0' -WindowStyle Normal" 