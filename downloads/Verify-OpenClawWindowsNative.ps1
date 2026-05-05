param(
  [string]$RepoDir = (Join-Path $env:USERPROFILE "openclaw-src"),
  [string]$StateDir = (Join-Path $env:USERPROFILE ".openclaw"),
  [int]$Port = 18789,
  [switch]$TelegramDryRun,
  [switch]$TelegramDryRunOnly,
  [string]$TelegramValidationArtifact,
  [switch]$JsonStatus
)

$ErrorActionPreference = "Continue"
$failures = 0
$warnings = 0
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EngineCandidates = @(
  (Join-Path $KitDir "engine\OpenClawWindowsNative.Engine.psm1"),
  (Join-Path $KitDir "OpenClawWindowsNative.Engine.psm1")
)
$EngineModule = $EngineCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
$EngineAvailable = $false
if ($EngineModule) {
  Import-Module $EngineModule -Force -DisableNameChecking
  $EngineAvailable = $true
  Assert-OpenClawSafeParameters -BoundParameters $PSBoundParameters
}
if ([string]::IsNullOrWhiteSpace($TelegramValidationArtifact)) {
  $TelegramValidationArtifact = Join-Path $StateDir "validation\telegram-validation.dry-run.json"
}

function Pass([string]$Text) { Write-Host "[PASS] $Text" -ForegroundColor Green }
function Warn([string]$Text) { $script:warnings++; Write-Host "[WARN] $Text" -ForegroundColor Yellow }
function Fail([string]$Text) { $script:failures++; Write-Host "[FAIL] $Text" -ForegroundColor Red }

function Test-Cmd([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not $JsonStatus) {
  Write-Host "OpenClaw Windows Native Verification" -ForegroundColor Cyan
  Write-Host "Repo:  $RepoDir"
  Write-Host "State: $StateDir"
  Write-Host "Port:  $Port"
  if ($TelegramDryRun -or $TelegramDryRunOnly) { Write-Host "Telegram dry-run: enabled" }
  Write-Host ""
}

if ($EngineAvailable -and $TelegramDryRunOnly) {
  $artifact = New-OpenClawTelegramDryRunArtifact -StateDir $StateDir -OutputPath $TelegramValidationArtifact
  Write-OpenClawStatus -Level pass -Message "Telegram dry-run validation artifact written" -Check "telegram-dry-run" -Data @{ artifact = $artifact.path; mode = $artifact.mode; status = $artifact.status } -Json:$JsonStatus
  Write-OpenClawStatus -Level warn -Message "Telegram dry-run is simulated and does not prove live send/receive" -Check "telegram-live-scope" -Data @{ mode = $artifact.mode } -Json:$JsonStatus
  if ($JsonStatus) {
    Write-OpenClawStatus -Level warn -Message "Verification summary: failures=0 warnings=1" -Check "summary" -Data @{ failures = 0; warnings = 1 } -Json
  } else {
    Write-Host ""
    Write-Host "Verification summary: failures=0 warnings=1"
  }
  exit 0
}

if ($EngineAvailable) {
  $results = @(Invoke-OpenClawVerifierChecks -RepoDir $RepoDir -StateDir $StateDir -Port $Port)
  foreach ($result in $results) {
    if ($result.level -eq "fail") { $failures++ }
    if ($result.level -eq "warn") { $warnings++ }
    Write-OpenClawStatus -Level $result.level -Message $result.message -Check $result.name -Data $result.data -Json:$JsonStatus
  }
  if ($TelegramDryRun) {
    $artifact = New-OpenClawTelegramDryRunArtifact -StateDir $StateDir -OutputPath $TelegramValidationArtifact
    Write-OpenClawStatus -Level pass -Message "Telegram dry-run validation artifact written" -Check "telegram-dry-run" -Data @{ artifact = $artifact.path; mode = $artifact.mode; status = $artifact.status } -Json:$JsonStatus
  }
  if ($JsonStatus) {
    $level = if ($failures -gt 0) { "fail" } elseif ($warnings -gt 0) { "warn" } else { "ok" }
    Write-OpenClawStatus -Level $level -Message "Verification summary: failures=$failures warnings=$warnings" -Check "summary" -Data @{ failures = $failures; warnings = $warnings } -Json
  } else {
    Write-Host ""
    Write-Host "Verification summary: failures=$failures warnings=$warnings"
  }
  if ($failures -gt 0) { exit 1 }
  exit 0
}

if ($TelegramDryRun -or $TelegramDryRunOnly) { Warn "Telegram dry-run artifact generation requires the shared engine module." }

if ($env:WSL_DISTRO_NAME) { Fail "Running inside WSL: $env:WSL_DISTRO_NAME" } else { Pass "Running in native Windows PowerShell/CMD context" }

foreach ($cmd in @("git.exe", "node.exe", "pnpm.cmd")) {
  if (Test-Cmd $cmd) {
    Pass "$cmd found"
  } else {
    Fail "$cmd missing"
  }
}

if (Test-Cmd "node.exe") {
  try {
    $nodeVersion = [version]((& node.exe -v).Trim().TrimStart("v"))
    if ($nodeVersion -ge [version]"22.14.0") { Pass "Node.js version $nodeVersion meets >= 22.14.0" } else { Fail "Node.js version $nodeVersion is older than 22.14.0" }
  } catch {
    Fail "Could not parse Node.js version"
  }
}

if (Test-Path -LiteralPath (Join-Path $RepoDir ".git") -PathType Container) { Pass "OpenClaw repository exists" } else { Fail "OpenClaw repository missing: $RepoDir" }
if (Test-Path -LiteralPath (Join-Path $RepoDir "dist\index.js") -PathType Leaf) { Pass "OpenClaw CLI build exists" } else { Fail "OpenClaw CLI build missing: dist\\index.js" }
if (Test-Path -LiteralPath (Join-Path $RepoDir "dist\control-ui\index.html") -PathType Leaf) { Pass "Control UI build exists" } else { Fail "Control UI build missing: dist\\control-ui\\index.html" }

$configPath = Join-Path $StateDir "openclaw.json"
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
  Pass "OpenClaw config exists"
  try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($cfg.gateway) { Pass "Gateway config exists" } else { Warn "Gateway config not found in openclaw.json" }
    if ($cfg.channels.telegram.enabled -eq $true) { Pass "Telegram channel enabled" } else { Warn "Telegram channel is not enabled yet" }
    if ($cfg.channels.telegram.tokenFile -or $cfg.channels.telegram.botToken -or $env:TELEGRAM_BOT_TOKEN) {
      Pass "Telegram bot credential is configured or available"
    } else {
      Warn "Telegram bot credential not detected"
    }
  } catch {
    Fail "openclaw.json is not valid JSON"
  }
} else {
  Fail "OpenClaw config missing: $configPath"
}

