// StockFlow Pro — Windows desktop shell (Tauri v2)
// Publisher: Mindtune Innovations · Developed by Muhammad Ali (alim2840@gmail.com)
//
// Architecture: this shell wraps the organisation's deployed StockFlow Pro
// server (Next.js on Vercel or similar). Security is enforced in the cloud
// (Supabase RLS + SECURITY DEFINER RPCs); the shell provides native install,
// windowing, offline behaviour and safe link handling. The remote web app
// NEVER receives Tauri IPC access (capability is scoped to the bundled
// connect screen only).

// Hide the console window in release builds (no terminal for end users).
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::{fs, path::PathBuf};
use tauri::{AppHandle, Manager, Url, WebviewUrl, WebviewWindowBuilder};
use tauri_plugin_opener::OpenerExt;

const CONFIG_FILE: &str = "config.json";

/// Production server URL baked in at BUILD time by the release workflow
/// (env STOCKFLOW_SERVER_URL). When present, end users never see a server
/// address screen — the app connects automatically and opens at login.
/// An IT administrator can still override it by placing a config.json in the
/// app config folder (protected/advanced path; documented in the guides).
const DEFAULT_SERVER_URL: Option<&str> = option_env!("STOCKFLOW_SERVER_URL");

fn config_path(app: &AppHandle) -> Option<PathBuf> {
    app.path().app_config_dir().ok().map(|d| d.join(CONFIG_FILE))
}

fn stored_server_url(app: &AppHandle) -> Option<String> {
    let path = config_path(app)?;
    let raw = fs::read_to_string(path).ok()?;
    let v: serde_json::Value = serde_json::from_str(&raw).ok()?;
    v.get("server_url")?.as_str().map(|s| s.to_string())
}

fn read_server_url(app: &AppHandle) -> Option<String> {
    // Admin override (config file) wins; otherwise the compiled-in production URL.
    stored_server_url(app).or_else(|| DEFAULT_SERVER_URL.map(|s| s.trim_end_matches('/').to_string()))
}

/// Returns the effective server URL (None only in unconfigured dev builds).
#[tauri::command]
fn get_server_url(app: AppHandle) -> Option<String> {
    read_server_url(&app)
}

/// True when a production URL was baked in at build time — the connect form
/// and "use a different server" affordances are hidden in that case.
#[tauri::command]
fn is_preconfigured() -> bool {
    DEFAULT_SERVER_URL.is_some()
}

/// Validates and persists the server URL chosen on first run.
/// Only http(s) URLs without embedded credentials are accepted.
#[tauri::command]
fn set_server_url(app: AppHandle, url: String) -> Result<String, String> {
    let trimmed = url.trim().trim_end_matches('/').to_string();
    let parsed = Url::parse(&trimmed).map_err(|_| "Enter a valid URL, e.g. https://stock.yourcompany.com".to_string())?;
    if parsed.scheme() != "https" && parsed.scheme() != "http" {
        return Err("The server address must start with https:// (or http:// for a LAN server).".into());
    }
    if !parsed.username().is_empty() || parsed.password().is_some() {
        return Err("Do not include credentials in the server address.".into());
    }
    if parsed.host_str().is_none() {
        return Err("The server address is missing a host name.".into());
    }
    let path = config_path(&app).ok_or("Could not resolve the application config folder.")?;
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir).map_err(|e| format!("Could not create config folder: {e}"))?;
    }
    let body = serde_json::json!({ "server_url": trimmed });
    fs::write(&path, serde_json::to_string_pretty(&body).unwrap())
        .map_err(|e| format!("Could not save configuration: {e}"))?;
    Ok(trimmed)
}

/// Forgets the saved server (used by the "change server" affordance).
#[tauri::command]
fn clear_server_url(app: AppHandle) -> Result<(), String> {
    if let Some(path) = config_path(&app) {
        if path.exists() {
            fs::remove_file(path).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

#[tauri::command]
fn get_app_version(app: AppHandle) -> String {
    app.package_info().version.to_string()
}

fn is_bundled_origin(url: &Url) -> bool {
    // Bundled assets: tauri://localhost (macOS/Linux) or http(s)://tauri.localhost (Windows).
    url.scheme() == "tauri" || url.host_str() == Some("tauri.localhost")
}

fn main() {
    tauri::Builder::default()
        // Single instance: a second launch focuses the existing window instead.
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            if let Some(w) = app.get_webview_window("main") {
                let _ = w.unminimize();
                let _ = w.set_focus();
            }
        }))
        // Remember window size, position and maximised state between runs.
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            get_server_url,
            set_server_url,
            clear_server_url,
            get_app_version,
            is_preconfigured
        ])
        .setup(|app| {
            let nav_handle = app.handle().clone();
            let dl_handle = app.handle().clone();

            WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                .title("StockFlow Pro")
                .inner_size(1440.0, 900.0)
                .min_inner_size(1180.0, 680.0)
                .center()
                // Navigation policy: bundled connect screen + the configured
                // server stay in-window; mailto: and every foreign site open
                // in the user's default browser / mail client.
                .on_navigation(move |url| {
                    if is_bundled_origin(url) || url.scheme() == "about" || url.scheme() == "data" {
                        return true;
                    }
                    if url.scheme() == "mailto" {
                        let _ = nav_handle.opener().open_url(url.as_str(), None::<&str>);
                        return false;
                    }
                    if url.scheme() == "http" || url.scheme() == "https" {
                        if let Some(server) = read_server_url(&nav_handle) {
                            if let Ok(s) = Url::parse(&server) {
                                if s.host_str() == url.host_str() {
                                    return true; // the organisation's own server
                                }
                            }
                        }
                        let _ = nav_handle.opener().open_url(url.as_str(), None::<&str>);
                        return false;
                    }
                    false
                })
                // Exports/downloads (CSV etc.) land in the user's Downloads folder.
                .on_download(move |_webview, event| {
                    if let tauri::webview::DownloadEvent::Requested { destination, .. } = event {
                        if let Ok(dir) = dl_handle.path().download_dir() {
                            let name = destination
                                .file_name()
                                .map(|f| f.to_os_string())
                                .unwrap_or_else(|| "stockflow-export".into());
                            *destination = dir.join(name);
                        }
                    }
                    true
                })
                .build()?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running StockFlow Pro");
}
