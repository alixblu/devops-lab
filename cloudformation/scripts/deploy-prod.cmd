@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-prod.ps1"
if errorlevel 1 exit /b 1

endlocal
