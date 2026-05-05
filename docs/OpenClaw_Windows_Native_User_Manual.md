# OpenClaw Windows Native 설치 및 사용 매뉴얼

작성일: 2026-05-05
대상: Windows 10/11, PowerShell/CMD, WSL 미사용
목표: 설치 파일 실행, dry-run 검증, Telegram tokenFile 설정, pairing 승인, 첫 대화 확인.

## 빠른 시작

1. `OpenClawWindowsNativeSetup.exe`를 다운로드합니다.
2. `checksums.sha256`과 SHA-256을 비교합니다.
3. 설치 파일을 실행합니다.
4. 실제 Telegram 토큰 전에는 dry-run을 먼저 실행합니다.
5. BotFather 토큰은 로컬 파일에 저장하고 `--token-file`로 등록합니다.
6. pairing code를 승인하고 Gateway/channel 상태를 확인합니다.

```powershell
Get-FileHash .\OpenClawWindowsNativeSetup.exe -Algorithm SHA256
Get-Content .\checksums.sha256
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Verify-OpenClawWindowsNative.ps1 -TelegramDryRunOnly
```

현재 installer SHA-256은 배포 폴더의 `checksums.sha256`에서 확인합니다.

## 설치기가 준비하는 것

- Git for Windows, Node.js `>=22.14.0`, pnpm `10.33.2` 확인.
- `%USERPROFILE%\openclaw-src`에 OpenClaw clone/update/build.
- OpenClaw onboarding: local gateway, loopback bind, port `18789`, token auth 권장.
- Telegram plugin enable 및 tokenFile 등록.
- Gateway install/start.
- 바탕화면 `OpenClaw` 폴더에 운영용 CMD helper 생성.
- verifier 실행 및 redacted status 출력.

## Telegram 설정

1. Telegram에서 `@BotFather`와 대화합니다.
2. `/newbot`으로 봇을 만듭니다.
3. BotFather 토큰을 복사합니다.
4. 설치기가 물으면 붙여넣습니다.
5. 설치기는 토큰 원문을 로그에 출력하지 않고 다음 파일에 저장합니다.

```text
%USERPROFILE%\.openclaw\credentials\telegram-bot-token.txt
```

나중에 직접 등록하려면 다음을 사용합니다.

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\credentials"
notepad "$env:USERPROFILE\.openclaw\credentials\telegram-bot-token.txt"
cd $env:USERPROFILE\openclaw-src
pnpm.cmd openclaw plugins enable telegram
pnpm.cmd openclaw channels add --channel telegram --token-file "$env:USERPROFILE\.openclaw\credentials\telegram-bot-token.txt"
```

## Dry-run과 실제 검증의 차이

Dry-run은 실제 Telegram에 접속하지 않습니다. 민감정보 없이 검증 artifact를 생성합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Verify-OpenClawWindowsNative.ps1 -TelegramDryRunOnly
```

생성 위치:

```text
%USERPROFILE%\.openclaw\validation\telegram-validation.dry-run.json
```

실제 송수신 검증은 사용자 BotFather 토큰과 pairing 승인 후 진행합니다.

```powershell
cd $env:USERPROFILE\openclaw-src
pnpm.cmd openclaw pairing list telegram
pnpm.cmd openclaw pairing approve telegram <PAIRING_CODE>
pnpm.cmd openclaw gateway health
pnpm.cmd openclaw channels status --probe
```

## 바탕화면 helper

| 파일 | 기능 |
| --- | --- |
| `OpenClaw_01_Start_Gateway.cmd` | Gateway 수동 실행 |
| `OpenClaw_02_Status.cmd` | Gateway/Telegram 상태 점검 |
| `OpenClaw_03_Stop_Gateway.cmd` | Gateway 종료 |
| `OpenClaw_04_Open_Dashboard.cmd` | Control UI 열기 |
| `OpenClaw_05_Approve_Telegram_Pairing.cmd` | Telegram pairing 승인 |
| `OpenClaw_06_Telegram_Dry_Run.cmd` | 실제 credential 없이 dry-run artifact 생성 |
| `OpenClaw_07_Update.cmd` | OpenClaw update and rebuild |

## English summary

Download the setup EXE, verify the checksum, install from native Windows, run Telegram dry-run, then enter your own BotFather token only when you are ready for live Telegram. Approve pairing and verify Gateway/channel status. Dry-run is simulated and does not prove live send/receive.