if ((Test-Cmd "pnpm.cmd") -and (Test-Path -LiteralPath $RepoDir -PathType Container)) {
  Push-Location -LiteralPath $RepoDir
  try {
    & pnpm.cmd openclaw --version | Out-Host
    if ($LASTEXITCODE -eq 0) { Pass "OpenClaw CLI runs" } else { Fail "OpenClaw CLI failed" }

    & pnpm.cmd openclaw plugins list --enabled | Tee-Object -Variable pluginsOut | Out-Null
    if ($LASTEXITCODE -eq 0 -and ($pluginsOut -match "telegram")) { Pass "Telegram plugin listed as enabled" } else { Warn "Telegram plugin is not listed as enabled" }

    & pnpm.cmd openclaw gateway health | Tee-Object -Variable healthOut | Out-Null
    if ($LASTEXITCODE -eq 0) { Pass "Gateway health command succeeded" } else { Warn "Gateway health command failed; start the gateway and rerun verification" }

    & pnpm.cmd openclaw channels status --probe | Out-Host
    if ($LASTEXITCODE -eq 0) { Pass "Channel status command succeeded" } else { Warn "Channel status probe failed or needs pairing/token setup" }
  } finally {
    Pop-Location
  }
}

try {
  $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
  if ($listeners.Count -gt 0) { Pass "Port $Port is listening" } else { Warn "No listener on port $Port" }
} catch {
  Warn "Could not inspect TCP port $Port"
}

Write-Host ""
Write-Host "Verification summary: failures=$failures warnings=$warnings"
if ($failures -gt 0) { exit 1 }
exit 0
