# OpenClaw Companion scaffold

This directory is a minimal Tauri v2-style desktop companion for the Windows Native kit. It is intentionally small: no generated `node_modules`, no committed Cargo lockfile yet, and no credentials.

## Build prerequisites

- Node.js matching the main OpenClaw requirements
- Rust stable toolchain
- Windows WebView2 runtime

## Commands

```powershell
cd companion
npm install
npm run check:rust
npm run fmt:rust
npm run dev
npm run build
```

## Secret handling

The Rust bridge is designed around token-file paths only. It validates a token file path and returns a redacted launch plan; it does not read token contents and does not put token values on the command line. Future engine calls should keep using `--token-file <path>` or config-file handoff rather than `--token <value>`.

