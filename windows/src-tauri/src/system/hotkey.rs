use crate::models::{CustomHotkeySpec, TriggerBehavior, TriggerKeyOption};
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use std::sync::Arc;
use std::time::{Duration, Instant};

/// Magic `dwExtraInfo` marker stamped on all synthetic `SendInput` events from TypeZero ("TZSY").
pub const SYNTHETIC_EVENT_MARKER: usize = 0x545A_5359;

// Standard Windows Virtual-Key Codes
pub const VK_ESCAPE: u32 = 0x1B;
pub const VK_SPACE: u32 = 0x20;
pub const VK_CAPITAL: u32 = 0x14;
pub const VK_LSHIFT: u32 = 0xA0;
pub const VK_RSHIFT: u32 = 0xA1;
pub const VK_LCONTROL: u32 = 0xA2;
pub const VK_RCONTROL: u32 = 0xA3;
pub const VK_LMENU: u32 = 0xA4;
pub const VK_RMENU: u32 = 0xA5;
pub const VK_LWIN: u32 = 0x5B;
pub const VK_RWIN: u32 = 0x5C;
pub const VK_F1: u32 = 0x70;
pub const VK_F2: u32 = 0x71;
pub const VK_F12: u32 = 0x7B;

pub const MOD_CTRL: u32 = 1;
pub const MOD_ALT: u32 = 2;
pub const MOD_SHIFT: u32 = 4;
pub const MOD_WIN: u32 = 8;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RecordedShortcutResult {
    Preset(TriggerKeyOption),
    Custom(CustomHotkeySpec),
    Cancelled,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct ModifierSnapshot {
    pub lctrl: bool,
    pub rctrl: bool,
    pub lalt: bool,
    pub ralt: bool,
    pub lshift: bool,
    pub rshift: bool,
    pub lwin: bool,
    pub rwin: bool,
}

impl ModifierSnapshot {
    pub fn ctrl(&self) -> bool {
        self.lctrl || self.rctrl
    }
    pub fn alt(&self) -> bool {
        self.lalt || self.ralt
    }
    pub fn shift(&self) -> bool {
        self.lshift || self.rshift
    }
    pub fn win(&self) -> bool {
        self.lwin || self.rwin
    }
    pub fn bitmask(&self) -> u32 {
        let mut m = 0u32;
        if self.ctrl() {
            m |= MOD_CTRL;
        }
        if self.alt() {
            m |= MOD_ALT;
        }
        if self.shift() {
            m |= MOD_SHIFT;
        }
        if self.win() {
            m |= MOD_WIN;
        }
        m
    }
    pub fn active_count(&self) -> u32 {
        [
            self.lctrl,
            self.rctrl,
            self.lalt,
            self.ralt,
            self.lshift,
            self.rshift,
            self.lwin,
            self.rwin,
        ]
        .into_iter()
        .filter(|&b| b)
        .count() as u32
    }
    pub fn update(&mut self, vk: u32, is_down: bool) -> bool {
        match vk {
            VK_LCONTROL => self.lctrl = is_down,
            VK_RCONTROL => self.rctrl = is_down,
            VK_LMENU => self.lalt = is_down,
            VK_RMENU => self.ralt = is_down,
            VK_LSHIFT => self.lshift = is_down,
            VK_RSHIFT => self.rshift = is_down,
            VK_LWIN => self.lwin = is_down,
            VK_RWIN => self.rwin = is_down,
            _ => return false,
        }
        true
    }
}

pub fn single_modifier_option_for_vk(vk: u32) -> Option<TriggerKeyOption> {
    match vk {
        VK_RMENU => Some(TriggerKeyOption::RightAlt),
        VK_RCONTROL => Some(TriggerKeyOption::RightCtrl),
        VK_LMENU => Some(TriggerKeyOption::LeftAlt),
        VK_LCONTROL => Some(TriggerKeyOption::LeftCtrl),
        VK_RSHIFT => Some(TriggerKeyOption::RightShift),
        VK_LSHIFT => Some(TriggerKeyOption::LeftShift),
        _ => None,
    }
}

pub fn matches_single_modifier_press(
    option: TriggerKeyOption,
    vk: u32,
    mods: ModifierSnapshot,
) -> bool {
    match option {
        TriggerKeyOption::RightAlt => vk == VK_RMENU && mods.ralt && !mods.ctrl() && !mods.shift() && !mods.win() && !mods.lalt,
        TriggerKeyOption::RightCtrl => vk == VK_RCONTROL && mods.rctrl && !mods.alt() && !mods.shift() && !mods.win() && !mods.lctrl,
        TriggerKeyOption::LeftAlt => vk == VK_LMENU && mods.lalt && !mods.ctrl() && !mods.shift() && !mods.win() && !mods.ralt,
        TriggerKeyOption::LeftCtrl => vk == VK_LCONTROL && mods.lctrl && !mods.alt() && !mods.shift() && !mods.win() && !mods.rctrl,
        TriggerKeyOption::RightShift => vk == VK_RSHIFT && mods.rshift && !mods.ctrl() && !mods.alt() && !mods.win() && !mods.lshift,
        TriggerKeyOption::LeftShift => vk == VK_LSHIFT && mods.lshift && !mods.ctrl() && !mods.alt() && !mods.win() && !mods.rshift,
        _ => false,
    }
}

pub fn is_function_key(vk: u32) -> bool {
    (VK_F1..=VK_F12).contains(&vk)
}

pub fn format_combo_label(vk: u32, modifiers: u32) -> String {
    let mut parts: Vec<String> = Vec::new();
    if modifiers & MOD_CTRL != 0 {
        parts.push("Ctrl".to_string());
    }
    if modifiers & MOD_ALT != 0 {
        parts.push("Alt".to_string());
    }
    if modifiers & MOD_SHIFT != 0 {
        parts.push("Shift".to_string());
    }
    if modifiers & MOD_WIN != 0 {
        parts.push("Win".to_string());
    }
    parts.push(vk_display_name(vk));
    parts.join(" + ")
}

pub fn vk_display_name(vk: u32) -> String {
    match vk {
        VK_SPACE => "Space".to_string(),
        VK_CAPITAL => "CapsLock".to_string(),
        0x09 => "Tab".to_string(),
        0x0D => "Enter".to_string(),
        0x08 => "Backspace".to_string(),
        0xC0 => "`".to_string(),
        0xBD => "-".to_string(),
        0xBB => "=".to_string(),
        0xDB => "[".to_string(),
        0xDD => "]".to_string(),
        0xDC => "\\".to_string(),
        0xBA => ";".to_string(),
        0xDE => "'".to_string(),
        0xBC => ",".to_string(),
        0xBE => ".".to_string(),
        0xBF => "/".to_string(),
        0x30..=0x39 => ((vk as u8) as char).to_string(),
        0x41..=0x5A => ((vk as u8) as char).to_string(),
        VK_F1..=VK_F12 => format!("F{}", vk - VK_F1 + 1),
        _ => format!("Key(0x{vk:02X})"),
    }
}

#[derive(Clone, Default)]
pub struct HotkeyCallbacks {
    pub on_prewarm_mic: Option<Arc<dyn Fn() + Send + Sync>>,
    pub on_trigger_start: Option<Arc<dyn Fn() + Send + Sync>>,
    pub on_trigger_stop: Option<Arc<dyn Fn() + Send + Sync>>,
    pub on_cancel: Option<Arc<dyn Fn() + Send + Sync>>,
}

struct HookRuntimeState {
    trigger_option: TriggerKeyOption,
    custom_spec: CustomHotkeySpec,
    behavior: TriggerBehavior,
    callbacks: HotkeyCallbacks,
    mods: ModifierSnapshot,
    is_trigger_down: bool,
    other_key_pressed_during_hold: bool,
    is_recording_active: bool,
    hold_did_fire_start: bool,
    hold_generation: u64,
    swallow_next_release_after_stop: bool,
    is_capturing: bool,
    capture_candidate_single: Option<TriggerKeyOption>,
    capture_saw_other_key: bool,
    capture_callback: Option<Arc<dyn Fn(RecordedShortcutResult) + Send + Sync>>,
    last_hold_down_at: Option<Instant>,
}

impl Default for HookRuntimeState {
    fn default() -> Self {
        Self {
            trigger_option: TriggerKeyOption::RightAlt,
            custom_spec: CustomHotkeySpec::default(),
            behavior: TriggerBehavior::TapToggle,
            callbacks: HotkeyCallbacks::default(),
            mods: ModifierSnapshot::default(),
            is_trigger_down: false,
            other_key_pressed_during_hold: false,
            is_recording_active: false,
            hold_did_fire_start: false,
            hold_generation: 0,
            swallow_next_release_after_stop: false,
            is_capturing: false,
            capture_candidate_single: None,
            capture_saw_other_key: false,
            capture_callback: None,
            last_hold_down_at: None,
        }
    }
}

static HOOK_STATE: Lazy<Mutex<HookRuntimeState>> = Lazy::new(|| Mutex::new(HookRuntimeState::default()));

/// Action emitted by processing a single low-level keyboard event.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KeyHookDecision {
    PassThrough,
    Swallow,
    SuppressAltMenuAndPass,
}

