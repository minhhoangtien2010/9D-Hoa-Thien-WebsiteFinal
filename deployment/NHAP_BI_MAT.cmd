@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Import-Secrets.ps1" %*
pause
