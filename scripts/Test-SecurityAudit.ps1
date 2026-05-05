param(
  [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [switch]$SkipGitHistory,
  [string]$TelegramValidationArtifact = (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) ".artifacts\telegram-validation.json")
)

$ErrorActionPreference = "Stop"

function Write-AuditOk([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Fail-Audit([string]$Message) {
  throw "[SECURITY AUDIT] $Message"
}

function Assert-JsonFile([string]$Path, [string]$Label) {
  try {
    return (Get-Content -Encoding UTF8 -Raw -LiteralPath $Path | ConvertFrom-Json)
  } catch {
    Fail-Audit "$Label is not valid JSON: $($_.Exception.Message)"
  }
}

function Assert-NoSensitivePropertyName([object]$Value, [string]$Path = "$") {
  if ($null -eq $Value) { return }
  if ($Value -is [System.Array]) {
    for ($i = 0; $i -lt $Value.Count; $i++) {
      Assert-NoSensitivePropertyName -Value $Value[$i] -Path "$Path[$i]"
    }
    return
  }
  if ($Value -is [pscustomobject]) {
    foreach ($property in $Value.PSObject.Properties) {
      if ($property.Name -match "(?i)(token|secret|password|apikey|apiKey|credential|pairingCode|botToken)") {
        Fail-Audit "Sensitive field name is not allowed in validation artifacts: $Path.$($property.Name)"
      }
      Assert-NoSensitivePropertyName -Value $property.Value -Path "$Path.$($property.Name)"
    }
  }
}

function Assert-NoSecretLikeText([string]$Text, [string]$Label, [string[]]$Patterns) {
  foreach ($pattern in $Patterns) {
    if ($Text -match $pattern) {
      Fail-Audit "$Label contains secret-like or local-only text matching: $pattern"
    }
  }
}

function Assert-TelegramValidationArtifact([string]$Path, [string[]]$Patterns) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-AuditOk "Telegram validation artifact schema check skipped; artifact not present"
    return
  }

  $artifact = Assert-JsonFile -Path $Path -Label "Telegram validation artifact"
  $raw = Get-Content -Encoding UTF8 -Raw -LiteralPath $Path
  Assert-NoSecretLikeText -Text $raw -Label "Telegram validation artifact" -Patterns $Patterns
  Assert-NoSensitivePropertyName -Value $artifact

  if ($artifact.schemaVersion -ne 1) { Fail-Audit "Telegram validation artifact schemaVersion must be 1" }
  if ($artifact.channel -ne "telegram") { Fail-Audit "Telegram validation artifact channel must be telegram" }
  if ($artifact.status -notin @("passed", "warning", "failed", "skipped")) { Fail-Audit "Telegram validation artifact status is invalid: $($artifact.status)" }
  try { [datetimeoffset]::Parse([string]$artifact.generatedAt) | Out-Null } catch { Fail-Audit "Telegram validation artifact generatedAt must be ISO-8601 parseable" }
  if (-not ($artifact.checks -is [System.Array]) -or $artifact.checks.Count -eq 0) { Fail-Audit "Telegram validation artifact checks must be a non-empty array" }
  foreach ($check in $artifact.checks) {
    if ([string]::IsNullOrWhiteSpace([string]$check.name)) { Fail-Audit "Telegram validation artifact check is missing name" }
    if ($check.status -notin @("passed", "warning", "failed", "skipped")) { Fail-Audit "Telegram validation artifact check '$($check.name)' has invalid status" }
    if ($check.PSObject.Properties.Name -contains "evidence" -and ([string]$check.evidence -match "(?i)(token|secret|password|pairing)")) {
      Fail-Audit "Telegram validation artifact check '$($check.name)' evidence must be redacted and non-sensitive"
    }
  }
  Write-AuditOk "Telegram validation artifact schema and redaction checks passed"
}

