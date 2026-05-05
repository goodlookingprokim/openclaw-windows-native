# OpenClaw Windows Native Companion

[공개 사이트](https://goodlookingprokim.github.io/openclaw-windows-native/) · [설치 가이드](manual.html) · [Release](https://github.com/goodlookingprokim/openclaw-windows-native/releases/tag/v2026.05.06-korean-only-pages)

OpenClaw를 WSL 없이 Windows 네이티브 환경에서 설치하고, Telegram 봇 연결 전 dry-run으로 안전하게 검증하도록 돕는 설치 패키지와 GitHub Pages 안내 사이트입니다.

## 이번 개선

- GitHub Pages의 언어 전환 UI를 제거하고 한국어 단일 안내로 정리했습니다.
- 로컬 OpenClaw 작업 폴더의 `open-design` sibling 디렉터리에 `nexu-io/open-design`를 source 설치해 앞으로 디자인 참고 도구로 활용할 수 있게 했습니다.
- 외부 코드나 자산은 복사하지 않고, 이 저장소의 정적 HTML/CSS로 독립 구현했습니다.
- CSP는 `script-src 'none'`이며 JavaScript를 사용하지 않습니다.
- Telegram 민감 값은 GitHub, Pages, 릴리스 artifact에 포함하지 않습니다.

## 빠른 시작

1. [다운로드 페이지](release.html#download)에서 `OpenClawWindowsNativeSetup.exe`를 받습니다.
2. SHA-256을 확인합니다.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
```

기대 값:

```text
5204fa42eaecce7fc40b75afa60f67c30fdbf1814848e62c70d21a51acf7d883
```

3. Windows PowerShell 또는 CMD에서 설치 파일을 실행합니다.
4. 실제 BotFather 값을 입력하기 전에 dry-run 검증을 먼저 실행합니다.
5. 사용자가 직접 승인한 Telegram 봇 값을 로컬 tokenFile에만 저장하고 pairing을 확인합니다.

## 검증 기준

- Windows 네이티브 패키지: `OpenClawWindowsNativeSetup.exe`
- 기본 OpenClaw source: `https://github.com/openclaw/openclaw.git`
- 기본 ref: `main`
- Node.js 기준: `node >=22.14.0`
- 기본 Gateway port: `18789`
- 보안 기준: 공개 비밀 값 없음, raw token command argument 없음, script 실행 없는 정적 Pages

## 문서

- [설치 가이드](manual.html)
- [보안 가이드](security.html)
- [기술 노트](technical.html)
- [다운로드](release.html)

## 자동화로 검증하지 않는 항목

실제 Telegram 송수신은 사용자의 BotFather 값과 pairing 승인이 필요하므로, 사용자 환경에서 최종 확인합니다.
