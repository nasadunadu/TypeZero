/// Windows Registry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`) auto-start helper
/// + one-click opener for Windows Microphone Privacy Settings (`ms-settings:privacy-microphone`).

#[cfg(target_os = "windows")]
pub fn set_launch_at_login(enabled: bool) -> Result<(), String> {
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;
    use windows::core::PCWSTR;
    use windows::Win32::System::Registry::{
        RegCloseKey, RegDeleteValueW, RegOpenKeyExW, RegSetValueExW, HKEY, HKEY_CURRENT_USER,
        KEY_SET_VALUE, REG_SZ,
    };

    fn wide(s: &str) -> Vec<u16> {
        OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
    }

    let subkey = wide(r"Software\Microsoft\Windows\CurrentVersion\Run");
    let value_name = wide("TypeZero");

    unsafe {
        let mut hkey = HKEY::default();
        RegOpenKeyExW(
            HKEY_CURRENT_USER,
            PCWSTR(subkey.as_ptr()),
            0,
            KEY_SET_VALUE,
            &mut hkey,
        )
        .ok()
        .map_err(|e| format!("无法打开开机自启注册表项：{e}"))?;

        let res = if enabled {
            let exe = std::env::current_exe()
                .map_err(|e| format!("无法获取程序路径：{e}"))?;
            let cmd = format!("\"{}\" --minimized", exe.display());
            let wide_cmd = wide(&cmd);
            let bytes = std::slice::from_raw_parts(
                wide_cmd.as_ptr() as *const u8,
                wide_cmd.len() * 2,
            );
            RegSetValueExW(hkey, PCWSTR(value_name.as_ptr()), 0, REG_SZ, Some(bytes))
                .ok()
                .map_err(|e| format!("写入开机自启失败：{e}"))
        } else {
            let _ = RegDeleteValueW(hkey, PCWSTR(value_name.as_ptr()));
            Ok(())
        };

        let _ = RegCloseKey(hkey);
        res
    }
}

#[cfg(not(target_os = "windows"))]
pub fn set_launch_at_login(_enabled: bool) -> Result<(), String> {
    Ok(())
}

#[cfg(target_os = "windows")]
pub fn open_microphone_privacy_settings() {
    let _ = std::process::Command::new("cmd")
        .args(["/C", "start", "ms-settings:privacy-microphone"])
        .spawn();
}

#[cfg(not(target_os = "windows"))]
pub fn open_microphone_privacy_settings() {}
