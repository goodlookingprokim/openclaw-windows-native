# OpenClaw Windows Native Companion

Windows에서 WSL 없이 OpenClaw를 설치하고 Telegram으로 실제 대화까지 이어지도록 만든 네이티브 온보딩 프로젝트입니다.

Public site: https://goodlookingprokim.github.io/openclaw-windows-native/

## What changed

OpenClaw Windows Native is moving from a script/manual kit into a guided Companion journey:

1. **Download** the Windows setup package.
2. **Run guided setup** for Git, Node.js, pnpm, OpenClaw source, build, and gateway checks.
3. **Connect Telegram** with user-controlled BotFather token entry and pairing approval.
4. **Verify conversation** instead of stopping at "installed".
5. **Repair/update** with structured diagnostics and redacted logs.

The repository now includes:

- A structured PowerShell engine: `downloads/engine/OpenClawWindowsNative.Engine.psm1`
- Backward-compatible setup and verify scripts under `downloads/`
- A rebuilt setup package: `downloads/OpenClawWindowsNativeSetup.exe`
- A build-verified Tauri v2 Companion shell under `companion/`
- A redesigned static GitHub Pages experience
- Telegram validation artifact checks documented in `docs/VALIDATION_ARTIFACTS.md`

## Quick start

1. Open the GitHub Pages site.
2. Download `OpenClawWindowsNativeSetup.exe`.
3. Run the installer on native Windows PowerShell/CMD, not WSL.
4. Follow the guided setup and Telegram steps.
5. Confirm OpenClaw can exchange messages through Telegram.

Fallback script path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\downloads\Install-OpenClawWindowsNative.ps1
```

Machine-readable verification:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\downloads\Verify-OpenClawWindowsNative.ps1 -JsonStatus
```

## Security boundary

- Telegram/provider credentials are never committed, embedded, published, or passed as command-line token values.
- Telegram bot tokens are entered by the user and registered by user-local token file path.
- Logs and JSON status output are redacted by the shared engine.
- Release checks scan scripts, HTML, manifests, installer strings, workflow pinning, checksums, and git history.

Run local validation:

```powershell
.\scripts\Test-ValidationArtifactFixtures.ps1
.\scripts\Test-SecurityAudit.ps1
```

## Companion development

```powershell
cd companion
npm install
npm run fmt:rust
npm run check:rust
npm run build:frontend
npm run build
```

Full Tauri packaging requires Rust/Cargo and the Tauri build prerequisites on Windows.

## Repository name

The repository name stays `openclaw-windows-native` to preserve the public URL and release history.

## License

Installer scripts, documentation, Companion shell, and the static site are released under the MIT License. OpenClaw itself is a separate project governed by its own maintainers and license.
