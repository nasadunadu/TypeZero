use crate::models::ActiveScreenContext;
#[cfg(target_os = "windows")]
use crate::system::hotkey::SYNTHETIC_EVENT_MARKER;
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use regex::Regex;

static NUMBERED_MARKER_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"^(\d+\.\s+)").unwrap());
static BULLET_MARKER_RE: Lazy<Regex> = Lazy::new(|| Regex::new(r"^([-*•]\s+)").unwrap());
static DUP_NUMBERED_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?m)^(\d+\.\s+)\d+\.\s+").unwrap());
static DUP_BULLET_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?m)^([-*•]\s+)[-*•]\s+").unwrap());

#[derive(Debug, Clone, Copy)]
pub struct ScreenPoint {
    pub x: i32,
    pub y: i32,
}

pub struct ContextInjector;

impl ContextInjector {
    /// Extracts leading list marker like `"2. "` or `"- "`.
    pub fn extract_leading_list_marker(line: &str) -> Option<String> {
        if let Some(m) = NUMBERED_MARKER_RE.find(line) {
            return Some(m.as_str().to_string());
        }
        if let Some(m) = BULLET_MARKER_RE.find(line) {
            return Some(m.as_str().to_string());
        }
        None
    }

    pub fn collapse_duplicated_list_markers(text: &str) -> String {
        let step1 = DUP_NUMBERED_RE.replace_all(text, "$1");
        DUP_BULLET_RE.replace_all(&step1, "$1").into_owned()
    }

    pub fn contains_duplicated_list_marker(actual_box: &str, expected: &str) -> bool {
        let collapsed = Self::collapse_duplicated_list_markers(actual_box);
        collapsed != actual_box && collapsed.contains(expected.trim())
    }

    pub fn is_own_process(ctx: &ActiveScreenContext) -> bool {
        let p = ctx.process_name.to_lowercase();
        p.contains("typezero")
    }

    pub fn capture_current_context() -> ActiveScreenContext {
        platform::capture_current_context()
    }

    pub fn capture_fast_foreground_app() -> (String, String, String) {
        platform::capture_fast_foreground_app()
    }

    pub fn read_current_focused_value() -> Option<String> {
        platform::read_current_focused_value()
    }

    pub fn is_likely_editable_focus_now() -> bool {
        platform::is_likely_editable_focus_now()
    }

    pub fn read_clipboard_text() -> String {
        platform::read_clipboard_text().unwrap_or_default()
    }

    pub fn save_to_safety_clipboard(text: &str) {
        let _ = platform::write_clipboard_text(text);
    }

    /// Default 8ms Atomic Paste: snapshots user clipboard, writes UTF-16 text, sends Ctrl+V (or Shift+Insert in terminals),
    /// waits for WM_PASTE consumption, and restores original clipboard seamlessly!
    pub fn inject_text_at_cursor(text: &str, context: &ActiveScreenContext) {
        if text.is_empty() {
            return;
        }
        platform::paste_via_clipboard_preserving_snapshot(text, context.is_strict_shell_terminal());
    }

    pub fn type_clean_unicode(text: &str) {
        platform::type_clean_unicode(text);
    }

    pub fn send_soft_newline_shift_return() {
        platform::send_soft_newline_shift_return();
    }

    pub fn send_clean_backspaces(count: usize) {
        platform::send_clean_backspaces(count);
    }

    pub fn send_select_all() {
        platform::send_select_all();
    }

    pub fn apply_clean_unicode_delta(from: &str, to: &str) {
        let a: Vec<char> = from.chars().collect();
        let b: Vec<char> = to.chars().collect();
        let mut common = 0usize;
        let lim = a.len().min(b.len());
        while common < lim && a[common] == b[common] {
            common += 1;
        }
        let erase = a.len().saturating_sub(common);
        if erase > 0 {
            Self::send_clean_backspaces(erase);
            std::thread::sleep(std::time::Duration::from_millis(6));
        }
        if common < b.len() {
            let suffix: String = b[common..].iter().collect();
            Self::type_clean_unicode(&suffix);
        }
    }

