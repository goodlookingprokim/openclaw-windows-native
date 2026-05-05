# OpenClaw Windows Native 배포 기술 스펙

작성일: 2026-05-05  
목표: WSL 없이 Windows 네이티브에서 OpenClaw Gateway, Control UI, Telegram bot channel을 설치/운영한다.

## 1. 채택 스택

| 계층 | 선택 |
| --- | --- |
| 설치 제어 | Windows PowerShell 5.1+ |
| 더블클릭 진입점 | CMD wrapper |
| 단일 EXE 패키징 | Windows 내장 IExpress |
| 패키지 설치 | WinGet, npm/Corepack fallback |
| 소스 관리 | Git for Windows |
| 런타임 | Node.js LTS, OpenClaw 요구 최소 `>=22.14.0` |
| 패키지 매니저 | pnpm `10.33.2` |
| 소스 ref | 기본 `main`, 설치 옵션 `-RepoRef <tag-or-commit>` 지원 |
| Gateway 자동실행 | OpenClaw `gateway install`, Windows Task Scheduler/schtasks |
| Telegram 인증 | `channels.telegram.tokenFile` |

## 2. 설계 원칙

- WSL, Docker, Podman을 설치 경로에 넣지 않는다.
- 설치 파일에는 토큰/API key/pairing code를 포함하지 않는다.
- 사용자가 설치 중 직접 선택하는 항목만 로컬 사용자 프로필 아래 저장한다.
- Telegram bot token은 CLI 인자 대신 파일 경로(`--token-file`)로 등록한다.
- Gateway는 loopback `127.0.0.1`과 port `18789`를 기본값으로 사용한다.
- 검증은 빌드 산출물, OpenClaw config, Gateway health, Telegram channel probe를 직접 확인한다.

## 3. 설치 흐름

```text
OpenClawWindowsNativeSetup.exe
  -> OpenClaw_Windows_Native_Installer.cmd
    -> Install-OpenClawWindowsNative.ps1
      1. Git/Node.js/pnpm 확인
      2. 누락 도구 winget 설치 시도
      3. %USERPROFILE%\openclaw-src clone 또는 pull
      4. RepoRef fetch 및 checkout
      5. pnpm install --frozen-lockfile
      6. pnpm build
      7. pnpm ui:build
      8. pnpm openclaw onboard
      9. pnpm openclaw plugins enable telegram
      10. Telegram tokenFile 생성 및 channels add
      11. pnpm openclaw gateway install/start
      12. 바탕화면 운영 실행기 생성
      13. Verify-OpenClawWindowsNative.ps1 실행
```

## 4. 저장 경로

| 경로 | 내용 |
| --- | --- |
| `%USERPROFILE%\openclaw-src` | OpenClaw 소스 및 빌드 산출물 |
| `%USERPROFILE%\.openclaw` | 설정, 로그, 세션, credentials |
| `%USERPROFILE%\.openclaw\credentials\telegram-bot-token.txt` | 사용자가 입력한 Telegram bot token |
| `%USERPROFILE%\Desktop\OpenClaw` | 매뉴얼, 로그, 운영용 CMD 실행기 |
| `%USERPROFILE%\Desktop\OpenClaw\install-logs` | 설치 transcript |

## 5. 보안 처리

- 설치 패키지에는 실제 `openclaw.json`을 포함하지 않는다.
- 설치 스크립트는 token 값을 출력하지 않는다.
- Telegram token은 `Read-Host -AsSecureString`으로 입력받는다.
- token은 로컬 파일에 저장한 뒤 `icacls`로 현재 사용자와 SYSTEM만 접근하도록 ACL을 조정한다.
- CLI에는 `--token <값>` 대신 `--token-file <경로>`를 사용한다.
- 검증 스크립트는 token 원문을 출력하지 않는다.

## 6. 검증 항목

`Verify-OpenClawWindowsNative.ps1`는 다음을 확인한다.

- `WSL_DISTRO_NAME`이 없는 Windows 네이티브 프로세스
- `git.exe`, `node.exe`, `pnpm.cmd`
- Node.js `>=22.14.0`
- `%USERPROFILE%\openclaw-src\.git`
- `dist\index.js`
- `dist\control-ui\index.html`
- `%USERPROFILE%\.openclaw\openclaw.json`
- Gateway config 존재
- Telegram channel enabled
- Telegram credential source 존재
- `pnpm.cmd openclaw --version`
- `pnpm.cmd openclaw plugins list --enabled`
- `pnpm.cmd openclaw gateway health`
- `pnpm.cmd openclaw channels status --probe`
- port `18789` listener

## 7. 공식 참고 근거

- Node.js 공식 다운로드 페이지는 2026-05-05 기준 v24 LTS를 제공한다. https://nodejs.org/en/download
- OpenClaw `package.json`의 engine 조건은 `node >=22.14.0`이다.
- pnpm 공식 문서는 Windows에서 npm 또는 Corepack 설치를 권장하고, Node.js 22/24와 pnpm 10 호환을 명시한다. https://pnpm.io/installation
- Git for Windows 공식 페이지는 winget 설치 명령 `winget install --id Git.Git -e --source winget`을 제공한다. https://git-scm.com/install/windows
- Microsoft WinGet 문서는 `winget install --id <ID> -e`와 agreement 옵션을 지원한다. https://learn.microsoft.com/windows/package-manager/winget/install
- OpenClaw CLI 문서는 `channels add`, `channels status --probe`, `gateway install/start/stop` 흐름을 제공한다. https://docs.openclaw.ai/cli
- OpenClaw Telegram 문서는 BotFather token, `TELEGRAM_BOT_TOKEN`, `tokenFile`, pairing 승인 흐름을 제공한다. https://docs.openclaw.ai/channels/telegram
