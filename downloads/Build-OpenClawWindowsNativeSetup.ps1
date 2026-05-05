$ErrorActionPreference = "Stop"

$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $KitDir
$OutputExe = Join-Path $KitDir "OpenClawWindowsNativeSetup.exe"
$BuildDir = Join-Path $env:TEMP ("OpenClawWindowsNativeSetup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$PayloadDir = Join-Path $BuildDir "payload"
$SedPath = Join-Path $BuildDir "OpenClawWindowsNativeSetup.sed"
$IExpress = Join-Path $env:WINDIR "System32\iexpress.exe"

if (-not (Test-Path -LiteralPath $IExpress -PathType Leaf)) {
  throw "IExpress was not found: $IExpress"
}

New-Item -ItemType Directory -Force -Path $PayloadDir | Out-Null

$payloadFiles = @(
  [pscustomobject]@{ Name = "OpenClaw_Windows_Native_Installer.cmd"; Source = (Join-Path $KitDir "OpenClaw_Windows_Native_Installer.cmd") },
  [pscustomobject]@{ Name = "Install-OpenClawWindowsNative.ps1"; Source = (Join-Path $KitDir "Install-OpenClawWindowsNative.ps1") },
  [pscustomobject]@{ Name = "Verify-OpenClawWindowsNative.ps1"; Source = (Join-Path $KitDir "Verify-OpenClawWindowsNative.ps1") },
  [pscustomobject]@{ Name = "Uninstall-OpenClawWindowsNative.ps1"; Source = (Join-Path $KitDir "Uninstall-OpenClawWindowsNative.ps1") },
  [pscustomobject]@{ Name = "OpenClaw_Windows_Native_User_Manual.md"; Source = (Join-Path $RepoRoot "docs\OpenClaw_Windows_Native_User_Manual.md") },
  [pscustomobject]@{ Name = "OpenClaw_Windows_Native_Technical_Spec.md"; Source = (Join-Path $RepoRoot "docs\OpenClaw_Windows_Native_Technical_Spec.md") }
)

foreach ($file in $payloadFiles) {
  if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) {
    throw "Missing payload file: $($file.Source)"
  }
  Copy-Item -LiteralPath $file.Source -Destination (Join-Path $PayloadDir $file.Name) -Force
}

if (Test-Path -LiteralPath $OutputExe -PathType Leaf) {
  Remove-Item -LiteralPath $OutputExe -Force
}

$payloadNames = $payloadFiles | ForEach-Object { $_.Name }
$sourceFileEntries = ($payloadNames | ForEach-Object { "$_=" }) -join "`r`n"

$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=Install OpenClaw Windows Native?
DisplayLicense=
FinishMessage=OpenClaw Windows Native installer finished.
TargetName=$OutputExe
FriendlyName=OpenClaw Windows Native Setup
AppLaunched=OpenClaw_Windows_Native_Installer.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=OpenClaw_Windows_Native_Installer.cmd
UserQuietInstCmd=OpenClaw_Windows_Native_Installer.cmd
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$PayloadDir\
[SourceFiles0]
$sourceFileEntries
"@

$sed | Set-Content -LiteralPath $SedPath -Encoding ASCII
& $IExpress /N $SedPath
$iexpressExit = $LASTEXITCODE
if (($iexpressExit -is [int]) -and $iexpressExit -ne 0 -and -not (Test-Path -LiteralPath $OutputExe -PathType Leaf)) {
  throw "IExpress failed with exit code $iexpressExit"
}

$deadline = (Get-Date).AddSeconds(30)
while (-not (Test-Path -LiteralPath $OutputExe -PathType Leaf)) {
  if ((Get-Date) -gt $deadline) {
    throw "Timed out waiting for $OutputExe"
  }
  Start-Sleep -Milliseconds 250
}

$manifest = [pscustomobject]@{
  builtAt = (Get-Date).ToString("o")
  packageDir = "."
  outputExe = "OpenClawWindowsNativeSetup.exe"
  payloadFiles = $payloadNames
  buildScript = "Build-OpenClawWindowsNativeSetup.ps1"
  nativeWindows = $true
  usesWsl = $false
  installer = "PowerShell 5.1 + CMD wrapper + IExpress"
  defaultRepoUrl = "https://github.com/openclaw/openclaw.git"
  defaultRepoRef = "main"
  defaultRepoDir = "%USERPROFILE%\openclaw-src"
  defaultStateDir = "%USERPROFILE%\.openclaw"
  defaultPort = 18789
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $KitDir "package-manifest.json") -Encoding UTF8

$hashLines = Get-ChildItem -LiteralPath $KitDir -File |
  Where-Object { $_.Name -eq "OpenClawWindowsNativeSetup.exe" } |
  Sort-Object Name |
  ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($_.Name)"
  }
$hashLines | Set-Content -LiteralPath (Join-Path $KitDir "checksums.sha256") -Encoding ASCII

Write-Host "Built: $OutputExe"
Write-Host "Manifest: $(Join-Path $KitDir 'package-manifest.json')"
Write-Host "Checksums: $(Join-Path $KitDir 'checksums.sha256')"