    pub fn get_focused_caret_screen_origin(pill_w: i32, pill_h: i32) -> Option<ScreenPoint> {
        platform::get_focused_caret_screen_origin(pill_w, pill_h)
    }

    pub fn default_bottom_origin(pill_w: i32, pill_h: i32) -> ScreenPoint {
        platform::default_bottom_origin(pill_w, pill_h)
    }
}

/// Optional Live Inline Typewriter + Prefix-Preserving SSE Morph Session (Windows SendInput Unicode).
pub struct LiveInputSession {
    inner: Mutex<LiveSessionState>,
}

struct LiveSessionState {
    context: ActiveScreenContext,
    emitted_text: String,
    previous_hypothesis: String,
    draft_before_sse: String,
    sse_accumulated: String,
    sse_has_diverged: bool,
    post_newline_guard: Option<String>,
}

impl LiveInputSession {
    pub fn new(context: ActiveScreenContext) -> Self {
        Self {
            inner: Mutex::new(LiveSessionState {
                context,
                emitted_text: String::new(),
                previous_hypothesis: String::new(),
                draft_before_sse: String::new(),
                sse_accumulated: String::new(),
                sse_has_diverged: false,
                post_newline_guard: None,
            }),
        }
    }

    pub fn update_context(&self, ctx: ActiveScreenContext) {
        self.inner.lock().context = ctx;
    }

    pub fn current_text(&self) -> String {
        self.inner.lock().emitted_text.clone()
    }

    pub fn update_live_text(&self, raw_hypothesis: &str, is_cloud_stream: bool) {
        let trimmed = raw_hypothesis
            .trim_end_matches(|c: char| "。，、！？；：.,!?;:… ".contains(c))
            .to_string();
        if trimmed.is_empty() {
            return;
        }

        let (erase_count, to_type) = {
            let mut s = self.inner.lock();
            if ContextInjector::is_own_process(&s.context) {
                return;
            }
            let target = if is_cloud_stream {
                trimmed.clone()
            } else {
                // Local SenseVoice anti-flicker agreement
                if s.previous_hypothesis.is_empty() {
                    trimmed.clone()
                } else {
                    let prev_c: Vec<char> = s.previous_hypothesis.chars().collect();
                    let curr_c: Vec<char> = trimmed.chars().collect();
                    let mut common = 0usize;
                    let lim = prev_c.len().min(curr_c.len());
                    while common < lim && prev_c[common] == curr_c[common] {
                        common += 1;
                    }
                    curr_c[..common].iter().collect()
                }
            };
            s.previous_hypothesis = trimmed;
            if target.is_empty() {
                return;
            }

            let e_chars: Vec<char> = s.emitted_text.chars().collect();
            let t_chars: Vec<char> = target.chars().collect();
            let mut common = 0usize;
            let lim = e_chars.len().min(t_chars.len());
            while common < lim && e_chars[common] == t_chars[common] {
                common += 1;
            }
            let erase = e_chars.len().saturating_sub(common);
            if erase > 6 || s.emitted_text.chars().rev().take(erase).any(|c| c == '\n') {
                return;
            }
            let append: String = t_chars[common..].iter().collect();
            s.emitted_text = target;
            (erase, append)
        };

        if erase_count > 0 {
            ContextInjector::send_clean_backspaces(erase_count);
            std::thread::sleep(std::time::Duration::from_millis(4));
        }
        if !to_type.is_empty() {
            ContextInjector::type_clean_unicode(&to_type);
        }
    }

    pub fn prepare_for_sse_polish(&self) -> bool {
        let mut s = self.inner.lock();
        if ContextInjector::is_own_process(&s.context) {
            return false;
        }
        s.draft_before_sse = s.emitted_text.clone();
        s.sse_accumulated.clear();
        s.sse_has_diverged = false;
        s.post_newline_guard = None;
        s.context.has_focused_text_input || ContextInjector::is_likely_editable_focus_now()
    }

