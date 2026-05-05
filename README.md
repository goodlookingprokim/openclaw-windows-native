# OpenClaw Windows Native Companion

[한국어](#한국어) | [English](#english)

Public site / 공개 사이트: https://goodlookingprokim.github.io/openclaw-windows-native/

---

## 한국어

목표: 참석자가 설치 파일을 실행하고, 본인 Telegram 봇 토큰과 모델 인증을 직접 입력해 Windows 네이티브 환경에서 OpenClaw를 사용한다.

어렵게 생각하면 설치는 큰 일처럼 보입니다. 이 프로젝트는 그 큰 일을 작은 행동으로 나눕니다. 파일을 받고, 파일 지문을 확인하고, 설치하고, 실제 토큰 전에 dry-run을 해보고, 마지막에 Telegram 대화를 확인합니다.

1. `OpenClawWindowsNativeSetup.exe`를 다운로드합니다.
2. SHA-256 값이 사이트와 같은지 확인합니다.
3. Windows PowerShell/CMD에서 설치 파일을 실행합니다. WSL은 사용하지 않습니다.
4. Telegram 실제 토큰을 넣기 전에 dry-run으로 설정 흐름을 연습합니다.
5. BotFather 토큰은 사용자 PC의 로컬 파일에만 저장합니다.
6. pairing code를 승인하고 Telegram 대화를 확인합니다.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
Get-Content .\checksums.sha256
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\downloads\Verify-OpenClawWindowsNative.ps1 -TelegramDryRunOnly
```

SHA-256:

```text
a1a1154f8816c3fa26100224182df9842c00777026cda1b6afff248d501781ce
```

설치기는 민감정보를 포함하지 않습니다. Telegram 봇 토큰, Gateway token, 모델 API key/OAuth 정보는 실행 중 사용자가 직접 입력하거나 OpenClaw 공식 온보딩에서 직접 선택합니다.

---

## English

OpenClaw Windows Native Companion helps users install OpenClaw on Windows without WSL and reach the first Telegram conversation safely.

The guide explains setup as small actions: download the file, compare its fingerprint, run the installer, practice Telegram setup with dry-run, enter real credentials only on your own PC, approve pairing, and verify the channel.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
Get-Content .\checksums.sha256
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\downloads\Verify-OpenClawWindowsNative.ps1 -TelegramDryRunOnly
```

Current installer SHA-256:

```text
a1a1154f8816c3fa26100224182df9842c00777026cda1b6afff248d501781ce
```

Dry-run does not contact Telegram. It creates a redacted validation artifact and keeps live send/receive separate from simulated validation.

### Included

- Structured PowerShell engine
- Setup, verify, and uninstall scripts
- Single-file Windows setup package
- Build-verified Tauri v2 Companion shell
- Bilingual GitHub Pages guide
- Telegram dry-run and validation artifact checks

### Security boundary

- No real credentials are committed, embedded, published, or passed as command-line values.
- Telegram bot tokens are registered through user-local token files.
- Logs and JSON status output are redacted.

### License

Installer scripts, documentation, Companion shell, and the static site are released under the MIT License. OpenClaw itself is a separate project governed by its own maintainers and license.