function Assert-PackageManifest([string]$RepoRoot, [string[]]$ExpectedPayloads, [string[]]$Patterns) {
  $manifestPath = Join-Path $RepoRoot "downloads\package-manifest.json"
  $manifest = Assert-JsonFile -Path $manifestPath -Label "package-manifest.json"
  $raw = Get-Content -Encoding UTF8 -Raw -LiteralPath $manifestPath
  Assert-NoSecretLikeText -Text $raw -Label "package-manifest.json" -Patterns $Patterns

  foreach ($property in @("builtAt", "packageDir", "outputExe", "payloadFiles", "buildScript", "nativeWindows", "usesWsl", "installer", "defaultRepoUrl", "defaultRepoRef", "defaultRepoDir", "defaultStateDir", "defaultPort")) {
    if ($manifest.PSObject.Properties.Name -notcontains $property) { Fail-Audit "package-manifest.json missing required property: $property" }
  }
  try { [datetimeoffset]::Parse([string]$manifest.builtAt) | Out-Null } catch { Fail-Audit "package-manifest.json builtAt must be ISO-8601 parseable" }
  if ($manifest.nativeWindows -ne $true) { Fail-Audit "package-manifest.json nativeWindows must be true" }
  if ($manifest.usesWsl -ne $false) { Fail-Audit "package-manifest.json usesWsl must be false" }
  if ($manifest.outputExe -ne "OpenClawWindowsNativeSetup.exe") { Fail-Audit "package-manifest.json outputExe changed unexpectedly" }
  if ($manifest.buildScript -ne "Build-OpenClawWindowsNativeSetup.ps1") { Fail-Audit "package-manifest.json buildScript changed unexpectedly" }
  if ($manifest.defaultRepoUrl -notmatch "^https://") { Fail-Audit "package-manifest.json defaultRepoUrl must be https" }
  if ($manifest.defaultPort -isnot [int] -and $manifest.defaultPort -isnot [long]) { Fail-Audit "package-manifest.json defaultPort must be numeric" }
  if ([string]$manifest.defaultRepoDir -notmatch "%USERPROFILE%") { Fail-Audit "package-manifest.json defaultRepoDir must remain user-relative" }
  if ([string]$manifest.defaultStateDir -notmatch "%USERPROFILE%") { Fail-Audit "package-manifest.json defaultStateDir must remain user-relative" }

  $actualPayloads = @($manifest.payloadFiles | ForEach-Object { [string]$_ }) | Sort-Object
  $expected = @($ExpectedPayloads | Sort-Object)
  if (($actualPayloads -join "|") -ne ($expected -join "|")) {
    Fail-Audit "package-manifest.json payloadFiles changed without audit update. Expected: $($expected -join ', '); actual: $($actualPayloads -join ', ')"
  }
  foreach ($payload in $actualPayloads) {
    if (-not ((Test-Path -LiteralPath (Join-Path $RepoRoot "downloads\$payload") -PathType Leaf) -or
        (Test-Path -LiteralPath (Join-Path $RepoRoot "downloads\engine\$payload") -PathType Leaf) -or
        (Test-Path -LiteralPath (Join-Path $RepoRoot "docs\$payload") -PathType Leaf))) {
      Fail-Audit "package-manifest.json payload missing from downloads/ or docs/: $payload"
    }
  }
  Write-AuditOk "package-manifest JSON schema, payload, and redaction checks passed"
}

