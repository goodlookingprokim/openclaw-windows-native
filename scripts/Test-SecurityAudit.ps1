param(
  [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [switch]$SkipGitHistory
)

$ErrorActionPreference = "Stop"

function Write-AuditOk([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Fail-Audit([string]$Message) {
  throw "[SECURITY AUDIT] $Message"
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

  $psFiles = Get-ChildItem -Path downloads, scripts -Filter *.ps1 -File
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
      $textExtensions -contains $_.Extension
    }
  foreach ($pattern in ($secretPatterns + $localOnlyPatterns)) {
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
  foreach ($pattern in ($secretPatterns + $localOnlyPatterns)) {
    foreach ($text in $binaryTexts) {
      if ($text -match $pattern) {
        Fail-Audit "Potential secret or local-only value found in installer binary: $pattern"
      }
    }
  }
  Write-AuditOk "installer binary string scan passed"

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
    "downloads/OpenClawWindowsNativeSetup.exe",
    "downloads/OpenClaw_Windows_Native_Installer.cmd",
    "downloads/package-manifest.json",
    "downloads/Uninstall-OpenClawWindowsNative.ps1",
    "downloads/Verify-OpenClawWindowsNative.ps1"
  ) | Sort-Object
  foreach ($relativePath in $allowedPagesFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relativePath) -PathType Leaf)) {
      Fail-Audit "Pages allowlist references missing file: $relativePath"
    }
  }
  if ($allowedPagesFiles -contains "docs/RELEASE_CHECKLIST.md") {
    Fail-Audit "Release checklist must not be published to GitHub Pages"
  }
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
} finally {
  Pop-Location
}
