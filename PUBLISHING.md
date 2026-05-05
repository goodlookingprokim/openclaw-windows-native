# Publishing Guide

Recommended repository name: `openclaw-windows-native`

Expected public URLs:

- Repository: `https://github.com/goodlookingprokim/openclaw-windows-native`
- GitHub Pages: `https://goodlookingprokim.github.io/openclaw-windows-native/`
- Latest release: `https://github.com/goodlookingprokim/openclaw-windows-native/releases/latest`

## One-time publish

Authenticate GitHub CLI:

```powershell
gh auth login
```

Then publish:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-GitHub.ps1
```

Or double-click:

```text
Publish-ToGitHub.cmd
```

If browser login is not available, use a GitHub Personal Access Token with `repo` and `workflow` scopes:

```text
Publish-WithToken.cmd
```

The token helper keeps the token in the current process only and does not write it to the repository.

The script will:

1. Check GitHub CLI auth.
2. Create `goodlookingprokim/openclaw-windows-native` if it does not exist.
3. Push `main`.
4. Enable GitHub Pages with the Actions workflow.
5. Push an initial release tag.

## Normal code changes

```powershell
git status
git add .
git commit -m "Describe the change"
git push origin main
```

## Release changes

Use a date tag for classroom-friendly releases:

```powershell
git tag v2026.05.05
git push origin main --tags
```

The release workflow uploads:

- `downloads/OpenClawWindowsNativeSetup.exe`
- `downloads/checksums.sha256`
- installer/verifier/uninstaller scripts
- user manual
- technical spec

Use [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) before every public release.

## Pages troubleshooting

If the Pages URL is not live yet, open the repository settings:

```text
Settings -> Pages -> Build and deployment -> Source: GitHub Actions
```

Then rerun the `Deploy GitHub Pages` workflow from the Actions tab.