pub struct HotkeyMonitor;

impl HotkeyMonitor {
    pub fn configure(
        trigger: TriggerKeyOption,
        custom: CustomHotkeySpec,
        behavior: TriggerBehavior,
    ) {
        let mut s = HOOK_STATE.lock();
        s.trigger_option = trigger;
        s.custom_spec = custom;
        s.behavior = behavior;
        s.is_trigger_down = false;
        s.other_key_pressed_during_hold = false;
        s.hold_did_fire_start = false;
        s.swallow_next_release_after_stop = false;
        s.hold_generation = s.hold_generation.wrapping_add(1);
    }

    pub fn set_callbacks(callbacks: HotkeyCallbacks) {
        HOOK_STATE.lock().callbacks = callbacks;
    }

    pub fn sync_recording_state(active: bool) {
        let mut s = HOOK_STATE.lock();
        s.is_recording_active = active;
        if !active {
            s.is_trigger_down = false;
            s.hold_did_fire_start = false;
            s.hold_generation = s.hold_generation.wrapping_add(1);
        }
    }

    pub fn begin_interactive_capture<F>(cb: F)
    where
        F: Fn(RecordedShortcutResult) + Send + Sync + 'static,
    {
        let mut s = HOOK_STATE.lock();
        s.is_capturing = true;
        s.capture_candidate_single = None;
        s.capture_saw_other_key = false;
        s.capture_callback = Some(Arc::new(cb));
    }

