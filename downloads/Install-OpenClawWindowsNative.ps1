param(
  [switch]$VerifyOnly,
  [switch]$SkipPrerequisiteInstall,
  [switch]$SkipBuild,
  [switch]$SkipTelegram,
  [switch]$NonInteractive,
  [string]$RepoUrl = "https://github.com/openclaw/openclaw.git",
  [string]$RepoRef = "main",
  [string]$RepoDir = (Join-Path $env:USERPROFILE "openclaw-src"),
  [string]$StateDir = (Join-Path $env:USERPROFILE ".openclaw"),
  [int]$Port = 18789,
  [switch]$JsonStatus
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

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

$DesktopDir = [Environment]::GetFolderPath("DesktopDirectory")
$DesktopOpenClaw = Join-Path $DesktopDir "OpenClaw"
$LogDir = Join-Path $DesktopOpenClaw "install-logs"
$ManualSource = Join-Path $KitDir "OpenClaw_Windows_Native_User_Manual.md"
$ManualTarget = Join-Path $DesktopOpenClaw "OpenClaw_Windows_Native_User_Manual.md"
$VerifyScript = Join-Path $KitDir "Verify-OpenClawWindowsNative.ps1"
$PackagePnpm = "pnpm@10.33.2"
$MinimumNode = [version]"22.14.0"

function Write-Title([string]$Text) {
  Write-Host ""
  Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Write-Info([string]$Text) {
  if ($EngineAvailable) {
    Write-OpenClawStatus -Level info -Message $Text -Json:$JsonStatus
    return
  }
  Write-Host "[INFO] $Text" -ForegroundColor Gray
}

function Write-Ok([string]$Text) {
  if ($EngineAvailable) {
    Write-OpenClawStatus -Level ok -Message $Text -Json:$JsonStatus
    return
  }
  Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-WarnLine([string]$Text) {
  if ($EngineAvailable) {
    Write-OpenClawStatus -Level warn -Message $Text -Json:$JsonStatus
    return
  }
  Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Fail([string]$Text) {
  if ($EngineAvailable) {
    Write-OpenClawStatus -Level error -Message $Text -Json:$JsonStatus
    return
  }
  Write-Host "[ERROR] $Text" -ForegroundColor Red
}

function Read-ChoiceValue {
  param(
    [string]$Prompt,
    [string[]]$Allowed,
    [string]$Default
  )
  if ($NonInteractive) {
    return $Default
  }
  while ($true) {
    $suffix = if ($Default) { " [$Default]" } else { "" }
    $value = (Read-Host "$Prompt$suffix").Trim()
    if ([string]::IsNullOrWhiteSpace($value) -and $Default) {
      return $Default
    }
    if ($Allowed -contains $value) {
      return $value
    }
    Write-WarnLine "Allowed values: $($Allowed -join ', ')"
  }
}

function Read-YesNo {
  param(
    [string]$Prompt,
    [bool]$DefaultYes = $true
  )
  $default = if ($DefaultYes) { "Y" } else { "N" }
  $choice = Read-ChoiceValue -Prompt "$Prompt (Y/N)" -Allowed @("Y", "y", "N", "n") -Default $default
  return $choice -match "^[Yy]$"
}

function Read-PlainSecret([string]$Prompt) {
  if ($EngineAvailable) {
    return Read-OpenClawPlainSecret -Prompt $Prompt
  }
  $secure = Read-Host $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    if ($bstr -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }
}

function Invoke-LoggedCommand {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory = $RepoDir,
    [switch]$AllowFailure
  )
  if ($EngineAvailable) {
    Write-Info (Format-OpenClawCommandForLog -FilePath $FilePath -Arguments $Arguments)
  } else {
    Write-Info "$FilePath $($Arguments -join ' ')"
  }
  $oldLocation = Get-Location
  try {
    if ($WorkingDirectory -and (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
      Set-Location -LiteralPath $WorkingDirectory
    }
    & $FilePath @Arguments
    $exit = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
    if ($exit -ne 0 -and -not $AllowFailure) {
      throw "Command failed with exit code ${exit}: $FilePath $($Arguments -join ' ')"
    }
    return $exit
  } finally {
    Set-Location $oldLocation
  }
}

function Refresh-ProcessPath {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = (($machine, $user, $env:Path) | Where-Object { $_ } | Select-Object -Unique) -join ";"
}

function Test-CommandExists([string]$Name) {
  if ($EngineAvailable) {
    return Test-OpenClawCommandExists -Name $Name
  }
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-SafeRepoUrl([string]$Url) {
  $parsed = $null
  if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$parsed)) {
    throw "RepoUrl must be an absolute URL."
  }
  if ($parsed.Scheme -ne "https") {
    throw "RepoUrl must use https for this public installer."
  }
}

function Assert-SafeGitRef([string]$Ref) {
  if ([string]::IsNullOrWhiteSpace($Ref)) {
    throw "RepoRef must not be empty."
  }
  if ($Ref.StartsWith("-") -or $Ref -notmatch "^[A-Za-z0-9._/@+-]+$") {
    throw "RepoRef contains unsupported characters."
  }
}

function Get-NodeVersion {
  if (-not (Test-CommandExists "node.exe")) {
    return $null
  }
  $raw = (& node.exe -v 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
    return $null
  }
  return [version]($raw.Trim().TrimStart("v"))
}

function Invoke-WingetInstall {
  param(
    [string]$Id,
    [string]$Name
  )
  if ($SkipPrerequisiteInstall) {
    throw "$Name is missing and automatic prerequisite install was skipped."
  }
  if (-not (Test-CommandExists "winget.exe")) {
    throw "winget.exe was not found. Install $Name manually, then rerun this installer."
  }
  Write-Title "Installing prerequisite: $Name"
  Invoke-LoggedCommand -FilePath "winget.exe" -Arguments @(
    "install", "--id", $Id, "-e", "--source", "winget",
    "--accept-source-agreements", "--accept-package-agreements"
  ) -WorkingDirectory $env:USERPROFILE
  Refresh-ProcessPath
}

function Ensure-Git {
  Write-Title "Checking Git"
  if (-not (Test-CommandExists "git.exe")) {
    Invoke-WingetInstall -Id "Git.Git" -Name "Git for Windows"
  }
  Invoke-LoggedCommand -FilePath "git.exe" -Arguments @("--version") -WorkingDirectory $env:USERPROFILE
  Write-Ok "Git is available."
}

function Ensure-Node {
  Write-Title "Checking Node.js"
  $version = Get-NodeVersion
  if ($null -eq $version -or $version -lt $MinimumNode) {
    if ($version) {
      Write-WarnLine "Current Node.js is $version; OpenClaw requires $MinimumNode or newer."
    }
    Invoke-WingetInstall -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
    $version = Get-NodeVersion
  }
  if ($null -eq $version -or $version -lt $MinimumNode) {
    throw "Node.js $MinimumNode or newer is required. Current: $version"
  }
  Write-Ok "Node.js $version is available."
}

function Ensure-Pnpm {
  Write-Title "Checking pnpm"
  $installed = Test-CommandExists "pnpm.cmd"
  if (-not $installed) {
    if (Test-CommandExists "corepack.cmd") {
      Invoke-LoggedCommand -FilePath "corepack.cmd" -Arguments @("enable") -WorkingDirectory $env:USERPROFILE -AllowFailure | Out-Null
      Invoke-LoggedCommand -FilePath "corepack.cmd" -Arguments @("prepare", $PackagePnpm, "--activate") -WorkingDirectory $env:USERPROFILE
      Refresh-ProcessPath
    }
  }
  if (-not (Test-CommandExists "pnpm.cmd")) {
    Invoke-LoggedCommand -FilePath "npm.cmd" -Arguments @("install", "-g", $PackagePnpm) -WorkingDirectory $env:USERPROFILE
    Refresh-ProcessPath
  }
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("-v") -WorkingDirectory $env:USERPROFILE
  Write-Ok "pnpm is available."
}

function Ensure-Repository {
  Write-Title "Preparing OpenClaw source"
  Assert-SafeRepoUrl $RepoUrl
  Assert-SafeGitRef $RepoRef
  if (Test-Path -LiteralPath (Join-Path $RepoDir ".git") -PathType Container) {
    Write-Info "Existing repository found: $RepoDir"
    $currentRemote = (& git.exe -C $RepoDir remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or $currentRemote -ne $RepoUrl) {
      throw "Existing repository origin is not the expected RepoUrl. Current: $currentRemote"
    }
    if (-not $NonInteractive -and -not (Read-YesNo "Fetch and checkout OpenClaw ref '$RepoRef'?" $true)) {
      Write-WarnLine "Repository update skipped."
      return
    }
    Sync-RepositoryRef
    return
  }
  if (Test-Path -LiteralPath $RepoDir) {
    throw "$RepoDir exists but is not a Git repository. Rename or remove it, then rerun the installer."
  }
  Invoke-LoggedCommand -FilePath "git.exe" -Arguments @("clone", $RepoUrl, $RepoDir) -WorkingDirectory $env:USERPROFILE
  Sync-RepositoryRef
}

function Sync-RepositoryRef {
  Write-Info "Repository source: $RepoUrl"
  Write-Info "Repository ref: $RepoRef"
  Invoke-LoggedCommand -FilePath "git.exe" -Arguments @("-C", $RepoDir, "fetch", "origin", "--tags", "--prune") -WorkingDirectory $env:USERPROFILE
  Invoke-LoggedCommand -FilePath "git.exe" -Arguments @("-C", $RepoDir, "checkout", $RepoRef) -WorkingDirectory $env:USERPROFILE
  $branch = (& git.exe -C $RepoDir symbolic-ref --short -q HEAD 2>$null)
  if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($branch)) {
    Invoke-LoggedCommand -FilePath "git.exe" -Arguments @("-C", $RepoDir, "pull", "--ff-only", "origin", $branch.Trim()) -WorkingDirectory $env:USERPROFILE
  } else {
    Write-Info "Detached ref selected; pull step skipped."
  }
  $commit = (& git.exe -C $RepoDir rev-parse HEAD).Trim()
  Write-Ok "OpenClaw source checked out at $commit."
}

function Build-OpenClaw {
  if ($SkipBuild) {
    Write-WarnLine "Build step skipped by parameter."
    return
  }
  Write-Title "Installing and building OpenClaw"
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("install", "--frozen-lockfile") -WorkingDirectory $RepoDir
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("build") -WorkingDirectory $RepoDir
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("ui:build") -WorkingDirectory $RepoDir
  Write-Ok "OpenClaw build completed."
}

function Run-Onboarding {
  Write-Title "OpenClaw onboarding"
  $configPath = Join-Path $StateDir "openclaw.json"
  $shouldRun = $true
  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $shouldRun = Read-YesNo "Existing OpenClaw config found. Run onboarding again?" $false
  }
  if (-not $shouldRun) {
    Write-WarnLine "Onboarding skipped."
    return
  }
  Write-Info "The official OpenClaw onboarding will ask you to choose the model/provider credentials."
  Write-Info "Recommended Windows values: local gateway, loopback bind, port $Port, token auth."
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @(
    "openclaw", "onboard",
    "--flow", "quickstart",
    "--mode", "local",
    "--gateway-bind", "loopback",
    "--gateway-port", ([string]$Port),
    "--gateway-auth", "token",
    "--node-manager", "pnpm",
    "--install-daemon"
  ) -WorkingDirectory $RepoDir
}

function Protect-SecretFile([string]$Path) {
  try {
    if ($EngineAvailable) {
      Protect-OpenClawSecretFile -Path $Path
    } else {
      $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      & icacls.exe $Path /inheritance:r | Out-Null
      & icacls.exe $Path /grant:r "${identity}:F" "SYSTEM:F" | Out-Null
    }
  } catch {
    Write-WarnLine "Could not tighten ACL on ${Path}: $($_.Exception.Message)"
  }
}

function Configure-Telegram {
  if ($SkipTelegram) {
    Write-WarnLine "Telegram setup skipped by parameter."
    return
  }
  Write-Title "Telegram setup"
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("openclaw", "plugins", "enable", "telegram") -WorkingDirectory $RepoDir
  if (-not (Read-YesNo "Register a Telegram bot token now?" $true)) {
    Write-WarnLine "Telegram token registration skipped. You can run this later: pnpm.cmd openclaw channels add --channel telegram --token-file <path>"
    return
  }
  Write-Info "Paste the token from @BotFather. It is not stored in this installer or printed to the log."
  $token = Read-PlainSecret "Telegram bot token"
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-WarnLine "Empty token. Telegram channel registration skipped."
    return
  }
  $credentialsDir = Join-Path $StateDir "credentials"
  New-Item -ItemType Directory -Force -Path $credentialsDir | Out-Null
  $tokenFile = Join-Path $credentialsDir "telegram-bot-token.txt"
  [System.IO.File]::WriteAllText($tokenFile, $token.Trim(), [System.Text.Encoding]::ASCII)
  Protect-SecretFile $tokenFile
  $token = $null
  [GC]::Collect()
  Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("openclaw", "channels", "add", "--channel", "telegram", "--token-file", $tokenFile) -WorkingDirectory $RepoDir
  Write-Ok "Telegram channel registered with a user-local token file."
}

