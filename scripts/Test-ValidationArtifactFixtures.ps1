param(
  [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Write-FixtureOk([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Fail-Fixture([string]$Message) {
  throw "[VALIDATION FIXTURE] $Message"
}

$artifactDir = Join-Path $RepoRoot ".artifacts"
$goodArtifact = Join-Path $artifactDir "telegram-validation.good.json"
$badArtifact = Join-Path $artifactDir "telegram-validation.bad.json"
$auditScript = Join-Path $RepoRoot "scripts\Test-SecurityAudit.ps1"

New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
try {
  [pscustomobject]@{
    schemaVersion = 1
    generatedAt = "2026-05-05T00:00:00Z"
    channel = "telegram"
    status = "warning"
    mode = "dry-run"
    checks = @(
      [pscustomobject]@{
        name = "channel-status-probe"
        status = "warning"
        evidence = "Dry-run completed; user action may still be required."
      }
    )
  } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $goodArtifact -Encoding UTF8

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $RepoRoot -SkipGitHistory -TelegramValidationArtifact $goodArtifact
  if ($LASTEXITCODE -ne 0) {
    Fail-Fixture "Expected redacted Telegram validation artifact to pass schema audit."
  }
  Write-FixtureOk "redacted Telegram validation artifact is accepted"

  [pscustomobject]@{
    schemaVersion = 1
    generatedAt = "2026-05-05T00:00:00Z"
    channel = "telegram"
    status = "passed"
    checks = @(
      [pscustomobject]@{
        name = "channel-status-probe"
        status = "passed"
        token = "redacted-placeholder"
      }
    )
  } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $badArtifact -Encoding UTF8

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $RepoRoot -SkipGitHistory -TelegramValidationArtifact $badArtifact 2>&1 | Tee-Object -Variable badOutput | Out-Null
    $badExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($badExitCode -eq 0) {
    Fail-Fixture "Expected sensitive Telegram validation artifact field to fail schema audit."
  }
  if (($badOutput -join "`n") -notmatch "Sensitive field name") {
    Fail-Fixture "Expected failure to identify sensitive field name."
  }
  Write-FixtureOk "sensitive Telegram validation artifact is rejected"
} finally {
  Remove-Item -LiteralPath $goodArtifact, $badArtifact -Force -ErrorAction SilentlyContinue
}
