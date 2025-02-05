@echo off
echo Running diagnostic tool...
powershell -ExecutionPolicy Bypass -File "%~dp0check_logs.ps1"
echo.
echo Press any key to view the log file...
pause > nul
start "" notepad.exe "app_diagnostic_%date:~-4,4%-%date:~-10,2%-%date:~-7,2%_%time:~0,2%-%time:~3,2%.txt" 