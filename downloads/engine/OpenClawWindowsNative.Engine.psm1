Set-StrictMode -Version 2.0

$script:OpenClawSecretPatterns = New-Object System.Collections.Generic.List[string]
@(
  '(?i)(token|secret|password|apikey|api_key|authorization|bearer)\s*[:=]\s*[^\s''"]+',
  '(?i)(bot[0-9]{6,}:[A-Za-z0-9_-]{20,})'
) | ForEach-Object { [void]$script:OpenClawSecretPatterns.Add($_) }

function Add-OpenClawSecretPattern {
  param([Parameter(Mandatory=$true)][string]$Pattern)
  if (-not [string]::IsNullOrWhiteSpace($Pattern)) {
    [void]$script:OpenClawSecretPatterns.Add($Pattern)
  }
}

function Redact-OpenClawText {
  param([AllowNull()][string]$Text)
  if ($null -eq $Text) { return $null }
  $redacted = $Text
  foreach ($pattern in $script:OpenClawSecretPatterns) {
    $redacted = [regex]::Replace($redacted, $pattern, {
      param($m)
      $value = $m.Value
      $separator = [regex]::Match($value, '[:=]')
      if ($separator.Success) {
        return $value.Substring(0, $separator.Index + 1) + '<redacted>'
      }
      return '<redacted>'
    })
  }
  return $redacted
}

function Format-OpenClawCommandForLog {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [AllowNull()][string[]]$Arguments
  )
  $safeArgs = @()
  $sensitiveNext = $false
  foreach ($arg in @($Arguments)) {
    if ($sensitiveNext) {
      $safeArgs += '<redacted>'
      $sensitiveNext = $false
      continue
    }
    if ($arg -match '(?i)^--?(token|secret|password|api-key|apikey|authorization|bot-token)(:|=)?') {
      if ($arg -match '=') {
        $safeArgs += ([regex]::Replace($arg, '=(.*)$', '=<redacted>'))
      } else {
        $safeArgs += $arg
        $sensitiveNext = $true
      }
      continue
    }
    $safeArgs += (Redact-OpenClawText $arg)
  }
  return (Redact-OpenClawText (($FilePath, ($safeArgs -join ' ')) -join ' ').Trim())
}

function New-OpenClawStatusRecord {
  param(
    [ValidateSet('info','ok','pass','warn','fail','error')][string]$Level,
    [Parameter(Mandatory=$true)][string]$Message,
    [hashtable]$Data,
    [string]$Check
  )
  $record = [ordered]@{
    schema = 'openclaw.windows.native.status/v1'
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    level = $Level
    message = (Redact-OpenClawText $Message)
  }
  if ($Check) { $record.check = $Check }
  if ($Data) {
    $safe = [ordered]@{}
    foreach ($key in $Data.Keys) {
      $value = $Data[$key]
      if ($value -is [string]) { $safe[$key] = Redact-OpenClawText $value } else { $safe[$key] = $value }
    }
    $record.data = $safe
  }
  return [pscustomobject]$record
}

function Write-OpenClawStatus {
  param(
    [ValidateSet('info','ok','pass','warn','fail','error')][string]$Level = 'info',
    [Parameter(Mandatory=$true)][string]$Message,
    [hashtable]$Data,
    [string]$Check,
    [switch]$Json
  )
  $record = New-OpenClawStatusRecord -Level $Level -Message $Message -Data $Data -Check $Check
  if ($Json) {
    $record | ConvertTo-Json -Compress -Depth 8 | Write-Output
    return
  }
  $prefix = '[' + $Level.ToUpperInvariant() + ']'
  $color = 'Gray'
  switch ($Level) {
    'ok' { $color = 'Green' }
    'pass' { $color = 'Green' }
    'warn' { $color = 'Yellow' }
    'fail' { $color = 'Red' }
    'error' { $color = 'Red' }
  }
  Write-Host "$prefix $($record.message)" -ForegroundColor $color
}

function Assert-OpenClawSafeParameters {
  param([hashtable]$BoundParameters)
  foreach ($name in @($BoundParameters.Keys)) {
    if ($name -match '(?i)(token|secret|password|apikey|api[_-]?key|credential)') {
      throw "Unsafe command-line parameter '$name'. Secrets must be provided by secure prompt or by a user-local secret file, never as script arguments."
    }
  }
}

