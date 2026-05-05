@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
set "INSTALL_PS1=%SCRIPT_DIR%Install-OpenClawWindowsNative.ps1"

if not exist "%INSTALL_PS1%" (
  echo [ERROR] Missing installer payload: %INSTALL_PS1%
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%OPENCLAW_SKIP_PAUSE%"=="1" pause
exit /b %EXIT_CODE%
