@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%" || exit /b 1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\Publish-WithToken.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo [DONE] GitHub token publish flow completed.
) else (
  echo [ERROR] GitHub token publish flow failed with exit code %EXIT_CODE%.
)
pause
exit /b %EXIT_CODE%
