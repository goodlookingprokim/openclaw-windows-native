# Security

## Sensitive data policy

Do not commit:

- Telegram bot tokens
- Gateway tokens
- API keys
- OAuth tokens
- pairing codes
- `.openclaw` state directories
- installation logs that show private identifiers

## Reporting

For educational use, please open a GitHub issue with enough detail to reproduce the problem. Do not include secrets in issue text, screenshots, or logs.

## Repository hardening

Every push runs `scripts/Test-SecurityAudit.ps1`, which checks PowerShell syntax, checksums, common secret patterns, HTML security meta, internal links, the Pages publish allowlist, workflow action pinning, and git history secret patterns.

GitHub Pages publishes only the explicit allowlist from `.github/workflows/pages.yml`; operational release checklist files stay in the repository but are not deployed to Pages.