function Install-Gateway {
  Write-Title "Installing and starting Gateway"
  $installExit = Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("openclaw", "gateway", "install", "--force", "--port", ([string]$Port)) -WorkingDirectory $RepoDir -AllowFailure
  if ($installExit -ne 0) {
    Write-WarnLine "Gateway service install failed. Manual start launchers will still be created."
  }
  $startExit = Invoke-LoggedCommand -FilePath "pnpm.cmd" -Arguments @("openclaw", "gateway", "start") -WorkingDirectory $RepoDir -AllowFailure
  if ($startExit -ne 0) {
    Write-WarnLine "Gateway scheduled start failed. You can use the desktop Start Gateway launcher."
  }
}

function Write-LauncherFile {
  param(
    [string]$Name,
    [string[]]$Lines
  )
  $path = Join-Path $DesktopOpenClaw $Name
  $content = @("@echo off", "setlocal EnableExtensions", "chcp 65001 >nul", "cd /d `"$RepoDir`"") + $Lines + @("echo.", "pause")
  Set-Content -LiteralPath $path -Value $content -Encoding ASCII
}

function Install-DesktopAssets {
  Write-Title "Creating desktop launchers"
  New-Item -ItemType Directory -Force -Path $DesktopOpenClaw | Out-Null
  if (Test-Path -LiteralPath $ManualSource -PathType Leaf) {
    Copy-Item -LiteralPath $ManualSource -Destination $ManualTarget -Force
  }
  Write-LauncherFile "OpenClaw_01_Start_Gateway.cmd" @("pnpm.cmd openclaw gateway run --bind loopback --port $Port --verbose")
  Write-LauncherFile "OpenClaw_02_Status.cmd" @(
    "pnpm.cmd openclaw gateway status --no-probe",
    "pnpm.cmd openclaw gateway health",
    "pnpm.cmd openclaw channels status --probe"
  )
  Write-LauncherFile "OpenClaw_03_Stop_Gateway.cmd" @("pnpm.cmd openclaw gateway stop")
  Write-LauncherFile "OpenClaw_04_Open_Dashboard.cmd" @("pnpm.cmd openclaw dashboard")
  Write-LauncherFile "OpenClaw_05_Approve_Telegram_Pairing.cmd" @(
    "set /p PAIRING_CODE=Telegram pairing code: ",
    "pnpm.cmd openclaw pairing approve telegram %PAIRING_CODE%"
  )
  Write-LauncherFile "OpenClaw_06_Telegram_Dry_Run.cmd" @(
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$KitDir\Verify-OpenClawWindowsNative.ps1`" -RepoDir `"$RepoDir`" -StateDir `"$StateDir`" -Port $Port -TelegramDryRunOnly"
  )
  Write-LauncherFile "OpenClaw_07_Update.cmd" @(
    "git fetch origin --tags --prune",
    "git checkout $RepoRef",
    "for /f %%i in ('git symbolic-ref --short -q HEAD') do git pull --ff-only origin %%i",
    "pnpm.cmd install --frozen-lockfile",
    "pnpm.cmd build",
    "pnpm.cmd ui:build",
    "pnpm.cmd openclaw plugins enable telegram",
    "pnpm.cmd openclaw gateway install --force --port $Port",
    "pnpm.cmd openclaw gateway start"
  )
  Write-Ok "Launchers created in $DesktopOpenClaw"
}

