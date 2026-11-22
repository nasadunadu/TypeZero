use parking_lot::Mutex;

/// Automatically mutes Windows system audio output during active voice dictation and restores it on stop.
/// Strictly respects the user's pre-existing mute state (never unmutes if user was already muted!).
pub struct SystemAudioDucker {
    did_mute_by_us: Mutex<bool>,
}

impl Default for SystemAudioDucker {
    fn default() -> Self {
        Self::new()
    }
}

impl SystemAudioDucker {
    pub fn new() -> Self {
        Self {
            did_mute_by_us: Mutex::new(false),
        }
    }

    pub fn mute_if_needed(&self) {
        let mut guard = self.did_mute_by_us.lock();
        if *guard {
            return;
        }
        if platform::get_mute_state() == Some(false) && platform::set_mute_state(true) {
            *guard = true;
        }
    }

    pub fn restore_if_needed(&self) {
        let mut guard = self.did_mute_by_us.lock();
        if !*guard {
            return;
        }
        *guard = false;
        let _ = platform::set_mute_state(false);
    }
}

impl Drop for SystemAudioDucker {
    fn drop(&mut self) {
        self.restore_if_needed();
    }
}

#[cfg(target_os = "windows")]
mod platform {
    use windows::Win32::Media::Audio::Endpoints::IAudioEndpointVolume;
    use windows::Win32::Media::Audio::{
        eConsole, eRender, IMMDeviceEnumerator, MMDeviceEnumerator,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoUninitialize, CLSCTX_ALL, COINIT_MULTITHREADED,
    };

    fn with_endpoint_volume<T, F: FnOnce(&IAudioEndpointVolume) -> Option<T>>(f: F) -> Option<T> {
        unsafe {
            let hr = CoInitializeEx(None, COINIT_MULTITHREADED);
            let should_uninit = hr.is_ok();
            let result = (|| {
                let enumerator: IMMDeviceEnumerator =
                    CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL).ok()?;
                let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole).ok()?;
                let volume: IAudioEndpointVolume = device.Activate(CLSCTX_ALL, None).ok()?;
                f(&volume)
            })();
            if should_uninit {
                CoUninitialize();
            }
            result
        }
    }

    pub fn get_mute_state() -> Option<bool> {
        with_endpoint_volume(|vol| unsafe { vol.GetMute().ok().map(|b| b.as_bool()) })
    }

    pub fn set_mute_state(muted: bool) -> bool {
        with_endpoint_volume(|vol| unsafe {
            vol.SetMute(muted, std::ptr::null()).ok().map(|_| true)
        })
        .unwrap_or(false)
    }
}

#[cfg(not(target_os = "windows"))]
mod platform {
    pub fn get_mute_state() -> Option<bool> {
        None
    }
    pub fn set_mute_state(_muted: bool) -> bool {
        false
    }
}
