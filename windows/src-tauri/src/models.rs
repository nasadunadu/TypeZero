use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DictationMode {
    Dictate,
    RewriteSelection,
}

impl DictationMode {
    pub fn display_label(&self) -> &'static str {
        match self {
            Self::Dictate => "口述成稿",
            Self::RewriteSelection => "选中改写",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum PipelinePhase {
    Idle,
    Listening {
        #[serde(rename = "livePreview")]
        live_preview: String,
        mode: DictationMode,
    },
    Polishing {
        #[serde(rename = "rawText")]
        raw_text: String,
    },
    Completed {
        #[serde(rename = "finalText")]
        final_text: String,
        #[serde(rename = "latencyMs")]
        latency_ms: u64,
    },
    SavedToClipboard {
        #[serde(rename = "textPreview")]
        text_preview: String,
    },
    Error {
        message: String,
    },
}

impl Default for PipelinePhase {
    fn default() -> Self {
        Self::Idle
    }
}

/// Windows-native global trigger keys tailored for everyday PC keyboards.
/// Default is `RightAlt` (right thumb, zero conflict with Ctrl+C/V or Chinese IME switching,
/// with Alt menu-bar focus cleanly suppressed by TypeZero's WH_KEYBOARD_LL hook).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TriggerKeyOption {
    RightAlt,
    RightCtrl,
    LeftAlt,
    LeftCtrl,
    RightShift,
    AltSpace,
    CtrlSpace,
    LeftShift,
    CapsLock,
    F2,
    Custom,
}

impl Default for TriggerKeyOption {
    fn default() -> Self {
        Self::RightAlt
    }
}

impl TriggerKeyOption {
    pub const PRESET_MATRIX_ORDER: [Self; 10] = [
        Self::RightAlt,
        Self::RightCtrl,
        Self::LeftAlt,
        Self::LeftCtrl,
        Self::RightShift,
        Self::AltSpace,
        Self::CtrlSpace,
        Self::LeftShift,
        Self::CapsLock,
        Self::F2,
    ];

    pub fn display_name(&self) -> &'static str {
        match self {
            Self::RightAlt => "右侧 Alt（推荐）",
            Self::RightCtrl => "右侧 Ctrl",
            Self::LeftAlt => "左侧 Alt",
            Self::LeftCtrl => "左侧 Ctrl",
            Self::RightShift => "右侧 Shift",
            Self::AltSpace => "Alt + Space",
            Self::CtrlSpace => "Ctrl + Space",
            Self::LeftShift => "左侧 Shift",
            Self::CapsLock => "Caps Lock",
            Self::F2 => "F2 功能键",
            Self::Custom => "自定义快捷键",
        }
    }

    pub fn compact_label(&self) -> &'static str {
        match self {
            Self::RightAlt => "右 Alt",
            Self::RightCtrl => "右 Ctrl",
            Self::LeftAlt => "左 Alt",
            Self::LeftCtrl => "左 Ctrl",
            Self::RightShift => "右 Shift",
            Self::AltSpace => "Alt + Space",
            Self::CtrlSpace => "Ctrl + Space",
            Self::LeftShift => "左 Shift",
            Self::CapsLock => "Caps Lock",
            Self::F2 => "F2",
            Self::Custom => "自定义",
        }
    }

    /// Left-side typing modifiers frequently used in Ctrl+C / Alt+Tab / Shift+A combos.
    /// Protected by 140ms accidental-combo debounce in Hold-to-Talk mode.
    pub fn is_combo_prone_left_modifier(&self) -> bool {
        matches!(self, Self::LeftAlt | Self::LeftCtrl | Self::LeftShift)
    }

    pub fn is_single_modifier_key(&self) -> bool {
        matches!(
            self,
            Self::RightAlt
                | Self::RightCtrl
                | Self::LeftAlt
                | Self::LeftCtrl
                | Self::RightShift
                | Self::LeftShift
        )
    }
}

