# Release Checklist

Use this checklist whenever installer files, docs, or the landing page change.

## Before commit

- Run the installer build or copy the updated installer into `downloads/`.
- Update `downloads/checksums.sha256`.
- Update `docs/OpenClaw_Windows_Native_User_Manual.md` if user-facing behavior changed.
- Update `docs/OpenClaw_Windows_Native_Technical_Spec.md` if dependencies, paths, security handling, or workflow changed.
- Update `CHANGELOG.md`.
- Confirm no real token, API key, pairing code, local `.openclaw` state, or install log was added.

## Local verification

```powershell
$repo = Join-Path $env:USERPROFILE "Desktop\OpenClaw\openclaw-windows-native"
$hash = (Get-FileHash "$repo\downloads\OpenClawWindowsNativeSetup.exe" -Algorithm SHA256).Hash.ToLowerInvariant()
Select-String "$repo\downloads\checksums.sha256" -Pattern $hash

Get-ChildItem "$repo\downloads" -Filter *.ps1 | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) > $null
  if ($errors.Count) { throw "Parse failed: $($_.Name)" }
}
```

## Commit and publish

```powershell
git status
git add .
git commit -m "Describe the release change"
git tag vYYYY.MM.DD
git push origin main --tags
```

Or run:

```powershell
.\Publish-ToGitHub.cmd
```

## After publish

- Confirm the repository is reachable.
- Confirm the GitHub Pages deployment workflow is green.
- Confirm the release workflow created a release for the pushed tag.
- Open the Pages URL and test the installer download link.
- Compare the downloaded installer hash with `downloads/checksums.sha256`.