    pub fn cancel_interactive_capture() {
        let mut s = HOOK_STATE.lock();
        s.is_capturing = false;
        s.capture_candidate_single = None;
        s.capture_saw_other_key = false;
        s.capture_callback = None;
    }

    /// Starts the Win32 `WH_KEYBOARD_LL` global hook on a dedicated message-loop thread.
    pub fn start() {
        #[cfg(target_os = "windows")]
        win_hook::start_windows_hook_thread();
    }

    /// Pure keyboard state-machine processor (callable from Win32 hook AND unit tests!).
    pub fn process_key_event(vk: u32, is_down: bool, extra_info: usize) -> KeyHookDecision {
        if extra_info == SYNTHETIC_EVENT_MARKER || vk == 0xFF {
            return KeyHookDecision::PassThrough;
        }

        let mut fire_prewarm: Option<Arc<dyn Fn() + Send + Sync>> = None;
        let mut fire_start: Option<Arc<dyn Fn() + Send + Sync>> = None;
        let mut fire_stop: Option<Arc<dyn Fn() + Send + Sync>> = None;
        let mut fire_cancel: Option<Arc<dyn Fn() + Send + Sync>> = None;
        let mut fire_capture: Option<(Arc<dyn Fn(RecordedShortcutResult) + Send + Sync>, RecordedShortcutResult)> = None;
        let mut spawn_delayed_hold_gen: Option<u64> = None;

        let decision = {
            let mut s = HOOK_STATE.lock();
            let is_mod_key = s.mods.update(vk, is_down);

            // 1. Interactive Shortcut Recorder mode
            if s.is_capturing {
                if is_mod_key {
                    if is_down {
                        if !s.capture_saw_other_key && s.mods.active_count() == 1 {
                            s.capture_candidate_single = single_modifier_option_for_vk(vk);
                        } else {
                            s.capture_candidate_single = None;
                            s.capture_saw_other_key = true;
                        }
                    } else if s.mods.active_count() == 0 {
                        if let Some(opt) = s.capture_candidate_single.take() {
                            if !s.capture_saw_other_key {
                                s.is_capturing = false;
                                if let Some(cb) = s.capture_callback.take() {
                                    fire_capture = Some((cb, RecordedShortcutResult::Preset(opt)));
                                }
                            }
                        } else {
                            s.capture_saw_other_key = false;
                        }
                    }
                    KeyHookDecision::Swallow
                } else if is_down {
                    s.capture_saw_other_key = true;
                    s.capture_candidate_single = None;
                    let mask = s.mods.bitmask();
                    if vk == VK_ESCAPE && mask == 0 {
                        s.is_capturing = false;
                        if let Some(cb) = s.capture_callback.take() {
                            fire_capture = Some((cb, RecordedShortcutResult::Cancelled));
                        }
                        KeyHookDecision::Swallow
                    } else if vk == VK_CAPITAL && mask == 0 {
                        s.is_capturing = false;
                        if let Some(cb) = s.capture_callback.take() {
                            fire_capture = Some((cb, RecordedShortcutResult::Preset(TriggerKeyOption::CapsLock)));
                        }
                        KeyHookDecision::Swallow
                    } else if vk == VK_F2 && mask == 0 {
                        s.is_capturing = false;
                        if let Some(cb) = s.capture_callback.take() {
                            fire_capture = Some((cb, RecordedShortcutResult::Preset(TriggerKeyOption::F2)));
                        }
                        KeyHookDecision::Swallow
                    } else if vk == VK_SPACE && mask == MOD_ALT {
                        s.is_capturing = false;
                        if let Some(cb) = s.capture_callback.take() {
                            fire_capture = Some((cb, RecordedShortcutResult::Preset(TriggerKeyOption::AltSpace)));
                        }
                        KeyHookDecision::Swallow
                    } else if vk == VK_SPACE && mask == MOD_CTRL {
                        s.is_capturing = false;
                        if let Some(cb) = s.capture_callback.take() {
                            fire_capture = Some((cb, RecordedShortcutResult::Preset(TriggerKeyOption::CtrlSpace)));
                        }
                        KeyHookDecision::Swallow
                    } else if mask != 0 || is_function_key(vk) {
                        let spec = CustomHotkeySpec {
                            vk_code: vk,
                            modifiers: mask,
                            label: format_combo_label(vk, mask),
                        };
                        s.is_capturing = false;
                        if let Some(cb) = s.capture_callback.take() {
                            fire_capture = Some((cb, RecordedShortcutResult::Custom(spec)));
                        }
                        KeyHookDecision::Swallow
                    } else {
                        KeyHookDecision::Swallow
                    }
                } else {
                    KeyHookDecision::Swallow
                }
            }
            // 2. Esc cancels active dictation immediately
            else if vk == VK_ESCAPE && is_down && s.is_recording_active && s.mods.bitmask() == 0 {
                s.is_recording_active = false;
                s.is_trigger_down = false;
                s.hold_did_fire_start = false;
                s.hold_generation = s.hold_generation.wrapping_add(1);
                fire_cancel = s.callbacks.on_cancel.clone();
                KeyHookDecision::Swallow
            }
            // 3. Single-modifier trigger options (RightAlt, RightCtrl, LeftAlt, LeftCtrl, RightShift, LeftShift)
            else if s.trigger_option.is_single_modifier_key() {
                let target_vk = match s.trigger_option {
                    TriggerKeyOption::RightAlt => VK_RMENU,
                    TriggerKeyOption::RightCtrl => VK_RCONTROL,
                    TriggerKeyOption::LeftAlt => VK_LMENU,
                    TriggerKeyOption::LeftCtrl => VK_LCONTROL,
                    TriggerKeyOption::RightShift => VK_RSHIFT,
                    TriggerKeyOption::LeftShift => VK_LSHIFT,
                    _ => 0,
                };

                if vk != target_vk {
                    // User pressed another key while holding our modifier -> this is a normal combo (Ctrl+C, Alt+Tab, Shift+A)!
                    if is_down && s.is_trigger_down {
                        s.other_key_pressed_during_hold = true;
                        s.hold_generation = s.hold_generation.wrapping_add(1);
                    }
                    KeyHookDecision::PassThrough
                } else if is_down {
                    if !s.is_trigger_down && matches_single_modifier_press(s.trigger_option, vk, s.mods) {
                        s.is_trigger_down = true;
                        s.other_key_pressed_during_hold = false;
                        s.hold_did_fire_start = false;
                        s.last_hold_down_at = Some(Instant::now());

                        match s.behavior {
                            TriggerBehavior::TapToggle => {
                                if s.is_recording_active {
                                    // 0ms shutter stop on key-down!
                                    s.is_recording_active = false;
                                    s.swallow_next_release_after_stop = true;
                                    fire_stop = s.callbacks.on_trigger_stop.clone();
                                } else {
                                    fire_prewarm = s.callbacks.on_prewarm_mic.clone();
                                }
                            }
                            TriggerBehavior::HoldToTalk => {
                                fire_prewarm = s.callbacks.on_prewarm_mic.clone();
                                if s.trigger_option.is_combo_prone_left_modifier() {
                                    s.hold_generation = s.hold_generation.wrapping_add(1);
                                    spawn_delayed_hold_gen = Some(s.hold_generation);
                                } else {
                                    s.hold_did_fire_start = true;
                                    s.is_recording_active = true;
                                    fire_start = s.callbacks.on_trigger_start.clone();
                                }
                            }
                        }
                    }
                    KeyHookDecision::PassThrough
                } else {
                    // Modifier released
                    if s.is_trigger_down {
                        s.is_trigger_down = false;
                        s.hold_generation = s.hold_generation.wrapping_add(1);
                        let was_clean_solo = !s.other_key_pressed_during_hold;
                        let is_alt_trigger = matches!(
                            s.trigger_option,
                            TriggerKeyOption::RightAlt | TriggerKeyOption::LeftAlt
                        );

                        if s.swallow_next_release_after_stop {
                            s.swallow_next_release_after_stop = false;
                            if is_alt_trigger && was_clean_solo {
                                KeyHookDecision::SuppressAltMenuAndPass
                            } else {
                                KeyHookDecision::PassThrough
                            }
                        } else {
                            match s.behavior {
                                TriggerBehavior::TapToggle => {
                                    if was_clean_solo && !s.is_recording_active {
                                        s.is_recording_active = true;
                                        fire_start = s.callbacks.on_trigger_start.clone();
                                        if is_alt_trigger {
                                            KeyHookDecision::SuppressAltMenuAndPass
                                        } else {
                                            KeyHookDecision::PassThrough
                                        }
                                    } else {
                                        KeyHookDecision::PassThrough
                                    }
                                }
                                TriggerBehavior::HoldToTalk => {
                                    if s.hold_did_fire_start {
                                        s.hold_did_fire_start = false;
                                        s.is_recording_active = false;
                                        fire_stop = s.callbacks.on_trigger_stop.clone();
                                        if is_alt_trigger {
                                            KeyHookDecision::SuppressAltMenuAndPass
                                        } else {
                                            KeyHookDecision::PassThrough
                                        }
                                    } else {
                                        KeyHookDecision::PassThrough
                                    }
                                }
                            }
                        }
                    } else {
                        KeyHookDecision::PassThrough
                    }
                }
            }
            // 4. Non-modifier keys & Combos (`Alt+Space`, `Ctrl+Space`, `CapsLock`, `F2`, `Custom`)
            else {
                let (expected_vk, expected_mods) = match s.trigger_option {
                    TriggerKeyOption::AltSpace => (VK_SPACE, MOD_ALT),
                    TriggerKeyOption::CtrlSpace => (VK_SPACE, MOD_CTRL),
                    TriggerKeyOption::CapsLock => (VK_CAPITAL, 0),
                    TriggerKeyOption::F2 => (VK_F2, 0),
                    TriggerKeyOption::Custom => (s.custom_spec.vk_code, s.custom_spec.modifiers),
                    _ => (0, 0),
                };

                if vk == expected_vk && (is_down && s.mods.bitmask() == expected_mods || !is_down && s.is_trigger_down) {
                    if is_down {
                        if !s.is_trigger_down {
                            s.is_trigger_down = true;
                            match s.behavior {
                                TriggerBehavior::TapToggle => {
                                    if s.is_recording_active {
                                        s.is_recording_active = false;
                                        fire_stop = s.callbacks.on_trigger_stop.clone();
                                    } else {
                                        s.is_recording_active = true;
                                        fire_start = s.callbacks.on_trigger_start.clone();
                                    }
                                }
                                TriggerBehavior::HoldToTalk => {
                                    s.hold_did_fire_start = true;
                                    s.is_recording_active = true;
                                    fire_start = s.callbacks.on_trigger_start.clone();
                                }
                            }
                        }
                    } else {
                        s.is_trigger_down = false;
                        if s.behavior == TriggerBehavior::HoldToTalk && s.hold_did_fire_start {
                            s.hold_did_fire_start = false;
                            s.is_recording_active = false;
                            fire_stop = s.callbacks.on_trigger_stop.clone();
                        }
                    }
                    KeyHookDecision::Swallow
                } else {
                    KeyHookDecision::PassThrough
                }
            }
        };

        if let Some(gen_id) = spawn_delayed_hold_gen {
            std::thread::spawn(move || {
                std::thread::sleep(Duration::from_millis(140));
                let cb = {
                    let mut s = HOOK_STATE.lock();
                    if s.hold_generation == gen_id
                        && s.is_trigger_down
                        && !s.other_key_pressed_during_hold
                        && !s.is_recording_active
                    {
                        s.hold_did_fire_start = true;
                        s.is_recording_active = true;
                        s.callbacks.on_trigger_start.clone()
                    } else {
                        None
                    }
                };
                if let Some(f) = cb {
                    f();
                }
            });
        }

        if let Some((cb, res)) = fire_capture {
            std::thread::spawn(move || cb(res));
        }
        if let Some(f) = fire_prewarm {
            std::thread::spawn(move || f());
        }
        if let Some(f) = fire_start {
            std::thread::spawn(move || f());
        }
        if let Some(f) = fire_stop {
            std::thread::spawn(move || f());
        }
        if let Some(f) = fire_cancel {
            std::thread::spawn(move || f());
        }

        decision
    }
}