    pub fn consume_sse_chunk(&self, delta: &str) {
        if delta.is_empty() {
            return;
        }
        let (backspaces, emit_text) = {
            let mut s = self.inner.lock();
            s.sse_accumulated.push_str(delta);
            if s.sse_has_diverged {
                s.emitted_text.push_str(delta);
                (0usize, delta.to_string())
            } else if s.draft_before_sse.starts_with(&s.sse_accumulated) {
                return;
            } else {
                s.sse_has_diverged = true;
                let d_chars: Vec<char> = s.draft_before_sse.chars().collect();
                let a_chars: Vec<char> = s.sse_accumulated.chars().collect();
                let mut common = 0usize;
                let lim = d_chars.len().min(a_chars.len());
                while common < lim && d_chars[common] == a_chars[common] {
                    common += 1;
                }
                let bs = d_chars.len().saturating_sub(common);
                let suffix: String = a_chars[common..].iter().collect();
                s.emitted_text = s.sse_accumulated.clone();
                (bs, suffix)
            }
        };

        if backspaces > 0 {
            ContextInjector::send_clean_backspaces(backspaces);
            std::thread::sleep(std::time::Duration::from_millis(4));
        }
        if !emit_text.is_empty() {
            self.emit_delta_guarding_auto_list(&emit_text);
        }
    }

    fn emit_delta_guarding_auto_list(&self, text: &str) {
        for ch in text.chars() {
            if ch == '\n' {
                self.flush_guard();
                ContextInjector::send_soft_newline_shift_return();
                self.inner.lock().post_newline_guard = Some(String::new());
                continue;
            }
            let pending = {
                let mut s = self.inner.lock();
                if let Some(buf) = s.post_newline_guard.as_mut() {
                    buf.push(ch);
                    let maybe_prefix = buf.chars().count() < 5
                        && buf
                            .chars()
                            .all(|c| c.is_ascii_digit() || matches!(c, '.' | '-' | '*' | '•' | ' '));
                    if maybe_prefix {
                        None
                    } else {
                        s.post_newline_guard.take()
                    }
                } else {
                    Some(ch.to_string())
                }
            };
            if let Some(chunk) = pending {
                ContextInjector::type_clean_unicode(&chunk);
            }
        }
    }

    fn flush_guard(&self) {
        let pending = self.inner.lock().post_newline_guard.take();
        if let Some(p) = pending {
            if !p.is_empty() {
                ContextInjector::type_clean_unicode(&p);
            }
        }
    }

    pub fn finish_sse_polish(&self, final_formatted: &str) {
        self.flush_guard();
        let (on_screen, is_term) = {
            let mut s = self.inner.lock();
            let curr = if s.sse_has_diverged {
                s.emitted_text.clone()
            } else {
                s.draft_before_sse.clone()
            };
            s.emitted_text = final_formatted.to_string();
            (curr, s.context.is_strict_shell_terminal())
        };

        if on_screen.as_str() != final_formatted {
            ContextInjector::apply_clean_unicode_delta(&on_screen, final_formatted);
        }

        if final_formatted.contains('\n') {
            std::thread::sleep(std::time::Duration::from_millis(14));
            if let Some(actual_box) = ContextInjector::read_current_focused_value() {
                if ContextInjector::contains_duplicated_list_marker(&actual_box, final_formatted) {
                    let collapsed = ContextInjector::collapse_duplicated_list_markers(&actual_box);
                    if collapsed.trim() == final_formatted.trim() {
                        ContextInjector::send_select_all();
                        std::thread::sleep(std::time::Duration::from_millis(8));
                        platform::paste_via_clipboard_preserving_snapshot(final_formatted, is_term);
                    }
                }
            }
        }
    }

    pub fn finalize_after_key_release(&self, final_formatted: &str) -> bool {
        let (on_screen, ctx) = {
            let mut s = self.inner.lock();
            let curr = s.emitted_text.clone();
            s.emitted_text = final_formatted.to_string();
            (curr, s.context.clone())
        };
        if !ctx.has_focused_text_input && !ContextInjector::is_likely_editable_focus_now() {
            ContextInjector::save_to_safety_clipboard(final_formatted);
            return false;
        }
        if on_screen.is_empty() {
            ContextInjector::inject_text_at_cursor(final_formatted, &ctx);
        } else if on_screen != final_formatted {
            ContextInjector::apply_clean_unicode_delta(&on_screen, final_formatted);
        }
        true
    }
}

