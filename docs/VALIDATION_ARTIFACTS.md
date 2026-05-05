# Validation Artifacts

This repository keeps release validation artifacts out of Git by default (`.artifacts/` is ignored). Maintainers can still generate local JSON evidence and point the audit at it:

```powershell
.\scripts\Test-SecurityAudit.ps1 -TelegramValidationArtifact .artifacts\telegram-validation.json
```

## Telegram validation artifact schema

`telegram-validation.json` is intentionally redacted. It records validation status only; it must not contain bot tokens, gateway tokens, API keys, pairing codes, credential file contents, private chat IDs, or local absolute paths.

Required top-level fields:

| Field | Type | Required value |
| --- | --- | --- |
| `schemaVersion` | number | `1` |
| `generatedAt` | string | ISO-8601 timestamp |
| `channel` | string | `telegram` |
| `status` | string | `passed`, `warning`, `failed`, or `skipped` |
| `checks` | array | At least one check object |

Each check object uses:

| Field | Type | Notes |
| --- | --- | --- |
| `name` | string | Stable check name, for example `plugin-enabled` |
| `status` | string | `passed`, `warning`, `failed`, or `skipped` |
| `evidence` | string | Optional redacted summary only |

Allowed example:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-05-05T00:00:00Z",
  "channel": "telegram",
  "status": "warning",
  "checks": [
    {
      "name": "channel-status-probe",
      "status": "warning",
      "evidence": "Probe completed; user action may still be required."
    }
  ]
}
```

Rejected examples include any field named `token`, `botToken`, `secret`, `password`, `credential`, `pairingCode`, or evidence strings that include sensitive values.

## Release QA coverage added to `scripts/Test-SecurityAudit.ps1`

The audit now validates these release gates in addition to the baseline secret, checksum, HTML, and workflow checks:

- `downloads/package-manifest.json` parses as JSON, contains required fields, stays Windows-native (`nativeWindows: true`, `usesWsl: false`), uses user-relative default paths, and matches the expected payload list.
- Installer engine checks remain aligned with OpenClaw's Node floor (`>=22.14.0`), require HTTPS repo URLs, validate Git refs, and register Telegram with `--token-file` instead of printing or passing raw token values.
- Verifier checks parse `openclaw.json` as JSON and do not print credential values.
- Companion desktop launcher checks include the expected six launchers and keep Telegram pairing/token material runtime-only.
- GitHub Pages workflow publishes exactly the audited static allowlist and never publishes `docs/RELEASE_CHECKLIST.md` or broad recursive repository copies.
