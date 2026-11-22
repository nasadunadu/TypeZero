use crate::system::injector::{ContextInjector, ScreenPoint};
use parking_lot::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
#[cfg(not(target_os = "windows"))]
use tauri::PhysicalPosition;
use tauri::{AppHandle, Manager};

const PILL_WIDTH: i32 = 240;
const PILL_HEIGHT: i32 = 74;

/// Controls the transparent, click-through, non-activating Floating Acoustic Pill HUD (`label: "pill"`).
/// - On Windows: stamps `WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_TRANSPARENT`
///   so showing/gliding NEVER steals focus from the user's active editor!
/// - Runs 7Hz background UIA/Caret polling + 60fps smooth lerp.
pub struct PillWindowController {
    app_handle: Mutex<Option<AppHandle>>,
    is_visible: Arc<AtomicBool>,
    target_pos: Arc<Mutex<Option<ScreenPoint>>>,
    current_pos: Arc<Mutex<(f64, f64)>>,
    tracking_cancel: Mutex<Option<Arc<AtomicBool>>>,
}

impl Default for PillWindowController {
    fn default() -> Self {
        Self::new()
    }
}

impl PillWindowController {
    pub fn new() -> Self {
        Self {
            app_handle: Mutex::new(None),
            is_visible: Arc::new(AtomicBool::new(false)),
            target_pos: Arc::new(Mutex::new(None)),
            current_pos: Arc::new(Mutex::new((0.0, 0.0))),
            tracking_cancel: Mutex::new(None),
        }
    }

    pub fn attach(&self, app: AppHandle) {
        if let Some(win) = app.get_webview_window("pill") {
            let _ = win.set_ignore_cursor_events(true);
            #[cfg(target_os = "windows")]
            apply_win32_noactivate_styles(&win);
        }
        *self.app_handle.lock() = Some(app);
    }

    pub fn set_visible(&self, visible: bool) {
        let prev = self.is_visible.swap(visible, Ordering::SeqCst);
        let Some(app) = self.app_handle.lock().clone() else {
            return;
        };
        let Some(win) = app.get_webview_window("pill") else {
            return;
        };

        if visible {
            if !prev {
                let initial = ContextInjector::get_focused_caret_screen_origin(PILL_WIDTH, PILL_HEIGHT)
                    .unwrap_or_else(|| ContextInjector::default_bottom_origin(PILL_WIDTH, PILL_HEIGHT));
                *self.target_pos.lock() = Some(initial);
                *self.current_pos.lock() = (initial.x as f64, initial.y as f64);

                #[cfg(target_os = "windows")]
                {
                    apply_win32_noactivate_styles(&win);
                    show_win32_noactivate(&win, initial.x, initial.y);
                }
                #[cfg(not(target_os = "windows"))]
                {
                    let _ = win.set_position(PhysicalPosition::new(initial.x, initial.y));
                    let _ = win.show();
                }

                self.start_caret_tracking(app);
            }
        } else {
            self.stop_caret_tracking();
            *self.target_pos.lock() = None;
            let _ = win.hide();
        }
    }