#[cfg(target_os = "windows")]
mod win_hook {
    use super::{HotkeyMonitor, KeyHookDecision, SYNTHETIC_EVENT_MARKER};
    use std::sync::atomic::{AtomicBool, Ordering};
    use windows::Win32::Foundation::{HINSTANCE, LPARAM, LRESULT, WPARAM};
    use windows::Win32::UI::Input::KeyboardAndMouse::{
        SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT, KEYEVENTF_KEYUP, VIRTUAL_KEY,
    };
    use windows::Win32::UI::WindowsAndMessaging::{
        CallNextHookEx, DispatchMessageW, GetMessageW, SetWindowsHookExW, TranslateMessage,
        HHOOK, KBDLLHOOKSTRUCT, MSG, WH_KEYBOARD_LL, WM_KEYDOWN, WM_KEYUP, WM_SYSKEYDOWN,
        WM_SYSKEYUP,
    };

    static HOOK_STARTED: AtomicBool = AtomicBool::new(false);

    pub fn start_windows_hook_thread() {
        if HOOK_STARTED.swap(true, Ordering::SeqCst) {
            return;
        }
        std::thread::Builder::new()
            .name("typezero-win32-hotkey".to_string())
            .spawn(|| unsafe {
                let hook = SetWindowsHookExW(
                    WH_KEYBOARD_LL,
                    Some(low_level_keyboard_proc),
                    HINSTANCE::default(),
                    0,
                );
                if hook.is_err() {
                    tracing::error!("Failed to install WH_KEYBOARD_LL hook");
                    return;
                }
                let mut msg = MSG::default();
                while GetMessageW(&mut msg, None, 0, 0).as_bool() {
                    let _ = TranslateMessage(&msg);
                    DispatchMessageW(&msg);
                }
            })
            .ok();
    }

