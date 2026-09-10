@echo off
setlocal DisableDelayedExpansion
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0T5-Launcher\Configure-SSD.ps1"
set "launcherExit=%errorlevel%"
pause
exit /b %launcherExit%