function Assert-InstallerEngineAndRedactionChecks([string]$RepoRoot) {
  $installPath = Join-Path $RepoRoot "downloads\Install-OpenClawWindowsNative.ps1"
  $verifyPath = Join-Path $RepoRoot "downloads\Verify-OpenClawWindowsNative.ps1"
  $technicalSpecPath = Join-Path $RepoRoot "docs\OpenClaw_Windows_Native_Technical_Spec.md"
  $install = Get-Content -Encoding UTF8 -Raw -LiteralPath $installPath
  $verify = Get-Content -Encoding UTF8 -Raw -LiteralPath $verifyPath
  $technicalSpec = Get-Content -Encoding UTF8 -Raw -LiteralPath $technicalSpecPath

  if ($install -notmatch '\$MinimumNode\s*=\s*\[version\]"22\.14\.0"') { Fail-Audit "Installer must enforce Node.js >= 22.14.0" }
  if ($technicalSpec -notmatch 'node\s*>=22\.14\.0') { Fail-Audit "Technical spec must document the Node.js engine floor" }
  if ($install -notmatch 'Assert-SafeRepoUrl' -or $install -notmatch 'RepoUrl must use https') { Fail-Audit "Installer must validate HTTPS repository URLs" }
  if ($install -notmatch 'Assert-SafeGitRef') { Fail-Audit "Installer must validate Git refs before checkout" }
  if ($install -notmatch 'Read-Host\s+\$Prompt\s+-AsSecureString') { Fail-Audit "Installer must read Telegram token as a SecureString" }
  if ($install -notmatch 'ZeroFreeBSTR') { Fail-Audit "Installer must zero the SecureString BSTR after reading the token" }
  if ($install -notmatch '--token-file' -or $install -match '--token\s+') { Fail-Audit "Installer must register Telegram with --token-file and not a raw token argument" }
  if ($install -match 'Write-(Host|Info|Ok|WarnLine).*\$token') { Fail-Audit "Installer must not print Telegram token variables" }
  if ($verify -match 'Write-(Host|Output).*botToken' -or $verify -match 'Write-(Host|Output).*TELEGRAM_BOT_TOKEN') { Fail-Audit "Verifier must not print Telegram credential values" }
  if ($verify -notmatch 'ConvertFrom-Json') { Fail-Audit "Verifier must parse openclaw.json as JSON" }
  Write-AuditOk "installer engine, JSON, and credential redaction checks passed"
}