function Read-OpenClawPlainSecret {
  param([Parameter(Mandatory=$true)][string]$Prompt)
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

function Protect-OpenClawSecretFile {
  param([Parameter(Mandatory=$true)][string]$Path)
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  & icacls.exe $Path /inheritance:r | Out-Null
  & icacls.exe $Path /grant:r "${identity}:F" "SYSTEM:F" | Out-Null
}

function Test-OpenClawCommandExists {
  param([Parameter(Mandatory=$true)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function New-OpenClawVerifierResult {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [ValidateSet('pass','warn','fail')][string]$Level,
    [Parameter(Mandatory=$true)][string]$Message,
    [hashtable]$Data
  )
  [pscustomobject]@{
    name = $Name
    level = $Level
    message = (Redact-OpenClawText $Message)
    data = $Data
  }
}

function Invoke-OpenClawVerifierChecks {
  param(
    [Parameter(Mandatory=$true)][string]$RepoDir,
    [Parameter(Mandatory=$true)][string]$StateDir,
    [Parameter(Mandatory=$true)][int]$Port,
    [version]$MinimumNode = [version]'22.14.0'
  )

  $results = New-Object System.Collections.Generic.List[object]

  if ($env:WSL_DISTRO_NAME) {
    [void]$results.Add((New-OpenClawVerifierResult -Name 'native-windows' -Level 'fail' -Message "Running inside WSL: $env:WSL_DISTRO_NAME"))
  } else {
    [void]$results.Add((New-OpenClawVerifierResult -Name 'native-windows' -Level 'pass' -Message 'Running in native Windows PowerShell/CMD context'))
  }

  foreach ($cmd in @('git.exe', 'node.exe', 'pnpm.cmd')) {
    if (Test-OpenClawCommandExists $cmd) {
      [void]$results.Add((New-OpenClawVerifierResult -Name "command:$cmd" -Level 'pass' -Message "$cmd found"))
    } else {
      [void]$results.Add((New-OpenClawVerifierResult -Name "command:$cmd" -Level 'fail' -Message "$cmd missing"))
    }
  }

  if (Test-OpenClawCommandExists 'node.exe') {
    try {
      $rawNode = (& node.exe -v 2>$null)
      $nodeVersion = [version]($rawNode.Trim().TrimStart('v'))
      if ($nodeVersion -ge $MinimumNode) {
        [void]$results.Add((New-OpenClawVerifierResult -Name 'node-version' -Level 'pass' -Message "Node.js version $nodeVersion meets >= $MinimumNode" -Data @{ version = $nodeVersion.ToString() }))
      } else {
        [void]$results.Add((New-OpenClawVerifierResult -Name 'node-version' -Level 'fail' -Message "Node.js version $nodeVersion is older than $MinimumNode" -Data @{ version = $nodeVersion.ToString() }))
      }
    } catch {
      [void]$results.Add((New-OpenClawVerifierResult -Name 'node-version' -Level 'fail' -Message 'Could not parse Node.js version'))
    }
  }

  $repoGit = Join-Path $RepoDir '.git'
  if (Test-Path -LiteralPath $repoGit -PathType Container) { [void]$results.Add((New-OpenClawVerifierResult -Name 'repo' -Level 'pass' -Message 'OpenClaw repository exists')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'repo' -Level 'fail' -Message "OpenClaw repository missing: $RepoDir")) }
  if (Test-Path -LiteralPath (Join-Path $RepoDir 'dist\index.js') -PathType Leaf) { [void]$results.Add((New-OpenClawVerifierResult -Name 'cli-build' -Level 'pass' -Message 'OpenClaw CLI build exists')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'cli-build' -Level 'fail' -Message 'OpenClaw CLI build missing: dist\index.js')) }
  if (Test-Path -LiteralPath (Join-Path $RepoDir 'dist\control-ui\index.html') -PathType Leaf) { [void]$results.Add((New-OpenClawVerifierResult -Name 'ui-build' -Level 'pass' -Message 'Control UI build exists')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'ui-build' -Level 'fail' -Message 'Control UI build missing: dist\control-ui\index.html')) }

  $configPath = Join-Path $StateDir 'openclaw.json'
  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    [void]$results.Add((New-OpenClawVerifierResult -Name 'config-file' -Level 'pass' -Message 'OpenClaw config exists'))
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      if ($cfg.gateway) { [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-config' -Level 'pass' -Message 'Gateway config exists')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-config' -Level 'warn' -Message 'Gateway config not found in openclaw.json')) }
      if ($cfg.channels.telegram.enabled -eq $true) { [void]$results.Add((New-OpenClawVerifierResult -Name 'telegram-enabled' -Level 'pass' -Message 'Telegram channel enabled')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'telegram-enabled' -Level 'warn' -Message 'Telegram channel is not enabled yet')) }
      if ($cfg.channels.telegram.tokenFile -or $cfg.channels.telegram.botToken -or $env:TELEGRAM_BOT_TOKEN) { [void]$results.Add((New-OpenClawVerifierResult -Name 'telegram-credential' -Level 'pass' -Message 'Telegram bot credential is configured or available')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'telegram-credential' -Level 'warn' -Message 'Telegram bot credential not detected')) }
    } catch {
      [void]$results.Add((New-OpenClawVerifierResult -Name 'config-json' -Level 'fail' -Message 'openclaw.json is not valid JSON'))
    }
  } else {
    [void]$results.Add((New-OpenClawVerifierResult -Name 'config-file' -Level 'fail' -Message "OpenClaw config missing: $configPath"))
  }

  if ((Test-OpenClawCommandExists 'pnpm.cmd') -and (Test-Path -LiteralPath $RepoDir -PathType Container)) {
    Push-Location -LiteralPath $RepoDir
    try {
      & pnpm.cmd openclaw --version | Out-Host
      if ($LASTEXITCODE -eq 0) { [void]$results.Add((New-OpenClawVerifierResult -Name 'openclaw-cli' -Level 'pass' -Message 'OpenClaw CLI runs')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'openclaw-cli' -Level 'fail' -Message 'OpenClaw CLI failed')) }

      & pnpm.cmd openclaw plugins list --enabled | Tee-Object -Variable pluginsOut | Out-Null
      if ($LASTEXITCODE -eq 0 -and ($pluginsOut -match 'telegram')) { [void]$results.Add((New-OpenClawVerifierResult -Name 'telegram-plugin' -Level 'pass' -Message 'Telegram plugin listed as enabled')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'telegram-plugin' -Level 'warn' -Message 'Telegram plugin is not listed as enabled')) }

      & pnpm.cmd openclaw gateway health | Tee-Object -Variable healthOut | Out-Null
      if ($LASTEXITCODE -eq 0) { [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-health' -Level 'pass' -Message 'Gateway health command succeeded')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-health' -Level 'warn' -Message 'Gateway health command failed; start the gateway and rerun verification')) }

      & pnpm.cmd openclaw channels status --probe | Out-Host
      if ($LASTEXITCODE -eq 0) { [void]$results.Add((New-OpenClawVerifierResult -Name 'channel-status' -Level 'pass' -Message 'Channel status command succeeded')) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'channel-status' -Level 'warn' -Message 'Channel status probe failed or needs pairing/token setup')) }
    } finally {
      Pop-Location
    }
  }

  try {
    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -gt 0) { [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-port' -Level 'pass' -Message "Port $Port is listening" -Data @{ port = $Port })) } else { [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-port' -Level 'warn' -Message "No listener on port $Port" -Data @{ port = $Port })) }
  } catch {
    [void]$results.Add((New-OpenClawVerifierResult -Name 'gateway-port' -Level 'warn' -Message "Could not inspect TCP port $Port" -Data @{ port = $Port }))
  }

  return $results.ToArray()
}

Export-ModuleMember -Function @(
  'Add-OpenClawSecretPattern',
  'Redact-OpenClawText',
  'Format-OpenClawCommandForLog',
  'New-OpenClawStatusRecord',
  'Write-OpenClawStatus',
  'Assert-OpenClawSafeParameters',
  'Read-OpenClawPlainSecret',
  'Protect-OpenClawSecretFile',
  'Test-OpenClawCommandExists',
  'New-OpenClawVerifierResult',
  'Invoke-OpenClawVerifierChecks'
)