#[cfg(target_os = "windows")]
mod platform {
    use super::{ActiveScreenContext, ScreenPoint, SYNTHETIC_EVENT_MARKER};
    use std::ffi::OsString;
    use std::os::windows::ffi::{OsStrExt, OsStringExt};
    use std::time::Duration;
    use windows::core::PWSTR;
    use windows::Win32::Foundation::{CloseHandle, HWND, POINT, RECT};
    use windows::Win32::Graphics::Gdi::{
        ClientToScreen, GetMonitorInfoW, MonitorFromPoint, MonitorFromWindow, MONITORINFO,
        MONITOR_DEFAULTTONEAREST,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoUninitialize, CLSCTX_INPROC_SERVER,
        COINIT_APARTMENTTHREADED,
    };
    use windows::Win32::System::DataExchange::{
        CloseClipboard, EmptyClipboard, GetClipboardData, OpenClipboard, SetClipboardData,
    };
    use windows::Win32::System::Memory::{GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE};
    use windows::Win32::System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, PROCESS_NAME_FORMAT,
        PROCESS_QUERY_LIMITED_INFORMATION,
    };
    use windows::Win32::UI::Accessibility::{
        CUIAutomation, IUIAutomation, IUIAutomationTextPattern, IUIAutomationValuePattern,
        UIA_DocumentControlTypeId, UIA_EditControlTypeId, UIA_TextPatternId, UIA_ValuePatternId,
    };
    use windows::Win32::UI::Input::KeyboardAndMouse::{
        SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT, KEYEVENTF_KEYUP, KEYEVENTF_UNICODE,
        VIRTUAL_KEY, VK_A, VK_BACK, VK_CONTROL, VK_INSERT, VK_RETURN, VK_SHIFT, VK_V,
    };
    use windows::Win32::UI::WindowsAndMessaging::{
        GetCursorPos, GetForegroundWindow, GetGUIThreadInfo, GetWindowRect, GetWindowTextW,
        GetWindowThreadProcessId, GUITHREADINFO,
    };

    const CF_UNICODETEXT_U32: u32 = 13;

    pub fn capture_fast_foreground_app() -> (String, String, String) {
        unsafe {
            let hwnd = GetForegroundWindow();
            if hwnd.0.is_null() {
                return (String::new(), String::new(), String::new());
            }
            let mut title_buf = [0u16; 512];
            let title_len = GetWindowTextW(hwnd, &mut title_buf);
            let title = if title_len > 0 {
                OsString::from_wide(&title_buf[..title_len as usize])
                    .to_string_lossy()
                    .to_string()
            } else {
                String::new()
            };

            let mut pid: u32 = 0;
            GetWindowThreadProcessId(hwnd, Some(&mut pid));
            let mut process_name = String::new();
            if pid != 0 {
                if let Ok(proc_handle) = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
                {
                    let mut path_buf = [0u16; 520];
                    let mut size = path_buf.len() as u32;
                    if QueryFullProcessImageNameW(
                        proc_handle,
                        PROCESS_NAME_FORMAT(0),
                        PWSTR(path_buf.as_mut_ptr()),
                        &mut size,
                    )
                    .is_ok()
                        && size > 0
                    {
                        let full = OsString::from_wide(&path_buf[..size as usize])
                            .to_string_lossy()
                            .to_string();
                        if let Some(fname) = std::path::Path::new(&full)
                            .file_name()
                            .and_then(|s| s.to_str())
                        {
                            process_name = fname.to_string();
                        }
                    }
                    let _ = CloseHandle(proc_handle);
                }
            }

            let app_name = process_name
                .strip_suffix(".exe")
                .or_else(|| process_name.strip_suffix(".EXE"))
                .unwrap_or(&process_name)
                .to_string();

            (app_name, process_name, title)
        }
    }

    pub fn capture_current_context() -> ActiveScreenContext {
        let (app_name, process_name, window_title) = capture_fast_foreground_app();
        let (selected_text, preceding_text, has_editable) = query_uia_focused_text_state();
        let is_explorer_desktop = process_name.eq_ignore_ascii_case("explorer.exe")
            && (window_title.is_empty() || window_title == "Program Manager");

        ActiveScreenContext {
            app_name,
            process_name,
            window_title,
            selected_text,
            preceding_text,
            has_focused_text_input: has_editable || !is_explorer_desktop,
        }
    }

    fn query_uia_focused_text_state() -> (String, String, bool) {
        unsafe {
            let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
            let should_uninit = hr.is_ok();
            let result = (|| -> Option<(String, String, bool)> {
                let uia: IUIAutomation =
                    CoCreateInstance(&CUIAutomation, None, CLSCTX_INPROC_SERVER).ok()?;
                let elem = uia.GetFocusedElement().ok()?;
                let ctrl_type = elem.CurrentControlType().ok()?;
                let mut is_editable = ctrl_type == UIA_EditControlTypeId
                    || ctrl_type == UIA_DocumentControlTypeId;
                let mut selected = String::new();
                let mut preceding = String::new();

                if let Ok(tp) = elem.GetCurrentPatternAs::<IUIAutomationTextPattern>(UIA_TextPatternId)
                {
                    is_editable = true;
                    if let Ok(sel_arr) = tp.GetSelection() {
                        if let Ok(len) = sel_arr.Length() {
                            if len > 0 {
                                if let Ok(range) = sel_arr.GetElement(0) {
                                    if let Ok(bstr) = range.GetText(512) {
                                        let s = bstr.to_string().trim().to_string();
                                        if !s.is_empty() {
                                            selected = s;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let Ok(doc_range) = tp.DocumentRange() {
                        if let Ok(bstr) = doc_range.GetText(300) {
                            let s = bstr.to_string();
                            let chars: Vec<char> = s.chars().collect();
                            preceding = if chars.len() > 140 {
                                chars[chars.len() - 140..].iter().collect()
                            } else {
                                s
                            };
                        }
                    }
                } else if let Ok(vp) =
                    elem.GetCurrentPatternAs::<IUIAutomationValuePattern>(UIA_ValuePatternId)
                {
                    let readonly = vp.CurrentIsReadOnly().map(|b| b.as_bool()).unwrap_or(false);
                    if !readonly {
                        is_editable = true;
                    }
                    if let Ok(val) = vp.CurrentValue() {
                        let s = val.to_string();
                        let chars: Vec<char> = s.chars().collect();
                        preceding = if chars.len() > 140 {
                            chars[chars.len() - 140..].iter().collect()
                        } else {
                            s
                        };
                    }
                }

                Some((selected, preceding, is_editable))
            })()
            .unwrap_or((String::new(), String::new(), false));

            if should_uninit {
                CoUninitialize();
            }
            result
        }
    }

    pub fn read_current_focused_value() -> Option<String> {
        unsafe {
            let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
            let should_uninit = hr.is_ok();
            let result = (|| -> Option<String> {
                let uia: IUIAutomation =
                    CoCreateInstance(&CUIAutomation, None, CLSCTX_INPROC_SERVER).ok()?;
                let elem = uia.GetFocusedElement().ok()?;
                if let Ok(vp) =
                    elem.GetCurrentPatternAs::<IUIAutomationValuePattern>(UIA_ValuePatternId)
                {
                    if let Ok(val) = vp.CurrentValue() {
                        let s = val.to_string();
                        if !s.is_empty() {
                            return Some(s);
                        }
                    }
                }
                if let Ok(tp) = elem.GetCurrentPatternAs::<IUIAutomationTextPattern>(UIA_TextPatternId)
                {
                    if let Ok(range) = tp.DocumentRange() {
                        if let Ok(bstr) = range.GetText(4096) {
                            let s = bstr.to_string();
                            if !s.is_empty() {
                                return Some(s);
                            }
                        }
                    }
                }
                None
            })();
            if should_uninit {
                CoUninitialize();
            }
            result
        }
    }

    pub fn is_likely_editable_focus_now() -> bool {
        let (_, _, editable) = query_uia_focused_text_state();
        if editable {
            return true;
        }
        unsafe {
            let hwnd = GetForegroundWindow();
            if hwnd.0.is_null() {
                return false;
            }
            let tid = GetWindowThreadProcessId(hwnd, None);
            let mut gui = GUITHREADINFO {
                cbSize: std::mem::size_of::<GUITHREADINFO>() as u32,
                ..Default::default()
            };
            if GetGUIThreadInfo(tid, &mut gui).is_ok() && !gui.hwndCaret.0.is_null() {
                return true;
            }
            true
        }
    }

    pub fn read_clipboard_text() -> Option<String> {
        unsafe {
            for _ in 0..5 {
                if OpenClipboard(HWND::default()).is_ok() {
                    let result = (|| -> Option<String> {
                        let handle = GetClipboardData(CF_UNICODETEXT_U32).ok()?;
                        let hmem = windows::Win32::Foundation::HGLOBAL(handle.0);
                        let ptr = GlobalLock(hmem) as *const u16;
                        if ptr.is_null() {
                            return None;
                        }
                        let mut len = 0usize;
                        while *ptr.add(len) != 0 {
                            len += 1;
                        }
                        let slice = std::slice::from_raw_parts(ptr, len);
                        let text = OsString::from_wide(slice).to_string_lossy().to_string();
                        let _ = GlobalUnlock(hmem);
                        Some(text)
                    })();
                    let _ = CloseClipboard();
                    return result;
                }
                std::thread::sleep(Duration::from_millis(8));
            }
            None
        }
    }

    pub fn write_clipboard_text(text: &str) -> bool {
        let wide: Vec<u16> = std::ffi::OsStr::new(text)
            .encode_wide()
            .chain(std::iter::once(0))
            .collect();
        let byte_len = wide.len() * 2;
        unsafe {
            for _ in 0..5 {
                if OpenClipboard(HWND::default()).is_ok() {
                    let _ = EmptyClipboard();
                    let ok = if let Ok(hmem) = GlobalAlloc(GMEM_MOVEABLE, byte_len) {
                        let ptr = GlobalLock(hmem) as *mut u16;
                        if !ptr.is_null() {
                            std::ptr::copy_nonoverlapping(wide.as_ptr(), ptr, wide.len());
                            let _ = GlobalUnlock(hmem);
                            SetClipboardData(
                                CF_UNICODETEXT_U32,
                                windows::Win32::Foundation::HANDLE(hmem.0),
                            )
                            .is_ok()
                        } else {
                            false
                        }
                    } else {
                        false
                    };
                    let _ = CloseClipboard();
                    return ok;
                }
                std::thread::sleep(Duration::from_millis(8));
            }
            false
        }
    }

    pub fn paste_via_clipboard_preserving_snapshot(text: &str, use_shift_insert: bool) {
        let previous = read_clipboard_text();
        if !write_clipboard_text(text) {
            type_clean_unicode(text);
            return;
        }
        std::thread::sleep(Duration::from_millis(12));
        if use_shift_insert {
            send_key_combo(VK_SHIFT, VK_INSERT);
        } else {
            send_key_combo(VK_CONTROL, VK_V);
        }
        // Restore user's original clipboard asynchronously after target app finishes WM_PASTE!
        if let Some(prev) = previous {
            let pasted = text.to_string();
            std::thread::spawn(move || {
                std::thread::sleep(Duration::from_millis(160));
                if read_clipboard_text().as_deref() == Some(pasted.as_str()) {
                    let _ = write_clipboard_text(&prev);
                }
            });
        }
    }

    fn key_input(vk: VIRTUAL_KEY, key_up: bool) -> INPUT {
        INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: vk,
                    wScan: 0,
                    dwFlags: if key_up {
                        KEYEVENTF_KEYUP
                    } else {
                        Default::default()
                    },
                    time: 0,
                    dwExtraInfo: SYNTHETIC_EVENT_MARKER,
                },
            },
        }
    }

    fn send_key_combo(modifier: VIRTUAL_KEY, key: VIRTUAL_KEY) {
        let inputs = [
            key_input(modifier, false),
            key_input(key, false),
            key_input(key, true),
            key_input(modifier, true),
        ];
        unsafe {
            let _ = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
        }
    }

    pub fn send_select_all() {
        send_key_combo(VK_CONTROL, VK_A);
    }

    pub fn send_soft_newline_shift_return() {
        send_key_combo(VK_SHIFT, VK_RETURN);
    }

    pub fn send_clean_backspaces(count: usize) {
        if count == 0 {
            return;
        }
        let mut inputs = Vec::with_capacity(count * 2);
        for _ in 0..count {
            inputs.push(key_input(VK_BACK, false));
            inputs.push(key_input(VK_BACK, true));
        }
        unsafe {
            let _ = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
        }
    }

    pub fn type_clean_unicode(text: &str) {
        if text.is_empty() {
            return;
        }
        for ch in text.chars() {
            if ch == '\n' {
                send_soft_newline_shift_return();
                continue;
            }
            if ch == '\r' {
                continue;
            }
            let mut buf = [0u16; 2];
            let units = ch.encode_utf16(&mut buf);
            let mut inputs = Vec::with_capacity(units.len() * 2);
            for &unit in units.iter() {
                inputs.push(INPUT {
                    r#type: INPUT_KEYBOARD,
                    Anonymous: INPUT_0 {
                        ki: KEYBDINPUT {
                            wVk: VIRTUAL_KEY(0),
                            wScan: unit,
                            dwFlags: KEYEVENTF_UNICODE,
                            time: 0,
                            dwExtraInfo: SYNTHETIC_EVENT_MARKER,
                        },
                    },
                });
                inputs.push(INPUT {
                    r#type: INPUT_KEYBOARD,
                    Anonymous: INPUT_0 {
                        ki: KEYBDINPUT {
                            wVk: VIRTUAL_KEY(0),
                            wScan: unit,
                            dwFlags: KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                            time: 0,
                            dwExtraInfo: SYNTHETIC_EVENT_MARKER,
                        },
                    },
                });
            }
            unsafe {
                let _ = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
            }
        }
    }

    fn work_area_for_hwnd(hwnd: HWND) -> RECT {
        unsafe {
            let hmon = if !hwnd.0.is_null() {
                MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)
            } else {
                let mut pt = POINT::default();
                let _ = GetCursorPos(&mut pt);
                MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST)
            };
            let mut mi = MONITORINFO {
                cbSize: std::mem::size_of::<MONITORINFO>() as u32,
                ..Default::default()
            };
            if GetMonitorInfoW(hmon, &mut mi).as_bool() {
                mi.rcWork
            } else {
                RECT {
                    left: 0,
                    top: 0,
                    right: 1920,
                    bottom: 1040,
                }
            }
        }
    }

    fn clamp_pill_near_rect(anchor: RECT, work: RECT, pill_w: i32, pill_h: i32) -> ScreenPoint {
        let center_x = (anchor.left + anchor.right) / 2;
        let x = (center_x - pill_w / 2).clamp(work.left + 12, (work.right - pill_w - 12).max(work.left));
        // Prefer directly below the caret/input; if too close to Taskbar, flip cleanly ABOVE!
        let below_y = anchor.bottom + 10;
        let y = if below_y + pill_h <= work.bottom - 8 {
            below_y
        } else {
            (anchor.top - pill_h - 10).clamp(work.top + 8, (work.bottom - pill_h - 8).max(work.top))
        };
        ScreenPoint { x, y }
    }

    /// 3-Tier Windows Caret / Input Anchor Ladder:
    /// L1: Win32 `GetGUIThreadInfo` Caret -> L2: UI Automation Focused Element Bounds -> L3: Active Window bottom-center.
    pub fn get_focused_caret_screen_origin(pill_w: i32, pill_h: i32) -> Option<ScreenPoint> {
        unsafe {
            let hwnd = GetForegroundWindow();
            if hwnd.0.is_null() {
                return None;
            }
            let work = work_area_for_hwnd(hwnd);

            // L1: Exact Win32 Caret
            let tid = GetWindowThreadProcessId(hwnd, None);
            let mut gui = GUITHREADINFO {
                cbSize: std::mem::size_of::<GUITHREADINFO>() as u32,
                ..Default::default()
            };
            if GetGUIThreadInfo(tid, &mut gui).is_ok() && !gui.hwndCaret.0.is_null() {
                let mut tl = POINT {
                    x: gui.rcCaret.left,
                    y: gui.rcCaret.top,
                };
                let mut br = POINT {
                    x: gui.rcCaret.right,
                    y: gui.rcCaret.bottom,
                };
                if ClientToScreen(gui.hwndCaret, &mut tl).as_bool()
                    && ClientToScreen(gui.hwndCaret, &mut br).as_bool()
                    && (br.y - tl.y) > 0
                {
                    let rect = RECT {
                        left: tl.x,
                        top: tl.y,
                        right: br.x.max(tl.x + 2),
                        bottom: br.y,
                    };
                    return Some(clamp_pill_near_rect(rect, work, pill_w, pill_h));
                }
            }

            // L2: UI Automation Focused Control Bounding Rect (works in Chrome / Edge / VS Code / WeChat / Feishu!)
            let hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
            let should_uninit = hr.is_ok();
            let uia_rect = (|| -> Option<RECT> {
                let uia: IUIAutomation =
                    CoCreateInstance(&CUIAutomation, None, CLSCTX_INPROC_SERVER).ok()?;
                let elem = uia.GetFocusedElement().ok()?;
                let r = elem.CurrentBoundingRectangle().ok()?;
                let w = r.right - r.left;
                let h = r.bottom - r.top;
                if w > 8 && h > 8 && w < (work.right - work.left) {
                    Some(r)
                } else {
                    None
                }
            })();
            if should_uninit {
                CoUninitialize();
            }
            if let Some(r) = uia_rect {
                return Some(clamp_pill_near_rect(r, work, pill_w, pill_h));
            }

            // L3: Active Window bottom-center within monitor work area
            let mut win_rect = RECT::default();
            if GetWindowRect(hwnd, &mut win_rect).is_ok() {
                let cx = (win_rect.left + win_rect.right) / 2;
                let x = (cx - pill_w / 2).clamp(work.left + 12, (work.right - pill_w - 12).max(work.left));
                let y = (win_rect.bottom - pill_h - 32)
                    .clamp(work.top + 16, (work.bottom - pill_h - 18).max(work.top));
                return Some(ScreenPoint { x, y });
            }

            None
        }
    }

    pub fn default_bottom_origin(pill_w: i32, pill_h: i32) -> ScreenPoint {
        unsafe {
            let hwnd = GetForegroundWindow();
            let work = work_area_for_hwnd(hwnd);
            let x = (work.left + work.right) / 2 - pill_w / 2;
            let y = work.bottom - pill_h - 24;
            ScreenPoint { x, y }
        }
    }
}