function Assert-EngineModuleChecks([string]$RepoRoot) {
  $enginePath = Join-Path $RepoRoot "downloads\engine\OpenClawWindowsNative.Engine.psm1"
  $installPath = Join-Path $RepoRoot "downloads\Install-OpenClawWindowsNative.ps1"
  $verifyPath = Join-Path $RepoRoot "downloads\Verify-OpenClawWindowsNative.ps1"
  $install = Get-Content -Encoding UTF8 -Raw -LiteralPath $installPath
  $verify = Get-Content -Encoding UTF8 -Raw -LiteralPath $verifyPath

  if ($install -notmatch 'EngineModule' -and $verify -notmatch 'EngineModule') {
    Write-AuditOk "engine module checks skipped; installer/verifier do not import an engine module"
    return
  }
  if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    Fail-Audit "Installer/verifier reference engine module but downloads/engine/OpenClawWindowsNative.Engine.psm1 is missing"
  }

  $engine = Get-Content -Encoding UTF8 -Raw -LiteralPath $enginePath
  foreach ($functionName in @(
    'Redact-OpenClawText',
    'Format-OpenClawCommandForLog',
    'New-OpenClawStatusRecord',
    'Write-OpenClawStatus',
    'Assert-OpenClawSafeParameters',
    'New-OpenClawTelegramDryRunArtifact',
    'Invoke-OpenClawVerifierChecks'
  )) {
    if ($engine -notmatch "function\s+$functionName\b") { Fail-Audit "Engine module missing required function: $functionName" }
  }
  if ($engine -notmatch 'openclaw\.windows\.native\.status/v1') { Fail-Audit "Engine status JSON schema identifier is missing" }
  if ($engine -notmatch 'ConvertTo-Json\s+-Compress\s+-Depth\s+8') { Fail-Audit "Engine JSON status output must be compressed with sufficient depth" }
  if ($engine -notmatch 'Redact-OpenClawText\s+\$Message') { Fail-Audit "Engine status records must redact messages" }
  if ($engine -notmatch 'Assert-OpenClawSafeParameters') { Fail-Audit "Engine must reject secret-like command-line parameter names" }
  if ($engine -match 'Write-Host.*(token|secret|password|apikey|TELEGRAM_BOT_TOKEN)') { Fail-Audit "Engine must not print credential-bearing values" }
  Write-AuditOk "engine JSON status and redaction checks passed"
}
function Assert-CompanionBuildSmokeChecks([string]$RepoRoot) {
  $installPath = Join-Path $RepoRoot "downloads\Install-OpenClawWindowsNative.ps1"
  $install = Get-Content -Encoding UTF8 -Raw -LiteralPath $installPath
  $expectedLaunchers = @(
    "OpenClaw_01_Start_Gateway.cmd",
    "OpenClaw_02_Status.cmd",
    "OpenClaw_03_Stop_Gateway.cmd",
    "OpenClaw_04_Open_Dashboard.cmd",
    "OpenClaw_05_Approve_Telegram_Pairing.cmd",
    "OpenClaw_06_Telegram_Dry_Run.cmd",
    "OpenClaw_07_Update.cmd"
  )
  foreach ($launcher in $expectedLaunchers) {
    if ($install -notmatch [regex]::Escape($launcher)) { Fail-Audit "Companion launcher missing $launcher" }
  }
  if ($install -notmatch 'set /p PAIRING_CODE=Telegram pairing code:') { Fail-Audit "Telegram pairing launcher must prompt for a pairing code at runtime" }
  if ($install -notmatch 'pnpm\.cmd openclaw pairing approve telegram %PAIRING_CODE%') { Fail-Audit "Telegram pairing launcher must approve the supplied code" }
  if ($install -notmatch '-TelegramDryRunOnly') { Fail-Audit "Telegram dry-run launcher must be available" }
  if ($install -match 'TELEGRAM_BOT_TOKEN=.*' -or $install -match 'bot-token\.txt.*echo') { Fail-Audit "Companion launcher must not embed Telegram credentials" }

  $companionDir = Join-Path $RepoRoot "companion"
  if (Test-Path -LiteralPath $companionDir -PathType Container) {
    foreach ($required in @(
      "package.json",
      "src\main.js",
      "src\styles.css",
      "src-tauri\Cargo.toml",
      "src-tauri\tauri.conf.json",
      "src-tauri\capabilities\default.json",
      "src-tauri\src\main.rs",
      "src-tauri\Cargo.lock",
      "src-tauri\icons\icon.ico"
    )) {
      if (-not (Test-Path -LiteralPath (Join-Path $companionDir $required) -PathType Leaf)) {
        Fail-Audit "Companion build surface missing required file: $required"
      }
    }
    $package = Assert-JsonFile -Path (Join-Path $companionDir "package.json") -Label "companion/package.json"
    $tauri = Assert-JsonFile -Path (Join-Path $companionDir "src-tauri\tauri.conf.json") -Label "companion tauri.conf.json"
    $capabilities = Assert-JsonFile -Path (Join-Path $companionDir "src-tauri\capabilities\default.json") -Label "companion default capabilities"
    foreach ($scriptName in @("dev", "build", "check:rust", "fmt:rust", "dev:frontend", "build:frontend")) {
      if ($package.scripts.PSObject.Properties.Name -notcontains $scriptName) { Fail-Audit "Companion package.json missing script: $scriptName" }
    }
    if ([string]$tauri.build.devUrl -ne "http://127.0.0.1:1420") { Fail-Audit "Companion devUrl must stay loopback-only" }
    if ([string]$tauri.app.security.csp -notmatch "default-src 'self'") { Fail-Audit "Companion CSP must keep a default-src self policy" }
    $permissions = @($capabilities.permissions | ForEach-Object { [string]$_ })
    if ($permissions | Where-Object { $_ -match '(?i)(shell|fs|process|http)' }) { Fail-Audit "Companion default capabilities include privileged permissions" }
  }
  Write-AuditOk "companion launcher and Tauri build smoke checks passed"
}