    /// Injects an unassigned virtual key (`0xFF`) so releasing a solo Alt key NEVER activates the foreground app's menu bar!
    unsafe fn send_alt_menu_suppression_mask() {
        let inputs = [
            INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 {
                    ki: KEYBDINPUT {
                        wVk: VIRTUAL_KEY(0xFF),
                        wScan: 0,
                        dwFlags: Default::default(),
                        time: 0,
                        dwExtraInfo: SYNTHETIC_EVENT_MARKER,
                    },
                },
            },
            INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 {
                    ki: KEYBDINPUT {
                        wVk: VIRTUAL_KEY(0xFF),
                        wScan: 0,
                        dwFlags: KEYEVENTF_KEYUP,
                        time: 0,
                        dwExtraInfo: SYNTHETIC_EVENT_MARKER,
                    },
                },
            },
        ];
        let _ = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
    }

    unsafe extern "system" fn low_level_keyboard_proc(
        code: i32,
        wparam: WPARAM,
        lparam: LPARAM,
    ) -> LRESULT {
        if code >= 0 && lparam.0 != 0 {
            let kb = &*(lparam.0 as *const KBDLLHOOKSTRUCT);
            let msg = wparam.0 as u32;
            let is_down = msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;
            let is_up = msg == WM_KEYUP || msg == WM_SYSKEYUP;

            if is_down || is_up {
                match HotkeyMonitor::process_key_event(kb.vkCode, is_down, kb.dwExtraInfo) {
                    KeyHookDecision::Swallow => return LRESULT(1),
                    KeyHookDecision::SuppressAltMenuAndPass => {
                        send_alt_menu_suppression_mask();
                    }
                    KeyHookDecision::PassThrough => {}
                }
            }
        }
        CallNextHookEx(HHOOK::default(), code, wparam, lparam)
    }
}