function Run-Verifier {
  Write-Title "Running verification"
  if (Test-Path -LiteralPath $VerifyScript -PathType Leaf) {
    Write-Info "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $VerifyScript -RepoDir $RepoDir -StateDir $StateDir -Port $Port"
    $verifyArgs = @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", $VerifyScript,
      "-RepoDir", $RepoDir,
      "-StateDir", $StateDir,
      "-Port", ([string]$Port)
    )
    if ($JsonStatus) {
      $verifyArgs += "-JsonStatus"
    }
    & powershell.exe @verifyArgs
    if ($LASTEXITCODE -ne 0) {
      Write-WarnLine "Verification reported failures. Review the messages above."
    }
  } else {
    Write-WarnLine "Verifier script not found: $VerifyScript"
  }
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$logPath = Join-Path $LogDir ("OpenClawWindowsNativeInstall-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
Start-Transcript -LiteralPath $logPath -Force | Out-Null
try {
  Write-Host "OpenClaw Windows Native Installer" -ForegroundColor Cyan
  Write-Host "No WSL is required. Target repo: $RepoDir"
  Write-Host "OpenClaw source: $RepoUrl @ $RepoRef"
  Write-Host "Log: $logPath"

  if ($VerifyOnly) {
    Run-Verifier
    return
  }

  Ensure-Git
  Ensure-Node
  Ensure-Pnpm
  Ensure-Repository
  Build-OpenClaw
  Run-Onboarding
  Configure-Telegram
  Install-Gateway
  Install-DesktopAssets
  Run-Verifier

  Write-Title "Done"
  Write-Ok "OpenClaw Windows native installation flow completed."
  Write-Info "Manual: $ManualTarget"
  Write-Info "Desktop launchers: $DesktopOpenClaw"
} catch {
  Write-Fail $_.Exception.Message
  Write-Info "Review the log: $logPath"
  exit 1
} finally {
  Stop-Transcript | Out-Null
}