function Assert-PagesWorkflowMatchesAllowlist([string]$RepoRoot, [string[]]$AllowedPagesFiles) {
  $workflowPath = Join-Path $RepoRoot ".github\workflows\pages.yml"
  $workflow = Get-Content -Encoding UTF8 -Raw -LiteralPath $workflowPath
  if ($workflow -notmatch 'rm -rf public') { Fail-Audit "Pages workflow must rebuild public/ from scratch" }
  if ($workflow -notmatch 'mkdir -p public/assets public/docs public/downloads') { Fail-Audit "Pages workflow must create only the expected static directories" }
  if ($workflow -match 'docs/RELEASE_CHECKLIST\.md') { Fail-Audit "Pages workflow must not publish docs/RELEASE_CHECKLIST.md" }
  if ($workflow -match 'cp\s+-r' -or $workflow -match 'cp\s+\.\s') { Fail-Audit "Pages workflow must not recursively copy broad repository paths" }

  $published = New-Object System.Collections.Generic.List[string]
  $lines = $workflow -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -notmatch '^\s*cp\s+') { continue }
    $command = $line.TrimEnd()
    while ($command.TrimEnd().EndsWith('\')) {
      $i++
      if ($i -ge $lines.Count) { break }
      $command = $command.TrimEnd('\').TrimEnd() + ' ' + $lines[$i].Trim()
    }
    $tokens = [regex]::Matches($command, '"[^"]+"|\S+') | ForEach-Object { $_.Value.Trim('"') }
    if ($tokens.Count -lt 3) { continue }
    $destination = $tokens[-1]
    if ($destination -notmatch '^public(/|$)') { continue }
    for ($t = 1; $t -lt ($tokens.Count - 1); $t++) {
      $source = $tokens[$t]
      if ($source -eq '\') { continue }
      if ($source -match '^(public|mkdir|rm|cp)$') { continue }
      $destinationPath = $destination.TrimEnd('/')
      if ($destinationPath -eq 'public') {
        $published.Add($source.Replace('\', '/'))
      } else {
        $published.Add(($destinationPath.Substring('public/'.Length).TrimEnd('/') + '/' + (Split-Path -Leaf $source)).Replace('\', '/'))
      }
    }
  }

  $actual = @($published | Sort-Object -Unique)
  $expected = @($AllowedPagesFiles | Sort-Object -Unique)
  if (($actual -join '|') -ne ($expected -join '|')) {
    Fail-Audit "Pages workflow published files differ from audit allowlist. Expected: $($expected -join ', '); actual: $($actual -join ', ')"
  }
  Write-AuditOk "Pages workflow static publish list matches audit allowlist"
}

Push-Location -LiteralPath $RepoRoot
try {
  $textExtensions = @(".cmd", ".css", ".html", ".json", ".md", ".ps1", ".txt", ".yml", ".yaml")
  $secretPatterns = @(
    "gh[pousr]_[A-Za-z0-9_]{30,}",
    "github_pat_[A-Za-z0-9_]{20,}_[A-Za-z0-9_]{40,}",
    "sk-[A-Za-z0-9_-]{20,}",
    "xox[baprs]-[A-Za-z0-9-]{20,}",
    "[0-9]{6,}:[A-Za-z0-9_-]{30,}",
    "AIza[0-9A-Za-z_-]{35}",
    "BEGIN [A-Z ]*PRIVATE KEY"
  )
  $localOnlyPatterns = @(
    'C:\\Users\\[^\\\s"`'']+'
  )

  $expectedPayloadFiles = @(
    "OpenClaw_Windows_Native_Installer.cmd",
    "Install-OpenClawWindowsNative.ps1",
    "Verify-OpenClawWindowsNative.ps1",
    "OpenClawWindowsNative.Engine.psm1",
    "Uninstall-OpenClawWindowsNative.ps1",
    "OpenClaw_Windows_Native_User_Manual.md",
    "OpenClaw_Windows_Native_Technical_Spec.md"
  )

  $allowedPagesFiles = @(
    ".nojekyll",
    "index.html",
    "manual.html",
    "release.html",
    "security.html",
    "technical.html",
    "assets/openclaw-native-preview.png",
    "assets/styles.css",
    "docs/OpenClaw_Windows_Native_Technical_Spec.md",
    "docs/OpenClaw_Windows_Native_User_Manual.md",
    "downloads/Build-OpenClawWindowsNativeSetup.ps1",
    "downloads/checksums.sha256",
    "downloads/Install-OpenClawWindowsNative.ps1",
    "downloads/engine/OpenClawWindowsNative.Engine.psm1",
    "downloads/OpenClawWindowsNativeSetup.exe",
    "downloads/OpenClaw_Windows_Native_Installer.cmd",
    "downloads/package-manifest.json",
    "downloads/Uninstall-OpenClawWindowsNative.ps1",
    "downloads/Verify-OpenClawWindowsNative.ps1"
  ) | Sort-Object

  $allSensitivePatterns = $secretPatterns + $localOnlyPatterns

  $psFiles = Get-ChildItem -Path downloads, scripts -Include *.ps1, *.psm1 -Recurse -File
  foreach ($file in $psFiles) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) > $null
    if ($errors.Count -gt 0) {
      Fail-Audit "PowerShell parse failed: $($file.FullName)"
    }
  }
  Write-AuditOk "PowerShell parser checks passed"

  $checksumPath = Join-Path $RepoRoot "downloads\checksums.sha256"
  $checksumLines = Get-Content -LiteralPath $checksumPath
  foreach ($line in $checksumLines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -notmatch "^([a-f0-9]{64})\s+(.+)$") {
      Fail-Audit "Malformed checksum line: $line"
    }
    $expected = $Matches[1]
    $name = $Matches[2].Trim()
    $filePath = Join-Path (Join-Path $RepoRoot "downloads") $name
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
      Fail-Audit "Checksum references missing file: $name"
    }
    $actual = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
      Fail-Audit "Checksum mismatch for $name"
    }
  }
  Write-AuditOk "checksums.sha256 matches tracked download files"

  $textFiles = Get-ChildItem -Recurse -File |
    Where-Object {
      $_.FullName -notmatch "\\.git\\" -and
      $_.FullName -notmatch "\\AppData\\Local\\Temp\\" -and
      $_.FullName -notmatch "\\.artifacts\\" -and
      $textExtensions -contains $_.Extension
    }
  foreach ($pattern in $allSensitivePatterns) {
    $hits = $textFiles | Select-String -Pattern $pattern -ErrorAction SilentlyContinue
    if ($hits) {
      $hits | ForEach-Object { Write-Host "$($_.Path):$($_.LineNumber):$($_.Line)" }
      Fail-Audit "Potential secret or local-only value found: $pattern"
    }
  }
  Write-AuditOk "text secret/local-value scan passed"

  $exePath = Join-Path $RepoRoot "downloads\OpenClawWindowsNativeSetup.exe"
  $bytes = [System.IO.File]::ReadAllBytes($exePath)
  $binaryTexts = @(
    [System.Text.Encoding]::ASCII.GetString($bytes),
    [System.Text.Encoding]::Unicode.GetString($bytes)
  )
  foreach ($pattern in $allSensitivePatterns) {
    foreach ($text in $binaryTexts) {
      if ($text -match $pattern) {
        Fail-Audit "Potential secret or local-only value found in installer binary: $pattern"
      }
    }
  }
  Write-AuditOk "installer binary string scan passed"

  Assert-PackageManifest -RepoRoot $RepoRoot -ExpectedPayloads $expectedPayloadFiles -Patterns $allSensitivePatterns
  Assert-InstallerEngineAndRedactionChecks -RepoRoot $RepoRoot
  Assert-EngineModuleChecks -RepoRoot $RepoRoot
  Assert-CompanionBuildSmokeChecks -RepoRoot $RepoRoot
  Assert-TelegramValidationArtifact -Path $TelegramValidationArtifact -Patterns $allSensitivePatterns

  $htmlFiles = Get-ChildItem -Path $RepoRoot -Filter *.html -File
  foreach ($file in $htmlFiles) {
    $content = Get-Content -Encoding UTF8 -Raw -LiteralPath $file.FullName
    if ($content -notmatch "Content-Security-Policy") { Fail-Audit "$($file.Name) is missing CSP meta" }
    if ($content -notmatch "script-src 'none'") { Fail-Audit "$($file.Name) CSP does not block scripts" }
    if ($content -match "<script\b") { Fail-Audit "$($file.Name) contains script tag" }
    if ($content -match "\sstyle=") { Fail-Audit "$($file.Name) contains inline style" }
    if ($content -match "(href|src)=""http://") { Fail-Audit "$($file.Name) contains insecure http URL" }
    if ($content -match "href=""docs/.*\.md") { Fail-Audit "$($file.Name) links users directly to Markdown docs" }

    $hrefs = [regex]::Matches($content, 'href="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    foreach ($href in $hrefs) {
      if ($href -match "^(https:|mailto:)") { continue }
      if ($href -match "^(http:|javascript:)") { Fail-Audit "$($file.Name) has unsafe href: $href" }
      $pathPart = $href
      $anchor = $null
      if ($href.Contains("#")) {
        $parts = $href.Split("#", 2)
        $pathPart = $parts[0]
        $anchor = $parts[1]
      }
      $targetFile = if ([string]::IsNullOrWhiteSpace($pathPart)) { $file.FullName } else { Join-Path $RepoRoot $pathPart }
      if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
        Fail-Audit "$($file.Name) links to missing target: $href"
      }
      if ($anchor) {
        $targetContent = if ([string]::IsNullOrWhiteSpace($pathPart)) { $content } else { Get-Content -Encoding UTF8 -Raw -LiteralPath $targetFile }
        $targetIds = [regex]::Matches($targetContent, 'id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        if ($targetIds -notcontains $anchor) {
          Fail-Audit "$($file.Name) links to missing anchor: $href"
        }
      }
    }
  }
  Write-AuditOk "HTML security and link checks passed"

  foreach ($relativePath in $allowedPagesFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relativePath) -PathType Leaf)) {
      Fail-Audit "Pages allowlist references missing file: $relativePath"
    }
  }
  if ($allowedPagesFiles -contains "docs/RELEASE_CHECKLIST.md") {
    Fail-Audit "Release checklist must not be published to GitHub Pages"
  }
  Assert-PagesWorkflowMatchesAllowlist -RepoRoot $RepoRoot -AllowedPagesFiles $allowedPagesFiles
  Write-AuditOk "Pages allowlist checks passed"

  $workflowFiles = Get-ChildItem -Path (Join-Path $RepoRoot ".github\workflows") -Filter *.yml -File
  foreach ($workflow in $workflowFiles) {
    $usesLines = Select-String -Path $workflow.FullName -Pattern "uses:\s*[^@\s]+@(.+)$"
    foreach ($line in $usesLines) {
      $ref = $line.Matches[0].Groups[1].Value.Trim()
      if ($ref -notmatch "^[0-9a-f]{40}$") {
        Fail-Audit "Workflow action is not pinned to a 40-char SHA: $($workflow.Name):$($line.LineNumber): $($line.Line.Trim())"
      }
    }
  }
  Write-AuditOk "workflow action pinning checks passed"

  if (-not $SkipGitHistory) {
    $historyPatterns = $secretPatterns -join "|"
    $commits = & git rev-list --all
    foreach ($commit in $commits) {
      $output = & git grep -n -I -E $historyPatterns $commit -- . ":(exclude)downloads/OpenClawWindowsNativeSetup.exe" 2>$null
      if ($LASTEXITCODE -eq 0 -and $output) {
        $output | Write-Host
        Fail-Audit "Potential secret found in git history at $commit"
      }
    }
    Write-AuditOk "git history secret scan passed"
  }
  Write-AuditOk "security audit completed"
} finally {
  Pop-Location
}

exit 0
