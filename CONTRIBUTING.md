# Contributing

This repository is intentionally small and practical.

## Change process

1. Keep user-facing installation simple.
2. Do not commit credentials, tokens, logs containing credentials, or local `.openclaw` state.
3. Update the manual when installer behavior changes.
4. Run the verifier before publishing a release.
5. Update `CHANGELOG.md`.
6. Push changes through Git with clear commit messages.

## Release process

1. Update files under `downloads/`, `docs/`, and the landing page if needed.
2. Verify SHA-256 in `downloads/checksums.sha256`.
3. Commit changes.
4. Tag a release:

```powershell
git tag vYYYY.MM.DD
git push origin main --tags
```

The release workflow uploads the installer, checksum file, scripts, and docs to the GitHub Release.
