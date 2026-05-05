param(
  [string]$Owner = "goodlookingprokim",
  [string]$Repo = "openclaw-windows-native",
  [string]$Description = "Windows-native OpenClaw installer and GitHub Pages guide for Telegram-based agent experiments.",
  [string]$InitialTag = ("v" + (Get-Date -Format "yyyy.MM.dd"))
)

$ErrorActionPreference = "Stop"

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = (($machinePath, $userPath, $env:Path) | Where-Object { $_ } | Select-Object -Unique) -join ";"
$GhExe = "gh"
if (-not (Get-Command $GhExe -ErrorAction SilentlyContinue)) {
  $candidate = Join-Path $env:ProgramFiles "GitHub CLI\gh.exe"
  if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    $GhExe = $candidate
  }
}

function Invoke-Gh {
  param(
    [string[]]$Arguments,
    [switch]$AllowFailure
  )
  & $GhExe @Arguments
  $exit = $LASTEXITCODE
  if ($exit -ne 0 -and -not $AllowFailure) {
    throw "gh $($Arguments -join ' ') failed with exit code $exit"
  }
  return $exit
}

if (-not (Get-Command $GhExe -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI is required. Install it with: winget install --id GitHub.cli -e --source winget"
}

Invoke-Gh -Arguments @("auth", "status") | Out-Null

$fullName = "$Owner/$Repo"
& $GhExe repo view $fullName >$null 2>$null
$repoExists = $LASTEXITCODE -eq 0
if (-not $repoExists) {
  Invoke-Gh -Arguments @(
    "repo", "create", $fullName,
    "--public",
    "--description", $Description,
    "--homepage", "https://$Owner.github.io/$Repo/",
    "--source", ".",
    "--remote", "origin",
    "--push"
  ) | Out-Null
} else {
  $remote = (& git remote get-url origin 2>$null)
  if (-not $remote) {
    & git remote add origin "https://github.com/$fullName.git"
  }
  & git push -u origin main
  if ($LASTEXITCODE -ne 0) {
    throw "git push failed."
  }
}

Invoke-Gh -Arguments @("repo", "edit", $fullName, "--homepage", "https://$Owner.github.io/$Repo/") | Out-Null

# GitHub Pages needs Actions as source for actions/deploy-pages.
Invoke-Gh -Arguments @("api", "--method", "POST", "/repos/$fullName/pages", "-f", "build_type=workflow") -AllowFailure | Out-Null

$tagExists = (& git tag --list $InitialTag)
if (-not $tagExists) {
  & git tag $InitialTag
}
& git push origin main --tags
if ($LASTEXITCODE -ne 0) {
  throw "git push tags failed."
}

Write-Host "Published repository: https://github.com/$fullName"
Write-Host "GitHub Pages URL: https://$Owner.github.io/$Repo/"
Write-Host "Release tag pushed: $InitialTag"
