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

if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $env:GH_TOKEN = $env:GITHUB_TOKEN
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

function Test-GitHubAuth {
  if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
    & $GhExe api user >$null
    if ($LASTEXITCODE -ne 0) {
      throw "GH_TOKEN/GITHUB_TOKEN is present but GitHub API authentication failed."
    }
    return
  }
  Invoke-Gh -Arguments @("auth", "status") | Out-Null
}

function Invoke-GitPush {
  param([string[]]$Arguments)
  if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
    $oldCount = $env:GIT_CONFIG_COUNT
    $oldKey = $env:GIT_CONFIG_KEY_0
    $oldValue = $env:GIT_CONFIG_VALUE_0
    try {
      $env:GIT_CONFIG_COUNT = "1"
      $env:GIT_CONFIG_KEY_0 = "http.https://github.com/.extraheader"
      $env:GIT_CONFIG_VALUE_0 = "AUTHORIZATION: bearer $env:GH_TOKEN"
      & git @Arguments
    } finally {
      $env:GIT_CONFIG_COUNT = $oldCount
      $env:GIT_CONFIG_KEY_0 = $oldKey
      $env:GIT_CONFIG_VALUE_0 = $oldValue
    }
  } else {
    & git @Arguments
  }
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed."
  }
}

if (-not (Get-Command $GhExe -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI is required. Install it with: winget install --id GitHub.cli -e --source winget"
}

Test-GitHubAuth

$fullName = "$Owner/$Repo"
$repoExists = $false
$previousErrorActionPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = "Continue"
  & $GhExe repo view $fullName *> $null
  $repoExists = $LASTEXITCODE -eq 0
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
if (-not $repoExists) {
  Invoke-Gh -Arguments @(
    "repo", "create", $fullName,
    "--public",
    "--description", $Description,
    "--homepage", "https://$Owner.github.io/$Repo/"
  ) | Out-Null
}

$remoteUrl = "https://github.com/$fullName.git"
$remote = (& git remote get-url origin 2>$null)
if (-not $remote) {
  & git remote add origin $remoteUrl
} elseif ($remote -ne $remoteUrl) {
  & git remote set-url origin $remoteUrl
}

Invoke-GitPush -Arguments @("push", "-u", "origin", "main")

Invoke-Gh -Arguments @("repo", "edit", $fullName, "--homepage", "https://$Owner.github.io/$Repo/") | Out-Null

# GitHub Pages needs Actions as source for actions/deploy-pages.
Invoke-Gh -Arguments @("api", "--method", "POST", "/repos/$fullName/pages", "-f", "build_type=workflow") -AllowFailure | Out-Null

$tagExists = (& git tag --list $InitialTag)
if (-not $tagExists) {
  & git tag $InitialTag
}
Invoke-GitPush -Arguments @("push", "origin", "main", "--tags")

Write-Host "Published repository: https://github.com/$fullName"
Write-Host "GitHub Pages URL: https://$Owner.github.io/$Repo/"
Write-Host "Release tag pushed: $InitialTag"
