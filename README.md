# OpenClaw Windows Native Kit

WSL 없이 Windows에서 OpenClaw Gateway와 Telegram bot channel을 설치하기 위한 공개 학습용 키트입니다.

## Repository name

추천 리포 이름은 `openclaw-windows-native`입니다.

- 서비스 목적이 바로 드러납니다.
- GitHub Pages URL이 명확합니다: `https://goodlookingprokim.github.io/openclaw-windows-native/`
- Windows, native, OpenClaw 키워드가 모두 들어 있어 검색과 공유에 유리합니다.

## Quick start

1. GitHub Pages 홈에서 `OpenClawWindowsNativeSetup.exe`를 다운로드합니다.
2. [`온보딩 매뉴얼`](https://goodlookingprokim.github.io/openclaw-windows-native/manual.html)을 따라 설치기를 실행합니다.
3. OpenClaw 온보딩에서 provider/model 인증을 직접 선택합니다.
4. Telegram BotFather token을 입력합니다.
5. Telegram pairing code를 승인합니다.

## Downloads

- Installer: [`downloads/OpenClawWindowsNativeSetup.exe`](downloads/OpenClawWindowsNativeSetup.exe)
- SHA-256: [`downloads/checksums.sha256`](downloads/checksums.sha256)
- Web manual: [`manual.html`](https://goodlookingprokim.github.io/openclaw-windows-native/manual.html)
- Security guide: [`security.html`](https://goodlookingprokim.github.io/openclaw-windows-native/security.html)
- Release center: [`release.html`](https://goodlookingprokim.github.io/openclaw-windows-native/release.html)
- Technical spec: [`technical.html`](https://goodlookingprokim.github.io/openclaw-windows-native/technical.html)
- Source manual: [`docs/OpenClaw_Windows_Native_User_Manual.md`](docs/OpenClaw_Windows_Native_User_Manual.md)
- Source technical spec: [`docs/OpenClaw_Windows_Native_Technical_Spec.md`](docs/OpenClaw_Windows_Native_Technical_Spec.md)
- Release checklist: [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md)

## Security

The installer and repository do not contain real Gateway tokens, Telegram bot tokens, API keys, or pairing codes. Users enter their own credentials during installation. Telegram credentials are registered through `--token-file`.

## Publishing

Maintainers can publish the repository and GitHub Pages site with:

```powershell
.\Publish-ToGitHub.cmd
```

If browser login is unavailable, use `.\Publish-WithToken.cmd` and paste a GitHub token with `repo` and `workflow` scopes.

## Audience

This project is for open-source learners, educators, and researchers who want to experiment with standalone agents on Windows for academic and non-commercial learning purposes.

## Thanks

Thank you to OpenClaw and to everyone building the open-source ecosystem that makes local, user-owned agent workflows possible.

## License

Installer scripts, documentation, and this landing page are released under the MIT License. OpenClaw itself is a separate project and remains governed by its own maintainers and license.
