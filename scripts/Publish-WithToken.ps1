$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$publishScript = Join-Path $repoRoot "scripts\Publish-GitHub.ps1"

Write-Host "GitHub Personal Access Token publish helper"
Write-Host "Required scopes for a classic token: repo, workflow."
Write-Host "The token is not written to disk."

$secure = Read-Host "Paste GitHub token" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Empty token."
  }
  $env:GH_TOKEN = $token.Trim()
  Push-Location -LiteralPath $repoRoot
  try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $publishScript
    if ($LASTEXITCODE -ne 0) {
      throw "Publish-GitHub.ps1 failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
} finally {
  $env:GH_TOKEN = $null
  if ($bstr -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}
