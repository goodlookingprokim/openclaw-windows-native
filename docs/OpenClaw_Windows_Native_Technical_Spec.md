# OpenClaw Windows Native 배포 기술 스펙

작성일: 2026-05-05
목표: WSL 없이 Windows 네이티브에서 OpenClaw Gateway, Control UI, Telegram bot channel, Companion shell을 설치/운영한다.

## 채택 스택

| 계층 | 선택 |
| --- | --- |
| 설치 제어 | Windows PowerShell 5.1+ |
| 더블클릭 진입점 | CMD wrapper |
| 단일 EXE 패키징 | Windows 내장 IExpress |
| 구조화 로직 | `OpenClawWindowsNative.Engine.psm1` |
| 패키지 설치 | WinGet, npm/Corepack fallback |
| 소스 관리 | Git for Windows |
| 런타임 | Node.js `>=22.14.0` (`node >=22.14.0`) |
| 패키지 매니저 | pnpm `10.33.2` |
| Gateway | loopback `127.0.0.1`, port `18789`, token auth |
| Telegram 인증 | `channels.telegram.tokenFile` |
| Companion | Tauri v2 Windows executable plus MSI/NSIS build surface |

## 설치 파이프라인

```text
OpenClawWindowsNativeSetup.exe
  -> OpenClaw_Windows_Native_Installer.cmd
    -> Install-OpenClawWindowsNative.ps1
      -> engine/OpenClawWindowsNative.Engine.psm1
      1. Git/Node.js/pnpm 확인
      2. 누락 도구 winget 또는 npm/Corepack fallback
      3. %USERPROFILE%\openclaw-src clone/update
      4. RepoRef fetch/checkout
      5. pnpm install --frozen-lockfile
      6. pnpm build
      7. pnpm ui:build
      8. pnpm openclaw onboard
      9. Telegram tokenFile 생성 및 channels add
      10. gateway install/start
      11. desktop helper 생성
      12. verifier 실행
```

## 보안 경계

- 설치 패키지와 Pages에는 실제 token, API key, pairing code, local state, logs를 넣지 않는다.
- Telegram token은 CLI 인자 대신 사용자 로컬 파일 경로로 등록한다.
- token 파일은 `%USERPROFILE%\.openclaw\credentials`에 저장하고 ACL을 조정한다.
- status/JSON 출력은 secret-like argument를 redact한다.
- GitHub Pages는 HTML/CSS만 배포하고 CSP에서 `script-src 'none'`을 유지한다.

## 검증 항목

`Verify-OpenClawWindowsNative.ps1`와 engine verifier는 다음을 확인한다.

- WSL이 아닌 native Windows PowerShell/CMD context.
- Git, Node.js, pnpm 존재 및 Node.js 최소 버전.
- `%USERPROFILE%\openclaw-src\.git`, `dist\index.js`, `dist\control-ui\index.html`.
- `%USERPROFILE%\.openclaw\openclaw.json` 및 Gateway config.
- Telegram plugin/channel credential source.
- `pnpm.cmd openclaw gateway health`.
- `pnpm.cmd openclaw channels status --probe`.
- port `18789` listener.
- `-TelegramDryRunOnly` redacted artifact 생성.

Dry-run artifact:

```text
%USERPROFILE%\.openclaw\validation\telegram-validation.dry-run.json
```

## Release assets

현재 release는 다음 12개 asset을 검증 대상으로 둔다.

- `Build-OpenClawWindowsNativeSetup.ps1`
- `OpenClawWindowsNativeSetup.exe`
- `checksums.sha256`
- `Install-OpenClawWindowsNative.ps1`
- `OpenClawWindowsNative.Engine.psm1`
- `OpenClaw_Windows_Native_Installer.cmd`
- `package-manifest.json`
- `Verify-OpenClawWindowsNative.ps1`
- `Uninstall-OpenClawWindowsNative.ps1`
- `VALIDATION_ARTIFACTS.md`
- `OpenClaw_Windows_Native_User_Manual.md`
- `OpenClaw_Windows_Native_Technical_Spec.md`

Installer SHA-256은 release asset `checksums.sha256`에서 확인합니다.

## English summary

The kit packages a native Windows install path with PowerShell 5.1+, a CMD entrypoint, IExpress EXE, structured engine module, tokenFile-based Telegram setup, redacted JSON status, dry-run validation, and a build-verified Tauri v2 Companion shell. Live Telegram send/receive remains outside dry-run and requires user-controlled credentials plus pairing approval.