#[cfg(not(target_os = "windows"))]
mod platform {
    use super::{ActiveScreenContext, ScreenPoint};
    use once_cell::sync::Lazy;
    use parking_lot::Mutex;

    static MOCK_CLIPBOARD: Lazy<Mutex<String>> = Lazy::new(|| Mutex::new(String::new()));

    pub fn capture_fast_foreground_app() -> (String, String, String) {
        ("TypeZero".to_string(), "TypeZero.exe".to_string(), "TypeZero".to_string())
    }
    pub fn capture_current_context() -> ActiveScreenContext {
        ActiveScreenContext::empty()
    }
    pub fn read_current_focused_value() -> Option<String> {
        None
    }
    pub fn is_likely_editable_focus_now() -> bool {
        true
    }
    pub fn read_clipboard_text() -> Option<String> {
        let s = MOCK_CLIPBOARD.lock().clone();
        if s.is_empty() { None } else { Some(s) }
    }
    pub fn write_clipboard_text(text: &str) -> bool {
        *MOCK_CLIPBOARD.lock() = text.to_string();
        true
    }
    pub fn paste_via_clipboard_preserving_snapshot(text: &str, _use_shift_insert: bool) {
        let _ = write_clipboard_text(text);
    }
    pub fn type_clean_unicode(_text: &str) {}
    pub fn send_soft_newline_shift_return() {}
    pub fn send_clean_backspaces(_count: usize) {}
    pub fn send_select_all() {}
    pub fn get_focused_caret_screen_origin(_pill_w: i32, _pill_h: i32) -> Option<ScreenPoint> {
        None
    }
    pub fn default_bottom_origin(_pill_w: i32, _pill_h: i32) -> ScreenPoint {
        ScreenPoint { x: 840, y: 940 }
    }
}
