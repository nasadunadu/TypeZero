pub mod audio;
pub mod commands;
pub mod core;
pub mod models;
pub mod system;

#[cfg(test)]
mod tests;

use crate::core::state::AppState;
use std::sync::Arc;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{Manager, RunEvent, WindowEvent};

fn show_and_focus_main(app: &tauri::AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        let _ = win.unminimize();
        let _ = win.show();
        let _ = win.set_focus();
    }
}

pub fn run() {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .try_init()
        .ok();

    let app_state = AppState::new();
    let state_for_setup = Arc::clone(&app_state);
    let state_for_close = Arc::clone(&app_state);
    let state_for_exit = Arc::clone(&app_state);

    let start_minimized = std::env::args().any(|a| a == "--minimized");

    let app = tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            show_and_focus_main(app);
        }))
        .manage(app_state)
        .setup(move |app| {
            let handle = app.handle().clone();
            state_for_setup.initialize_runtime(handle.clone());

            if start_minimized {
                if let Some(main_win) = app.get_webview_window("main") {
                    let _ = main_win.hide();
                }
            }

            // Build native Windows System Tray icon & menu
            let item_show = MenuItem::with_id(app, "show", "打开 TypeZero 主面板", true, None::<&str>)?;
            let item_copy_last =
                MenuItem::with_id(app, "copy_last", "复制最近一条成稿", true, None::<&str>)?;
            let item_quit = MenuItem::with_id(app, "quit", "退出 TypeZero", true, None::<&str>)?;
            let tray_menu = Menu::with_items(app, &[&item_show, &item_copy_last, &item_quit])?;

            let st_tray = Arc::clone(&state_for_setup);
            let mut builder = TrayIconBuilder::with_id("typezero-tray")
                .menu(&tray_menu)
                .tooltip("TypeZero — 说话，不要打字")
                .on_menu_event(move |app, event| match event.id.as_ref() {
                    "show" => show_and_focus_main(app),
                    "copy_last" => {
                        let _ = st_tray.copy_latest_record_to_clipboard();
                    }
                    "quit" => {
                        st_tray.audio_ducker.restore_if_needed();
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        show_and_focus_main(tray.app_handle());
                    }
                });

            if let Some(icon) = app.default_window_icon().cloned() {
                builder = builder.icon(icon);
            }
            let _ = builder.build(app)?;

            Ok(())
        })
        .on_window_event(move |window, event| {
            if window.label() == "main" {
                if let WindowEvent::CloseRequested { api, .. } = event {
                    if state_for_close.minimize_to_tray_enabled() {
                        api.prevent_close();
                        let _ = window.hide();
                    }
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_app_snapshot,
            commands::clear_status_banner,
            commands::set_sandbox_text,
            commands::start_sandbox_dictation,
            commands::stop_dictation,
            commands::cancel_dictation,
            commands::copy_text_to_clipboard,
            commands::update_preferences,
            commands::set_trigger_key,
            commands::set_trigger_behavior,
            commands::set_formatting_style,
            commands::start_shortcut_capture,
            commands::cancel_shortcut_capture,
            commands::save_volc_speech_key,
            commands::save_openai_asr_config,
            commands::probe_seed_asr,
            commands::probe_openai_asr,
            commands::activate_asr_provider,
            commands::save_llm_provider_draft,
            commands::benchmark_llm_provider,
            commands::activate_llm_provider,
            commands::upsert_lexicon_entry,
            commands::update_lexicon_entry,
            commands::remove_lexicon_entry,
            commands::remove_lexicon_batch,
            commands::bulk_import_lexicon_lines,
            commands::distill_pasted_corpus,
            commands::import_lexicon_from_folder,
            commands::import_lexicon_from_browsers,
            commands::start_offline_model_download,
            commands::cancel_offline_model_download,
            commands::complete_onboarding,
            commands::open_windows_mic_settings,
        ])
        .build(tauri::generate_context!())
        .expect("error while building TypeZero Windows application");

    app.run(move |_app_handle, event| {
        if let RunEvent::Exit = event {
            state_for_exit.audio_ducker.restore_if_needed();
        }
    });
}
