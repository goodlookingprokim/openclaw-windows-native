# OpenClaw Windows Native Companion

[공개 사이트 / Public site](https://goodlookingprokim.github.io/openclaw-windows-native/) · [설치 가이드](manual.html) · [Release](https://github.com/goodlookingprokim/openclaw-windows-native/releases/tag/v2026.05.05-open-design-refresh)

OpenClaw를 WSL 없이 Windows 네이티브 환경에서 설치하고, Telegram 봇 연결 전 dry-run으로 안전하게 검증하도록 돕는 설치 패키지와 GitHub Pages 안내 사이트입니다.

## 이번 디자인 개선

- `nexu-io/open-design`의 로컬 우선·디자인 시스템 접근을 참고해 GitHub Pages를 더 조용하고 명확한 설치 중심 화면으로 개편했습니다.
- 외부 코드나 자산은 복사하지 않고, 이 저장소의 정적 HTML/CSS로 독립 구현했습니다.
- 한국어/English CSS-only 언어 탭을 유지합니다.
- CSP는 `script-src 'none'`이며 JavaScript를 사용하지 않습니다.
- Telegram 민감 값은 GitHub, Pages, 릴리스 artifact에 포함하지 않습니다.

## 빠른 시작

1. [Download page](release.html#download)에서 `OpenClawWindowsNativeSetup.exe`를 받습니다.
2. SHA-256을 확인합니다.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
```

Expected:

```text
5204fa42eaecce7fc40b75afa60f67c30fdbf1814848e62c70d21a51acf7d883
```

3. Windows PowerShell 또는 CMD에서 설치 파일을 실행합니다.
4. 실제 BotFather 값을 입력하기 전에 dry-run 검증을 먼저 실행합니다.
5. 사용자가 직접 승인한 Telegram 봇 값을 로컬 tokenFile에만 저장하고 pairing을 확인합니다.

## 검증 기준

- Native Windows package: `OpenClawWindowsNativeSetup.exe`
- Default OpenClaw source: `https://github.com/openclaw/openclaw.git`
- Default ref: `main`
- Node.js floor: `node >=22.14.0`
- Default Gateway port: `18789`
- Security posture: no published secrets, no raw token command argument, static Pages with no script execution

## 문서

- [Setup guide](manual.html)
- [Security guide](security.html)
- [Technical notes](technical.html)
- [Release download](release.html)

## Not tested by automation

Live Telegram send/receive requires the user's own BotFather value and pairing approval, so it remains a user-controlled final check.