/// Custom Windows virtual-key shortcut specification.
/// `modifiers` bitmask: 1 = Ctrl, 2 = Alt, 4 = Shift, 8 = Win.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CustomHotkeySpec {
    pub vk_code: u32,
    pub modifiers: u32,
    pub label: String,
}

impl Default for CustomHotkeySpec {
    fn default() -> Self {
        Self {
            vk_code: 0x20,    // VK_SPACE
            modifiers: 1 | 4, // Ctrl + Shift
            label: "Ctrl + Shift + Space".to_string(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ASRProviderOption {
    #[serde(rename = "volcSeedASR")]
    VolcSeedASR,
    #[serde(rename = "openAIWhisper")]
    OpenAIWhisper,
    #[serde(rename = "localSenseVoice")]
    LocalSenseVoice,
}

impl Default for ASRProviderOption {
    fn default() -> Self {
        Self::VolcSeedASR
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LLMProviderOption {
    Deepseek,
    Volcengine,
    Dashscope,
    Openai,
    Gemini,
    Anthropic,
    Custom,
}

impl Default for LLMProviderOption {
    fn default() -> Self {
        Self::Deepseek
    }
}

impl LLMProviderOption {
    pub const ALL: [Self; 7] = [
        Self::Deepseek,
        Self::Volcengine,
        Self::Dashscope,
        Self::Openai,
        Self::Gemini,
        Self::Anthropic,
        Self::Custom,
    ];

    pub fn key_name(&self) -> &'static str {
        match self {
            Self::Deepseek => "deepseek",
            Self::Volcengine => "volcengine",
            Self::Dashscope => "dashscope",
            Self::Openai => "openai",
            Self::Gemini => "gemini",
            Self::Anthropic => "anthropic",
            Self::Custom => "custom",
        }
    }

    pub fn title(&self) -> &'static str {
        match self {
            Self::Deepseek => "DeepSeek 4 Flash",
            Self::Volcengine => "火山方舟 Doubao-Seed",
            Self::Dashscope => "阿里百炼 Qwen-Flash",
            Self::Openai => "OpenAI GPT",
            Self::Gemini => "Google Gemini",
            Self::Anthropic => "Anthropic Claude",
            Self::Custom => "自定义 OpenAI 兼容接口",
        }
    }

    pub fn short_name(&self) -> &'static str {
        match self {
            Self::Deepseek => "DeepSeek",
            Self::Volcengine => "火山方舟",
            Self::Dashscope => "阿里百炼",
            Self::Openai => "OpenAI",
            Self::Gemini => "Gemini",
            Self::Anthropic => "Claude",
            Self::Custom => "自定义接口",
        }
    }

    pub fn default_base_url(&self) -> &'static str {
        match self {
            Self::Deepseek => "https://api.deepseek.com/v1",
            Self::Volcengine => "https://ark.cn-beijing.volces.com/api/v3",
            Self::Dashscope => "https://dashscope.aliyuncs.com/compatible-mode/v1",
            Self::Openai => "https://api.openai.com/v1",
            Self::Gemini => "https://generativelanguage.googleapis.com/v1beta/openai",
            Self::Anthropic => "https://api.anthropic.com/v1",
            Self::Custom => "https://api.siliconflow.cn/v1",
        }
    }

    pub fn default_model_name(&self) -> &'static str {
        match self {
            Self::Deepseek => "deepseek-flash",
            Self::Volcengine => "doubao-seed-2-1-lite-260915",
            Self::Dashscope => "qwen-flash",
            Self::Openai => "gpt-4.1-mini",
            Self::Gemini => "gemini-3.8-flash",
            Self::Anthropic => "claude-haiku-5-5",
            Self::Custom => "deepseek-ai/DeepSeek-V3",
        }
    }

    pub fn infer_from_url(base_url: &str) -> Self {
        let u = base_url.to_lowercase();
        if u.contains("deepseek.com") {
            return Self::Deepseek;
        }
        if u.contains("volces.com") || u.contains("volcengine") {
            return Self::Volcengine;
        }
        if u.contains("aliyuncs.com") {
            return Self::Dashscope;
        }
        if u.contains("openai.com") {
            return Self::Openai;
        }
        if u.contains("generativelanguage.googleapis.com") {
            return Self::Gemini;
        }
        if u.contains("anthropic.com") {
            return Self::Anthropic;
        }
        Self::Custom
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TriggerBehavior {
    TapToggle,
    HoldToTalk,
}

impl Default for TriggerBehavior {
    fn default() -> Self {
        Self::TapToggle
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FormattingStyle {
    Structured,
    LightPolish,
    VerbatimLocal,
}

impl Default for FormattingStyle {
    fn default() -> Self {
        Self::Structured
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LexiconCategory {
    #[serde(rename = "人名/称呼")]
    Person,
    #[serde(rename = "项目/技术")]
    Project,
    #[serde(rename = "标的/商业")]
    Finance,
    #[serde(rename = "纪要/备忘")]
    Memo,
    #[serde(rename = "浏览高频")]
    Browser,
    #[serde(rename = "纠错自学习")]
    AutoLearned,
}

impl Default for LexiconCategory {
    fn default() -> Self {
        Self::Project
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LexiconEntry {
    pub id: String,
    pub term: String,
    #[serde(default)]
    pub aliases: Vec<String>,
    #[serde(default)]
    pub phonetic_key: String,
    #[serde(default)]
    pub category: LexiconCategory,
    #[serde(default = "default_weight")]
    pub weight: i32,
    #[serde(default)]
    pub hit_count: i32,
    #[serde(default = "Utc::now")]
    pub created_at: DateTime<Utc>,
}

fn default_weight() -> i32 {
    5
}

impl LexiconEntry {
    pub fn new(
        term: impl Into<String>,
        aliases: Vec<String>,
        phonetic_key: String,
        category: LexiconCategory,
        weight: i32,
    ) -> Self {
        let clean_term = term.into().trim().to_string();
        let clean_aliases: Vec<String> = aliases
            .into_iter()
            .map(|a| a.trim().to_string())
            .filter(|a| !a.is_empty())
            .collect();
        Self {
            id: Uuid::new_v4().to_string(),
            term: clean_term,
            aliases: clean_aliases,
            phonetic_key,
            category,
            weight,
            hit_count: 0,
            created_at: Utc::now(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DictationRecord {
    pub id: String,
    pub timestamp: DateTime<Utc>,
    pub raw_transcript: String,
    pub polished_text: String,
    pub duration_seconds: f64,
    pub polish_latency_ms: u64,
    pub target_app_name: String,
    pub mode: DictationMode,
    #[serde(default)]
    pub matched_terms: Vec<String>,
}

impl DictationRecord {
    pub fn character_count(&self) -> usize {
        self.polished_text.chars().count()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LLMConfig {
    #[serde(default)]
    pub selected_provider: LLMProviderOption,
    #[serde(default = "default_base_url", rename = "baseURL")]
    pub base_url: String,
    #[serde(default = "default_model_name")]
    pub model_name: String,
    #[serde(default = "default_custom_base_url", rename = "customBaseURL")]
    pub custom_base_url: String,
    #[serde(default)]
    pub provider_models: HashMap<String, String>,
    #[serde(default)]
    pub formatting_style: FormattingStyle,
    #[serde(default)]
    pub asr_provider: ASRProviderOption,
    #[serde(default = "default_openai_asr_url", rename = "openAIASRBaseURL")]
    pub openai_asr_base_url: String,
    #[serde(default = "default_openai_asr_model", rename = "openAIASRModel")]
    pub openai_asr_model: String,
    #[serde(default = "default_true", rename = "enableVolcSeedASR")]
    pub enable_volc_seed_asr: bool,
    #[serde(default)]
    pub enable_live_inline_typing: bool,
    #[serde(default = "default_true")]
    pub enable_fast_bypass_for_short_phrases: bool,
    #[serde(default = "default_true")]
    pub strip_trailing_period_in_chat_apps: bool,
    #[serde(default = "default_true")]
    pub enable_pangu_spacing: bool,
    #[serde(default = "default_true", rename = "enableWhisperAGC")]
    pub enable_whisper_agc: bool,
    #[serde(default = "default_true")]
    pub enable_auto_learn: bool,
    #[serde(default = "default_true")]
    pub enable_auto_mute_during_dictation: bool,
    #[serde(default = "default_speech_locale")]
    pub speech_locale: String,
    #[serde(default)]
    pub speech_locale_explicitly_set: bool,
    #[serde(default)]
    pub trigger_key: TriggerKeyOption,
    #[serde(default)]
    pub custom_hotkey: CustomHotkeySpec,
    #[serde(default)]
    pub trigger_behavior: TriggerBehavior,
    #[serde(default = "default_true")]
    pub minimize_to_tray: bool,
    #[serde(default)]
    pub launch_at_login: bool,
    #[serde(default)]
    pub onboarding_completed: bool,
    #[serde(default)]
    pub use_official_cloud_trial: bool,
}

fn default_true() -> bool {
    true
}
fn default_base_url() -> String {
    LLMProviderOption::Deepseek.default_base_url().to_string()
}
fn default_model_name() -> String {
    LLMProviderOption::Deepseek.default_model_name().to_string()
}
fn default_custom_base_url() -> String {
    LLMProviderOption::Custom.default_base_url().to_string()
}
fn default_openai_asr_url() -> String {
    "https://api.openai.com/v1".to_string()
}
fn default_openai_asr_model() -> String {
    "gpt-4o-mini-transcribe".to_string()
}
fn default_speech_locale() -> String {
    "auto".to_string()
}

impl Default for LLMConfig {
    fn default() -> Self {
        let mut provider_models = HashMap::new();
        provider_models.insert(
            LLMProviderOption::Deepseek.key_name().to_string(),
            default_model_name(),
        );
        Self {
            selected_provider: LLMProviderOption::Deepseek,
            base_url: default_base_url(),
            model_name: default_model_name(),
            custom_base_url: default_custom_base_url(),
            provider_models,
            formatting_style: FormattingStyle::Structured,
            asr_provider: ASRProviderOption::VolcSeedASR,
            openai_asr_base_url: default_openai_asr_url(),
            openai_asr_model: default_openai_asr_model(),
            enable_volc_seed_asr: true,
            enable_live_inline_typing: false,
            enable_fast_bypass_for_short_phrases: true,
            strip_trailing_period_in_chat_apps: true,
            enable_pangu_spacing: true,
            enable_whisper_agc: true,
            enable_auto_learn: true,
            enable_auto_mute_during_dictation: true,
            speech_locale: default_speech_locale(),
            speech_locale_explicitly_set: false,
            trigger_key: TriggerKeyOption::RightAlt,
            custom_hotkey: CustomHotkeySpec::default(),
            trigger_behavior: TriggerBehavior::TapToggle,
            minimize_to_tray: true,
            launch_at_login: false,
            onboarding_completed: false,
            use_official_cloud_trial: false,
        }
    }
}

impl LLMConfig {
    /// Maps `speech_locale` (`"auto"`, `"zh-CN"`, `"en-US"`, etc.) to sherpa-onnx SenseVoice language token.
    pub fn sense_voice_language_code(speech_locale: &str) -> &'static str {
        let trimmed = speech_locale.trim().to_lowercase();
        if trimmed.is_empty() || trimmed == "auto" {
            return "auto";
        }
        if trimmed == "yue" || trimmed == "zh-hk" || trimmed == "zh_hk" {
            return "yue";
        }
        let head = trimmed
            .split(['-', '_'])
            .next()
            .unwrap_or(trimmed.as_str());
        match head {
            "zh" => "zh",
            "en" => "en",
            "ja" => "ja",
            "ko" => "ko",
            "yue" => "yue",
            _ => "auto",
        }
    }

    pub fn select_asr_provider(&mut self, provider: ASRProviderOption) {
        self.asr_provider = provider;
        self.enable_volc_seed_asr = provider == ASRProviderOption::VolcSeedASR;
    }

    pub fn select_provider(&mut self, provider: LLMProviderOption) {
        self.provider_models.insert(
            self.selected_provider.key_name().to_string(),
            self.model_name.clone(),
        );
        if self.selected_provider == LLMProviderOption::Custom && !self.base_url.trim().is_empty() {
            self.custom_base_url = self.base_url.clone();
        }
        self.selected_provider = provider;
        self.base_url = if provider == LLMProviderOption::Custom {
            self.custom_base_url.clone()
        } else {
            provider.default_base_url().to_string()
        };
        let saved = self
            .provider_models
            .get(provider.key_name())
            .map(|s| s.trim().to_string())
            .unwrap_or_default();
        self.model_name = if saved.is_empty() {
            provider.default_model_name().to_string()
        } else {
            saved
        };
    }

    pub fn sync_active_endpoint_edits(&mut self) {
        self.provider_models.insert(
            self.selected_provider.key_name().to_string(),
            self.model_name.clone(),
        );
        if self.selected_provider == LLMProviderOption::Custom && !self.base_url.trim().is_empty() {
            self.custom_base_url = self.base_url.clone();
        }
    }

    pub fn normalize_after_deserialize(&mut self, raw_value: &serde_json::Value) {
        if raw_value.get("asrProvider").is_none() {
            if let Some(flag) = raw_value.get("enableVolcSeedASR").and_then(|v| v.as_bool()) {
                self.asr_provider = if flag {
                    ASRProviderOption::VolcSeedASR
                } else {
                    ASRProviderOption::LocalSenseVoice
                };
            }
        }
        self.enable_volc_seed_asr = self.asr_provider == ASRProviderOption::VolcSeedASR;
        if self.model_name.is_empty() || self.model_name == "deepseek-chat" {
            self.model_name = self.selected_provider.default_model_name().to_string();
        }
        if self.openai_asr_base_url.trim().is_empty() {
            self.openai_asr_base_url = default_openai_asr_url();
        }
        if self.openai_asr_model.trim().is_empty() {
            self.openai_asr_model = default_openai_asr_model();
        }
        let trimmed_locale = self.speech_locale.trim().to_string();
        if !self.speech_locale_explicitly_set
            && (trimmed_locale.is_empty() || trimmed_locale == "zh-CN")
        {
            self.speech_locale = "auto".to_string();
        } else if trimmed_locale.is_empty() {
            self.speech_locale = "auto".to_string();
        } else {
            self.speech_locale = trimmed_locale;
        }
        self.provider_models.insert(
            self.selected_provider.key_name().to_string(),
            self.model_name.clone(),
        );
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppToneProfile {
    InstantMessaging,
    EmailAndFormalDoc,
    AiPromptAndNotes,
    ShellTerminal,
}

impl AppToneProfile {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::InstantMessaging => "即时聊天",
            Self::EmailAndFormalDoc => "邮件与正式文档",
            Self::AiPromptAndNotes => "AI提问与笔记",
            Self::ShellTerminal => "命令行终端",
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct ActiveScreenContext {
    pub app_name: String,
    pub process_name: String,
    pub window_title: String,
    pub selected_text: String,
    pub preceding_text: String,
    pub has_focused_text_input: bool,
}

impl ActiveScreenContext {
    pub fn empty() -> Self {
        Self {
            has_focused_text_input: true,
            ..Default::default()
        }
    }

    pub fn is_strict_shell_terminal(&self) -> bool {
        let lower = format!(
            "{} {}",
            self.process_name.to_lowercase(),
            self.app_name.to_lowercase()
        );
        [
            "windowsterminal",
            "wt.exe",
            "powershell",
            "pwsh",
            "cmd.exe",
            "conhost",
            "mintty",
            "alacritty",
            "wezterm",
            "hyper",
            "warp",
            "ghostty",
            "terminal",
        ]
        .iter()
        .any(|k| lower.contains(k))
    }

    pub fn is_code_or_terminal(&self) -> bool {
        if self.is_strict_shell_terminal() {
            return true;
        }
        let lower = format!(
            "{} {}",
            self.process_name.to_lowercase(),
            self.app_name.to_lowercase()
        );
        [
            "code.exe",
            "vscode",
            "cursor",
            "antigravity",
            "windsurf",
            "idea64",
            "pycharm",
            "webstorm",
            "clion",
            "goland",
            "rider",
            "devenv",
            "zed",
            "sublime_text",
            "notepad++",
        ]
        .iter()
        .any(|k| lower.contains(k))
    }

    pub fn is_instant_messaging(&self) -> bool {
        let lower = format!(
            "{} {} {}",
            self.process_name.to_lowercase(),
            self.app_name.to_lowercase(),
            self.window_title.to_lowercase()
        );
        [
            "wechat",
            "weixin",
            "微信",
            "qq.exe",
            "tim.exe",
            "feishu",
            "lark",
            "飞书",
            "dingtalk",
            "钉钉",
            "wxwork",
            "企业微信",
            "slack",
            "discord",
            "telegram",
            "whatsapp",
            "teams",
        ]
        .iter()
        .any(|k| lower.contains(k))
    }

    pub fn is_email_or_formal_doc(&self) -> bool {
        let lower = format!(
            "{} {} {}",
            self.process_name.to_lowercase(),
            self.app_name.to_lowercase(),
            self.window_title.to_lowercase()
        );
        [
            "outlook",
            "winword",
            "word",
            "wps.exe",
            "foxmail",
            "thunderbird",
            "mail",
            "gmail",
            "docs.google",
        ]
        .iter()
        .any(|k| lower.contains(k))
    }

    pub fn tone_profile(&self) -> AppToneProfile {
        if self.is_strict_shell_terminal() {
            AppToneProfile::ShellTerminal
        } else if self.is_instant_messaging() {
            AppToneProfile::InstantMessaging
        } else if self.is_email_or_formal_doc() {
            AppToneProfile::EmailAndFormalDoc
        } else {
            AppToneProfile::AiPromptAndNotes
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppSnapshot {
    pub phase: PipelinePhase,
    pub config: LLMConfig,
    pub history: Vec<DictationRecord>,
    pub lexicon: Vec<LexiconEntry>,
    pub saved_provider_keys: HashMap<String, bool>,
    pub has_volc_speech_key: bool,
    pub has_openai_asr_override_key: bool,
    pub has_effective_openai_asr_key: bool,
    pub is_openai_asr_reusing_llm_key: bool,
    pub mic_available: bool,
    pub sense_voice_loaded: bool,
    pub sense_voice_full_fp32: bool,
    pub sherpa_runtime_available: bool,
    pub status_banner: String,
    pub sandbox_text: String,
    pub is_recording_shortcut: bool,
    pub is_downloading_offline_model: bool,
    pub offline_download_progress: f64,
    pub offline_download_status_text: String,
    pub active_trigger_display_name: String,
    pub active_trigger_compact_label: String,
    pub stats: DashboardStats,
    pub cloud_user: Option<crate::core::cloud::CloudUserProfile>,
    pub is_official_cloud_trial_active: bool,
    pub voucher_profile: Option<crate::core::cloud::CloudVoucherProfile>,
    pub is_using_doubao_voucher: bool,
    pub current_version: String,
    pub available_update: Option<crate::core::updater::AppVersionManifest>,
    pub is_checking_update: bool,
    pub is_installing_update: bool,
    pub update_download_progress: f64,
    pub update_status_text: String,
    pub skipped_update_version: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DashboardStats {
    pub total_characters: usize,
    pub time_saved_minutes: u64,
    pub average_cpm: u64,
    pub average_latency_ms: u64,
    pub active_days: usize,
    pub daily_counts: HashMap<String, usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PillTelemetry {
    pub phase: PipelinePhase,
    pub audio_level: f32,
    pub recognized_count: usize,
    pub enable_live_inline_typing: bool,
}
