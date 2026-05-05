use serde::Serialize;
use std::{env, path::PathBuf, process::Command};
use tauri::Manager;
use thiserror::Error;

#[derive(Debug, Error)]
enum CompanionError {
    #[error("token_file is required and must point to a user-owned token file")]
    MissingTokenFile,
    #[error("token_file must be a filesystem path, not an inline token value")]
    InlineTokenRejected,
    #[error("PowerShell probe failed: {0}")]
    PowerShellProbe(String),
}

#[derive(Debug, Serialize)]
struct PowerShellProbe {
    executable: &'static str,
    available: bool,
    version: Option<String>,
    stderr: Option<String>,
}

#[derive(Debug, Serialize)]
struct TokenFileValidation {
    accepted: bool,
    path: String,
    exists: bool,
    note: &'static str,
}

#[derive(Debug, Serialize)]
struct GatewayStartPlan {
    executable: &'static str,
    args: Vec<String>,
    token_file: TokenFileValidation,
    redaction: &'static str,
    executes_now: bool,
}

#[tauri::command]
fn probe_powershell() -> Result<PowerShellProbe, String> {
    let output = Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "$PSVersionTable.PSVersion.ToString()",
        ])
        .output()
        .map_err(|error| CompanionError::PowerShellProbe(error.to_string()).to_string())?;

    Ok(PowerShellProbe {
        executable: "powershell.exe",
        available: output.status.success(),
        version: output
            .status
            .success()
            .then(|| String::from_utf8_lossy(&output.stdout).trim().to_string())
            .filter(|version| !version.is_empty()),
        stderr: (!output.stderr.is_empty())
            .then(|| String::from_utf8_lossy(&output.stderr).trim().to_string()),
    })
}

#[tauri::command]
fn plan_gateway_start(
    app: tauri::AppHandle,
    token_file: String,
) -> Result<GatewayStartPlan, String> {
    let token_file = validate_token_file_path(token_file)?;
    let planned_script = default_engine_script(&app);

    Ok(GatewayStartPlan {
        executable: "powershell.exe",
        args: vec![
            "-NoProfile".into(),
            "-NonInteractive".into(),
            "-ExecutionPolicy".into(),
            "Bypass".into(),
            "-File".into(),
            planned_script.display().to_string(),
            "-TokenFile".into(),
            token_file.path.clone(),
        ],
        token_file,
        redaction: "Only token file paths are accepted; token contents are never read or echoed.",
        executes_now: false,
    })
}

fn validate_token_file_path(token_file: String) -> Result<TokenFileValidation, String> {
    let trimmed = token_file.trim();

    if trimmed.is_empty() {
        return Err(CompanionError::MissingTokenFile.to_string());
    }

    if looks_like_inline_token(trimmed) {
        return Err(CompanionError::InlineTokenRejected.to_string());
    }

    let expanded = expand_user_profile(trimmed);
    let path = PathBuf::from(&expanded);

    Ok(TokenFileValidation {
        accepted: true,
        path: expanded,
        exists: path.is_file(),
        note: "Path shape accepted. The companion does not read token file contents.",
    })
}

fn looks_like_inline_token(value: &str) -> bool {
    let has_path_separator = value.contains('\\') || value.contains('/');
    let has_token_separator = value.contains(':');
    let long_no_extension = value.len() > 30 && PathBuf::from(value).extension().is_none();

    !has_path_separator && (has_token_separator || long_no_extension)
}

fn expand_user_profile(value: &str) -> String {
    if let Some(rest) = value.strip_prefix("%USERPROFILE%") {
        if let Ok(profile) = env::var("USERPROFILE") {
            return format!("{profile}{rest}");
        }
    }

    value.to_string()
}

fn default_engine_script(app: &tauri::AppHandle) -> PathBuf {
    app.path()
        .home_dir()
        .unwrap_or_else(|_| PathBuf::from("%USERPROFILE%"))
        .join("Desktop")
        .join("OpenClaw")
        .join("Start-OpenClawGateway.ps1")
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            probe_powershell,
            plan_gateway_start
        ])
        .run(tauri::generate_context!())
        .expect("failed to run OpenClaw Companion");
}
