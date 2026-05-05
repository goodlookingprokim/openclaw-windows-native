param(
  [string]$RepoDir = (Join-Path $env:USERPROFILE "openclaw-src"),
  [string]$StateDir = (Join-Path $env:USERPROFILE ".openclaw"),
  [int]$Port = 18789,
  [switch]$RemoveState
)

$ErrorActionPreference = "Continue"

Write-Host "OpenClaw Windows Native Uninstall Helper" -ForegroundColor Cyan
if (Test-Path -LiteralPath $RepoDir -PathType Container) {
  Push-Location -LiteralPath $RepoDir
  try {
    & pnpm.cmd openclaw gateway stop
  } finally {
    Pop-Location
  }
}

try {
  $processIds = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique)
  foreach ($processId in $processIds) {
    $proc = Get-CimInstance Win32_Process -Filter ("ProcessId=" + [int]$processId) -ErrorAction SilentlyContinue
    if ($proc.CommandLine -match "openclaw-src|openclaw gateway|dist\\index.js") {
      Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
      Write-Host "Stopped OpenClaw gateway PID $processId"
    }
  }
} catch {
  Write-Host "Port cleanup skipped: $($_.Exception.Message)"
}

if (Test-Path -LiteralPath $RepoDir -PathType Container) {
  Write-Host "Removing source folder: $RepoDir"
  Remove-Item -LiteralPath $RepoDir -Recurse -Force
}

if ($RemoveState -and (Test-Path -LiteralPath $StateDir -PathType Container)) {
  Write-Host "Removing state folder: $StateDir"
  Remove-Item -LiteralPath $StateDir -Recurse -Force
} elseif (Test-Path -LiteralPath $StateDir -PathType Container) {
  Write-Host "State folder kept: $StateDir"
  Write-Host "Run with -RemoveState only when you intentionally want to delete credentials and local data."
}

Write-Host "Uninstall helper completed."
