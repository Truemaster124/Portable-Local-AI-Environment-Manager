@echo off
setlocal DisableDelayedExpansion
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0T5-Launcher\T5Launcher.ps1" -Mode Uninstall
if errorlevel 1 pause
