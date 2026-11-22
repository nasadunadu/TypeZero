use crate::models::LLMProviderOption;

pub const VOLC_SPEECH_SLOT: &str = "volc_speech_api_key";
pub const OPENAI_ASR_SLOT: &str = "openai_asr_api_key";

pub fn provider_slot(provider: LLMProviderOption) -> &'static str {
    match provider {
        LLMProviderOption::Deepseek => "deepseek_api_key",
        LLMProviderOption::Volcengine => "ark_api_key",
        LLMProviderOption::Dashscope => "dashscope_api_key",
        LLMProviderOption::Openai => "openai_api_key",
        LLMProviderOption::Gemini => "gemini_api_key",
        LLMProviderOption::Anthropic => "anthropic_api_key",
        LLMProviderOption::Custom => "custom_api_key",
    }
}

pub fn provider_slot_for_url(base_url: &str) -> &'static str {
    provider_slot(LLMProviderOption::infer_from_url(base_url))
}

fn target_name(slot: &str) -> String {
    format!("TypeZero/{slot}")
}

#[cfg(target_os = "windows")]
mod platform {
    use super::target_name;
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;
    use windows::core::{PCWSTR, PWSTR};
    use windows::Win32::Security::Credentials::{
        CredDeleteW, CredFree, CredReadW, CredWriteW, CREDENTIALW, CRED_PERSIST_LOCAL_MACHINE,
        CRED_TYPE_GENERIC,
    };

    fn to_wide_null(s: &str) -> Vec<u16> {
        OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
    }

    pub fn save_secret(slot: &str, value: &str) {
        let trimmed = value.trim();
        let target = to_wide_null(&target_name(slot));
        if trimmed.is_empty() {
            unsafe {
                let _ = CredDeleteW(PCWSTR(target.as_ptr()), CRED_TYPE_GENERIC, 0);
            }
            return;
        }

        let user = to_wide_null("TypeZeroUser");
        let mut blob = trimmed.as_bytes().to_vec();
        let cred = CREDENTIALW {
            Flags: Default::default(),
            Type: CRED_TYPE_GENERIC,
            TargetName: PWSTR(target.as_ptr() as *mut u16),
            Comment: PWSTR::null(),
            LastWritten: Default::default(),
            CredentialBlobSize: blob.len() as u32,
            CredentialBlob: blob.as_mut_ptr(),
            Persist: CRED_PERSIST_LOCAL_MACHINE,
            AttributeCount: 0,
            Attributes: std::ptr::null_mut(),
            TargetAlias: PWSTR::null(),
            UserName: PWSTR(user.as_ptr() as *mut u16),
        };

        unsafe {
            let _ = CredWriteW(&cred, 0);
        }
    }

    pub fn load_secret(slot: &str) -> String {
        let target = to_wide_null(&target_name(slot));
        let mut ptr: *mut CREDENTIALW = std::ptr::null_mut();
        unsafe {
            if CredReadW(PCWSTR(target.as_ptr()), CRED_TYPE_GENERIC, 0, &mut ptr).is_ok()
                && !ptr.is_null()
            {
                let cred = &*ptr;
                let out = if !cred.CredentialBlob.is_null() && cred.CredentialBlobSize > 0 {
                    let bytes = std::slice::from_raw_parts(
                        cred.CredentialBlob,
                        cred.CredentialBlobSize as usize,
                    );
                    String::from_utf8_lossy(bytes).trim().to_string()
                } else {
                    String::new()
                };
                CredFree(ptr as *const std::ffi::c_void);
                return out;
            }
        }
        String::new()
    }
}

#[cfg(not(target_os = "windows"))]
mod platform {
    use super::target_name;
    use once_cell::sync::Lazy;
    use parking_lot::RwLock;
    use std::collections::HashMap;

    static STORE: Lazy<RwLock<HashMap<String, String>>> =
        Lazy::new(|| RwLock::new(HashMap::new()));

    pub fn save_secret(slot: &str, value: &str) {
        let key = target_name(slot);
        let trimmed = value.trim();
        let mut guard = STORE.write();
        if trimmed.is_empty() {
            guard.remove(&key);
        } else {
            guard.insert(key, trimmed.to_string());
        }
    }

    pub fn load_secret(slot: &str) -> String {
        let key = target_name(slot);
        STORE.read().get(&key).cloned().unwrap_or_default()
    }
}

pub fn save_api_key(value: &str, provider: LLMProviderOption) {
    platform::save_secret(provider_slot(provider), value);
}

pub fn load_api_key(provider: LLMProviderOption) -> String {
    platform::load_secret(provider_slot(provider))
}

pub fn has_saved_api_key(provider: LLMProviderOption) -> bool {
    !load_api_key(provider).trim().is_empty()
}

pub fn save_volc_speech_api_key(value: &str) {
    platform::save_secret(VOLC_SPEECH_SLOT, value);
}

pub fn load_volc_speech_api_key() -> String {
    platform::load_secret(VOLC_SPEECH_SLOT)
}

pub fn save_openai_asr_api_key(value: &str) {
    platform::save_secret(OPENAI_ASR_SLOT, value);
}

pub fn load_openai_asr_override_key() -> String {
    platform::load_secret(OPENAI_ASR_SLOT)
}

pub fn load_effective_openai_asr_api_key(base_url: &str) -> String {
    let override_key = load_openai_asr_override_key();
    if !override_key.is_empty() {
        return override_key;
    }
    if !base_url.to_lowercase().contains("groq.com") {
        let llm_openai = load_api_key(LLMProviderOption::Openai);
        if !llm_openai.is_empty() {
            return llm_openai;
        }
    }
    String::new()
}
