# OpenClaw Windows Native 설치 및 사용 매뉴얼

작성일: 2026-05-05  
대상: Windows 10/11, PowerShell/CMD, WSL 미사용  
목표: 참석자가 설치 파일을 실행하고, 본인 Telegram 봇 토큰과 모델 인증을 직접 입력해 Windows 네이티브 환경에서 OpenClaw를 사용한다.

## 1. 배포 파일

배포 폴더는 `AttendeeKit`입니다.

| 파일 | 용도 |
| --- | --- |
| `OpenClawWindowsNativeSetup.exe` | 참석자용 단일 설치 파일 |
| `OpenClaw_Windows_Native_Installer.cmd` | EXE 대신 직접 실행할 수 있는 설치 실행기 |
| `Install-OpenClawWindowsNative.ps1` | 실제 설치 로직 |
| `Verify-OpenClawWindowsNative.ps1` | 설치 검증 |
| `Uninstall-OpenClawWindowsNative.ps1` | 삭제 보조 스크립트 |
| `OpenClaw_Windows_Native_User_Manual.md` | 이 문서 |
| `OpenClaw_Windows_Native_Technical_Spec.md` | 강의자용 기술 스펙 |

설치기는 민감정보를 포함하지 않습니다. Telegram 봇 토큰, Gateway token, 모델 API key/OAuth 정보는 실행 중 사용자가 직접 입력하거나 OpenClaw 공식 온보딩에서 직접 선택합니다.

## 2. 설치 전 준비

인터넷 연결이 필요합니다. 설치기는 다음 도구를 확인하고, 없으면 가능한 경우 `winget`으로 설치합니다.

- Git for Windows
- Node.js LTS, 최소 `22.14.0`
- pnpm `10.33.2`

회사/학교 PC에서 `winget`이 막혀 있으면 아래를 수동 설치한 뒤 설치 파일을 다시 실행합니다.

```powershell
winget install --id Git.Git -e --source winget
winget install --id OpenJS.NodeJS.LTS -e --source winget
npm install -g pnpm@10.33.2
```

## 3. 설치 실행

1. `OpenClawWindowsNativeSetup.exe`를 더블클릭합니다.
2. Windows SmartScreen이 표시되면 파일 출처를 확인한 뒤 `추가 정보` → `실행`을 선택합니다.
3. 설치 창에서 안내에 따라 진행합니다.

기본 OpenClaw 소스는 `https://github.com/openclaw/openclaw.git`의 `main` ref입니다. 강의나 연구에서 같은 소스 상태를 재현해야 하면 PowerShell 설치기를 직접 실행하면서 검증한 tag 또는 commit을 지정합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-OpenClawWindowsNative.ps1 -RepoRef <tag-or-commit>
```

설치 중 기본 경로는 다음과 같습니다.

```text
소스: %USERPROFILE%\openclaw-src
상태/설정: %USERPROFILE%\.openclaw
바탕화면 실행기: %USERPROFILE%\Desktop\OpenClaw
Gateway 포트: 18789
```

OpenClaw 온보딩 화면이 나오면 권장값은 다음과 같습니다.

| 항목 | 권장 선택 |
| --- | --- |
| Gateway mode | local |
| Bind | loopback |
| Port | 18789 |
| Auth | token |
| Model/provider | 본인이 사용할 provider 선택 |
| Gateway service | install |

## 4. Telegram 봇 준비

1. Telegram에서 `@BotFather`와 대화합니다.
2. `/newbot`을 실행합니다.
3. 봇 이름과 사용자명을 정합니다.
4. BotFather가 출력한 토큰을 복사합니다.
5. 설치기가 `Telegram bot token`을 물으면 붙여넣습니다.

설치기는 토큰을 화면이나 로그에 출력하지 않습니다. 토큰은 사용자의 로컬 파일에 저장되고 OpenClaw 설정에는 `tokenFile` 경로가 기록됩니다.

```text
%USERPROFILE%\.openclaw\credentials\telegram-bot-token.txt
```

토큰 입력을 건너뛰었다면 설치 후 PowerShell에서 직접 등록할 수 있습니다.

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\credentials"
notepad "$env:USERPROFILE\.openclaw\credentials\telegram-bot-token.txt"
cd $env:USERPROFILE\openclaw-src
pnpm.cmd openclaw plugins enable telegram
pnpm.cmd openclaw channels add --channel telegram --token-file "$env:USERPROFILE\.openclaw\credentials\telegram-bot-token.txt"
```

메모장이 열리면 BotFather 토큰 한 줄만 붙여넣고 저장합니다.

## 5. 첫 Telegram 대화 승인