    fn start_caret_tracking(&self, app: AppHandle) {
        self.stop_caret_tracking();
        let cancel = Arc::new(AtomicBool::new(false));
        *self.tracking_cancel.lock() = Some(Arc::clone(&cancel));

        // 7Hz background caret poller
        let poll_cancel = Arc::clone(&cancel);
        let poll_target = Arc::clone(&self.target_pos);
        std::thread::Builder::new()
            .name("typezero-pill-caret".to_string())
            .spawn(move || {
                while !poll_cancel.load(Ordering::Relaxed) {
                    if let Some(pt) =
                        ContextInjector::get_focused_caret_screen_origin(PILL_WIDTH, PILL_HEIGHT)
                    {
                        *poll_target.lock() = Some(pt);
                    }
                    std::thread::sleep(Duration::from_millis(140));
                }
            })
            .ok();

        // 60fps smooth in-memory lerp
        let lerp_cancel = Arc::clone(&cancel);
        let lerp_target = Arc::clone(&self.target_pos);
        let lerp_current = Arc::clone(&self.current_pos);
        std::thread::Builder::new()
            .name("typezero-pill-lerp".to_string())
            .spawn(move || {
                while !lerp_cancel.load(Ordering::Relaxed) {
                    std::thread::sleep(Duration::from_millis(16));
                    let Some(target) = *lerp_target.lock() else {
                        continue;
                    };
                    let (nx, ny, moved) = {
                        let mut cur = lerp_current.lock();
                        let dx = (target.x as f64) - cur.0;
                        let dy = (target.y as f64) - cur.1;
                        let dist = (dx * dx + dy * dy).sqrt();
                        if dist <= 0.6 {
                            (cur.0 as i32, cur.1 as i32, false)
                        } else if dist > 260.0 {
                            cur.0 = target.x as f64;
                            cur.1 = target.y as f64;
                            (target.x, target.y, true)
                        } else {
                            cur.0 += dx * 0.20;
                            cur.1 += dy * 0.20;
                            (cur.0.round() as i32, cur.1.round() as i32, true)
                        }
                    };
                    if moved {
                        if let Some(win) = app.get_webview_window("pill") {
                            #[cfg(target_os = "windows")]
                            move_win32_noactivate(&win, nx, ny);
                            #[cfg(not(target_os = "windows"))]
                            let _ = win.set_position(PhysicalPosition::new(nx, ny));
                        }
                    }
                }
            })
            .ok();
    }

    fn stop_caret_tracking(&self) {
        if let Some(flag) = self.tracking_cancel.lock().take() {
            flag.store(true, Ordering::SeqCst);
        }
    }
}

#[cfg(target_os = "windows")]
fn apply_win32_noactivate_styles(win: &tauri::WebviewWindow) {
    use windows::Win32::Foundation::HWND;
    use windows::Win32::UI::WindowsAndMessaging::{
        GetWindowLongPtrW, SetWindowLongPtrW, GWL_EXSTYLE, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW,
        WS_EX_TOPMOST, WS_EX_TRANSPARENT,
    };

    if let Ok(raw) = win.hwnd() {
        let hwnd = HWND(raw.0);
        unsafe {
            let ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
            let desired = ex
                | (WS_EX_NOACTIVATE.0 as isize)
                | (WS_EX_TOOLWINDOW.0 as isize)
                | (WS_EX_TOPMOST.0 as isize)
                | (WS_EX_TRANSPARENT.0 as isize);
            let _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE, desired);
        }
    }
}

#[cfg(target_os = "windows")]
fn show_win32_noactivate(win: &tauri::WebviewWindow, x: i32, y: i32) {
    use windows::Win32::Foundation::HWND;
    use windows::Win32::UI::WindowsAndMessaging::{
        SetWindowPos, ShowWindow, HWND_TOPMOST, SWP_NOACTIVATE, SWP_NOSIZE, SWP_SHOWWINDOW,
        SW_SHOWNOACTIVATE,
    };

    if let Ok(raw) = win.hwnd() {
        let hwnd = HWND(raw.0);
        unsafe {
            let _ = SetWindowPos(
                hwnd,
                HWND_TOPMOST,
                x,
                y,
                0,
                0,
                SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW,
            );
            let _ = ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        }
    }
}

#[cfg(target_os = "windows")]
fn move_win32_noactivate(win: &tauri::WebviewWindow, x: i32, y: i32) {
    use windows::Win32::Foundation::HWND;
    use windows::Win32::UI::WindowsAndMessaging::{
        SetWindowPos, HWND_TOPMOST, SWP_NOACTIVATE, SWP_NOSIZE,
    };

    if let Ok(raw) = win.hwnd() {
        let hwnd = HWND(raw.0);
        unsafe {
            let _ = SetWindowPos(hwnd, HWND_TOPMOST, x, y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
        }
    }
}
