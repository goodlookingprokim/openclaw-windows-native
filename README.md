# OpenClaw Windows Native Companion

[공개 사이트 / Public site](https://goodlookingprokim.github.io/openclaw-windows-native/) · [설치 가이드](manual.html) · [Release](https://github.com/goodlookingprokim/openclaw-windows-native/releases/tag/v2026.05.05-language-tabs)

## 한국어

OpenClaw Windows Native Companion은 WSL 없이 Windows에서 OpenClaw를 설치하고 Telegram으로 첫 대화까지 확인하도록 돕는 배포 키트입니다.

사용자는 큰 절차를 작은 행동으로 진행합니다.

1. `OpenClawWindowsNativeSetup.exe`를 다운로드합니다.
2. SHA-256 지문을 확인합니다.
3. Windows PowerShell/CMD에서 설치합니다.
4. 실제 Telegram 토큰 전에 dry-run을 실행합니다.
5. BotFather 토큰은 사용자 PC의 로컬 `tokenFile`에만 저장합니다.
6. pairing을 승인하고 Gateway health와 channel probe를 확인합니다.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
Get-Content .\checksums.sha256
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\downloads\Verify-OpenClawWindowsNative.ps1 -TelegramDryRunOnly
```

SHA-256:

```text
5204fa42eaecce7fc40b75afa60f67c30fdbf1814848e62c70d21a51acf7d883
```

포함 내용: PowerShell engine, 단일 EXE 설치 파일, verify/uninstall script, Tauri v2 Companion shell, JSON/redacted status, Telegram dry-run validation, 한/영 CSS 탭 GitHub Pages.

## English

OpenClaw Windows Native Companion helps users install OpenClaw on Windows without WSL and reach the first Telegram conversation safely.

The flow is intentionally small: download, compare the fingerprint, install, run Telegram dry-run, store real credentials only on your own PC, approve pairing, and verify the channel.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
Get-Content .\checksums.sha256
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\downloads\Verify-OpenClawWindowsNative.ps1 -TelegramDryRunOnly
```

Current installer SHA-256:

```text
5204fa42eaecce7fc40b75afa60f67c30fdbf1814848e62c70d21a51acf7d883
```

Included: structured PowerShell engine, single-file Windows setup package, setup/verify/uninstall scripts, build-verified Tauri v2 Companion shell, JSON/redacted status, Telegram dry-run validation, and Korean/English CSS-tab GitHub Pages.

## Security boundary

- No real credentials are committed, embedded, published, or passed as command-line values.
- Telegram bot tokens are registered through user-local token files.
- Logs, JSON status output, and validation artifacts are redacted.
- Dry-run does not prove live Telegram send/receive; live testing requires user-controlled BotFather token and pairing approval.

## License

Installer scripts, documentation, Companion shell, and the static site are released under the MIT License. OpenClaw itself is a separate project governed by its own maintainers and license.