Telegram DM 기본 정책은 pairing입니다. 처음 봇에게 메시지를 보내면 pairing code가 필요할 수 있습니다.

1. Telegram에서 본인 봇에게 메시지를 보냅니다.
2. PowerShell에서 pairing 목록을 확인합니다.

```powershell
cd $env:USERPROFILE\openclaw-src
pnpm.cmd openclaw pairing list telegram
```

3. 표시된 코드를 승인합니다.

```powershell
pnpm.cmd openclaw pairing approve telegram <PAIRING_CODE>
```

또는 바탕화면 `OpenClaw` 폴더에서 `OpenClaw_05_Approve_Telegram_Pairing.cmd`를 실행해 코드를 입력합니다.

## 6. 실행과 점검

설치 후 바탕화면 `OpenClaw` 폴더에 실행기가 생성됩니다.

| 파일 | 기능 |
| --- | --- |
| `OpenClaw_01_Start_Gateway.cmd` | Gateway 수동 실행 |
| `OpenClaw_02_Status.cmd` | Gateway/Telegram 상태 점검 |
| `OpenClaw_03_Stop_Gateway.cmd` | Gateway 종료 |
| `OpenClaw_04_Open_Dashboard.cmd` | Control UI 열기 |
| `OpenClaw_05_Approve_Telegram_Pairing.cmd` | Telegram pairing 승인 |
| `OpenClaw_06_Update.cmd` | 업데이트 및 재빌드 |

명령줄 검증은 다음과 같습니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Verify-OpenClawWindowsNative.ps1
```

성공 기준:

- Windows 네이티브 PowerShell/CMD에서 실행 중
- Git, Node.js, pnpm 존재
- `%USERPROFILE%\openclaw-src` 빌드 완료
- `%USERPROFILE%\.openclaw\openclaw.json` 존재
- Telegram 플러그인 활성화
- Gateway health 성공
- `channels status --probe`에서 Telegram이 configured/running/connected 또는 pairing 필요 상태로 확인

## 7. 자주 생기는 문제

### `winget`이 없다고 나올 때

Windows 10/11에서 App Installer가 비활성화되어 있을 수 있습니다. Microsoft Store에서 App Installer를 업데이트하거나, Git/Node.js를 직접 설치한 뒤 다시 실행합니다.

### `pnpm install --frozen-lockfile` 실패

네트워크, 사내 프록시, 백신 검사 문제일 수 있습니다. 같은 PowerShell에서 다시 실행합니다.

```powershell
cd $env:USERPROFILE\openclaw-src
pnpm.cmd install --frozen-lockfile
pnpm.cmd build
pnpm.cmd ui:build
```

### Dashboard에서 token 오류

```powershell
cd $env:USERPROFILE\openclaw-src
pnpm.cmd openclaw dashboard
```

위 명령은 현재 Gateway token을 적용해 Control UI를 엽니다.

### Telegram이 응답하지 않을 때

```powershell
cd $env:USERPROFILE\openclaw-src
pnpm.cmd openclaw channels status --probe
pnpm.cmd openclaw pairing list telegram
```

pairing code가 있으면 승인합니다.

```powershell
pnpm.cmd openclaw pairing approve telegram <PAIRING_CODE>
```

그룹에서 멘션 없는 메시지까지 받아야 하면 BotFather에서 `/setprivacy`를 조정하고 봇을 그룹에서 제거 후 다시 추가합니다.

## 8. 민감정보 관리

다음 파일과 폴더는 공유하지 않습니다.

```text
%USERPROFILE%\.openclaw
%USERPROFILE%\.openclaw\credentials
%USERPROFILE%\.openclaw\openclaw.json
```

배포용 설치 파일과 매뉴얼에는 실제 토큰, API key, pairing code를 넣지 않습니다. 강의 화면 공유 중에도 token 값이 출력되는 명령은 실행하지 않습니다.

## 9. 삭제

소스만 삭제:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-OpenClawWindowsNative.ps1
```

소스와 로컬 상태/토큰까지 삭제:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-OpenClawWindowsNative.ps1 -RemoveState
```

`-RemoveState`는 `%USERPROFILE%\.openclaw`를 삭제하므로 토큰, 세션, 로컬 작업 상태가 모두 사라집니다.

## 10. 참고 링크

- OpenClaw CLI: https://docs.openclaw.ai/cli
- OpenClaw Telegram: https://docs.openclaw.ai/channels/telegram
- Node.js 다운로드: https://nodejs.org/en/download
- Git for Windows: https://git-scm.com/install/windows
- pnpm 설치: https://pnpm.io/installation
- WinGet install 명령: https://learn.microsoft.com/windows/package-manager/winget/install
