@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%" || exit /b 1

set "GH=gh"
if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GH=%ProgramFiles%\GitHub CLI\gh.exe"

where gh >nul 2>&1
if errorlevel 1 if not exist "%GH%" (
  echo [OpenClaw] GitHub CLI is not installed.
  echo Install:
  echo   winget install --id GitHub.cli -e --source winget
  if not "%OPENCLAW_SKIP_PAUSE%"=="1" pause
  exit /b 1
)

"%GH%" auth status >nul 2>&1
if errorlevel 1 (
  if "%OPENCLAW_SKIP_PAUSE%"=="1" (
    echo [OpenClaw] GitHub login is required. Run gh auth login first.
    exit /b 1
  )
  echo [OpenClaw] GitHub login is required.
  echo A browser/device login flow will start now.
  "%GH%" auth login
  if errorlevel 1 (
    echo [ERROR] GitHub login failed.
    if not "%OPENCLAW_SKIP_PAUSE%"=="1" pause
    exit /b 1
  )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\Publish-GitHub.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo [DONE] GitHub publish flow completed.
) else (
  echo [ERROR] GitHub publish flow failed with exit code %EXIT_CODE%.
)
if not "%OPENCLAW_SKIP_PAUSE%"=="1" pause
exit /b %EXIT_CODE%
