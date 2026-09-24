/// The shell around the page: an activity on Android, and nothing at all in the browser,
/// where the very same page runs on its own (ADR 2). Everything the app does, it does in
/// the page, so the shell holds no commands.
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
