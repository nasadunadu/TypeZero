use crate::audio::dsp::{
    boost_quiet_speech_agc, resample_float_to_16khz_int16, AudioLevelBus,
};
use crate::audio::openai_asr::OpenAITranscriptionClient;
use crate::audio::volc_asr::VolcSeedASRClient;
use crate::core::credentials;
use crate::core::lexicon::{PersonalLexiconStore, PhoneticIndexer};
use crate::core::polish::PolishEngine;
use crate::models::{
    ASRProviderOption, ActiveScreenContext, AppToneProfile, FormattingStyle, LLMConfig,
    LLMProviderOption, LexiconCategory, LexiconEntry, TriggerBehavior, TriggerKeyOption,
};
use crate::system::hotkey::{
    format_combo_label, matches_single_modifier_press, HotkeyMonitor, KeyHookDecision,
    ModifierSnapshot, MOD_ALT, MOD_CTRL, MOD_SHIFT, SYNTHETIC_EVENT_MARKER, VK_LCONTROL, VK_LMENU,
    VK_LSHIFT, VK_RCONTROL, VK_RMENU, VK_RSHIFT, VK_SPACE,
};
use crate::system::injector::ContextInjector;
use std::f64::consts::PI;

#[test]
fn test_fuzzy_accent_phonetic_skeleton() {
    assert_eq!(
        PhoneticIndexer::fuzzy_skeleton("清晨"),
        PhoneticIndexer::fuzzy_skeleton("亲臣")
    );
    assert_eq!(
        PhoneticIndexer::fuzzy_skeleton("实验"),
        PhoneticIndexer::fuzzy_skeleton("思言")
    );
    assert_eq!(
        PhoneticIndexer::fuzzy_skeleton("张伟"),
        PhoneticIndexer::fuzzy_skeleton("赞尾")
    );
    assert_eq!(
        PhoneticIndexer::fuzzy_skeleton("林峰"),
        PhoneticIndexer::fuzzy_skeleton("宁风")
    );
}

#[test]
fn test_lexicon_smart_rename_merge_and_recall() {
    let tmp = std::env::temp_dir().join(format!("tz_win_test_{}.json", uuid::Uuid::new_v4()));
    let store = PersonalLexiconStore::new(Some(tmp.clone()));
    store.upsert("张伟", vec!["张威".into()], LexiconCategory::Person, 8);
    store.upsert("章玮", vec!["章维".into()], LexiconCategory::Memo, 7);

    let wrong = store
        .entries()
        .into_iter()
        .find(|e| e.term == "章玮")
        .expect("should find 章玮");
    store.update_entry(
        &wrong.id,
        "张伟",
        wrong.aliases,
        LexiconCategory::Person,
        9,
    );

    let merged: Vec<_> = store
        .entries()
        .into_iter()
        .filter(|e| e.term == "张伟")
        .collect();
    assert_eq!(merged.len(), 1);
    assert!(merged[0].aliases.contains(&"章玮".to_string()));
    assert!(merged[0].aliases.contains(&"章维".to_string()));

    let recalled = store.recall_relevant_terms("这件事交给章维跟进一下", "", 10);
    assert!(recalled.iter().any(|e| e.term == "张伟"));

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_duplicate_list_marker_prevention() {
    let clean = "现在我们做几件事：\n1. 检查代码质量；\n2. 准备 GitHub 分支；\n3. 写现状日志。";
    let buggy =
        "现在我们做几件事：\n1. 检查代码质量；\n2. 2. 准备 GitHub 分支；\n3. 3. 写现状日志。";
    assert_eq!(
        ContextInjector::extract_leading_list_marker("2. 准备分支").as_deref(),
        Some("2. ")
    );
    assert_eq!(
        ContextInjector::extract_leading_list_marker("- 无序要点").as_deref(),
        Some("- ")
    );
    assert!(ContextInjector::contains_duplicated_list_marker(buggy, clean));
    assert_eq!(ContextInjector::collapse_duplicated_list_markers(buggy), clean);
}

#[test]
fn test_pangu_spacing_punctuation_and_post_formatting_rules() {
    let im_ctx = ActiveScreenContext {
        app_name: "WeChat".into(),
        process_name: "WeChat.exe".into(),
        window_title: "微信".into(),
        has_focused_text_input: true,
        ..Default::default()
    };
    assert_eq!(im_ctx.tone_profile(), AppToneProfile::InstantMessaging);

    let formatted = PolishEngine::apply_post_formatting_rules(
        "使用DeepSeek提升百分之35速度。",
        &im_ctx,
        &LLMConfig::default(),
    );
    assert_eq!(formatted, "使用 DeepSeek 提升 35% 速度");

    let norm_q = PolishEngine::apply_post_formatting_rules(
        "今天发财报会不会一样? 太好了!",
        &im_ctx,
        &LLMConfig::default(),
    );
    assert_eq!(norm_q, "今天发财报会不会一样？ 太好了！");

    let no_blank = PolishEngine::apply_post_formatting_rules(
        "第一段说明。\n\n第二段继续。",
        &ActiveScreenContext::empty(),
        &LLMConfig::default(),
    );
    assert_eq!(no_blank, "第一段说明。\n第二段继续。");

    let stripped_md = PolishEngine::apply_post_formatting_rules(
        "### 核心结论\n这是**重点内容**，请确认。",
        &im_ctx,
        &LLMConfig::default(),
    );
    assert_eq!(stripped_md, "核心结论\n这是重点内容，请确认。");
}

#[test]
fn test_windows_app_tone_matrix() {
    let wt = ActiveScreenContext {
        app_name: "WindowsTerminal".into(),
        process_name: "WindowsTerminal.exe".into(),
        ..Default::default()
    };
    assert_eq!(wt.tone_profile(), AppToneProfile::ShellTerminal);
    assert!(wt.is_code_or_terminal());

    let vscode = ActiveScreenContext {
        app_name: "Code".into(),
        process_name: "Code.exe".into(),
        ..Default::default()
    };
    assert!(vscode.is_code_or_terminal());

    let outlook = ActiveScreenContext {
        app_name: "OUTLOOK".into(),
        process_name: "OUTLOOK.EXE".into(),
        ..Default::default()
    };
    assert_eq!(outlook.tone_profile(), AppToneProfile::EmailAndFormalDoc);

    let feishu = ActiveScreenContext {
        app_name: "Feishu".into(),
        process_name: "Feishu.exe".into(),
        ..Default::default()
    };
    assert_eq!(feishu.tone_profile(), AppToneProfile::InstantMessaging);
}

#[test]
fn test_auto_learn_filter_and_multi_paragraph_and_selection_rewrite() {
    assert!(PersonalLexiconStore::is_common_or_disposable_auto_learn_term("v0.5.0"));
    assert!(PersonalLexiconStore::is_common_or_disposable_auto_learn_term("今天"));
    assert!(!PersonalLexiconStore::is_common_or_disposable_auto_learn_term("星河"));
    assert!(!PersonalLexiconStore::is_common_or_disposable_auto_learn_term("DeepSeek"));

    let tmp = std::env::temp_dir().join(format!("tz_win_learn_{}.json", uuid::Uuid::new_v4()));
    let store = PersonalLexiconStore::new(Some(tmp.clone()));

    let multi_orig = "第一段背景说明。\n\n第二段我们让星合跟进一下海外投放。\n\n第三段收尾。";
    let multi_edited = "第一段背景说明。\n\n第二段我们让星河跟进一下海外投放。\n\n第三段收尾。";
    let learned = store.learn_from_manual_edit_if_applicable(multi_orig, multi_edited);
    assert_eq!(learned, Some(("星合".to_string(), "星河".to_string())));

    let taught = store.learn_from_selection_rewrite("Su", "SEO");
    assert_eq!(taught, Some(("Su".to_string(), "SEO".to_string())));

    let hot = store.top_acoustic_contextual_strings("正在对比 Semrush 与 GitHub 增长数据", 15);
    assert!(hot.contains(&"Semrush".to_string()));
    assert!(hot.contains(&"GitHub".to_string()));

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_word_boundary_acronym_glide_replacement() {
    let seo = LexiconEntry::new(
        "SEO",
        vec!["Su".into(), "s Su".into(), "艾斯伊欧".into()],
        "seo".into(),
        LexiconCategory::Project,
        10,
    );
    let fixed = PolishEngine::apply_instant_local_dictionary(
        "招这个 Su 的人做日本的 s Su，让 Summary 看一下 Supabase",
        &[seo],
        &ActiveScreenContext::empty(),
        &LLMConfig::default(),
        false,
    );
    assert_eq!(
        fixed,
        "招这个 SEO 的人做日本的 SEO，让 Summary 看一下 Supabase"
    );
}

#[test]
fn test_short_phrase_zero_ms_bypass_and_capsule_counter() {
    assert!(!LLMConfig::default().enable_live_inline_typing);
    assert!(PolishEngine::can_bypass_cloud_polish(
        "好的，那你动手把这3点改上吧。",
        &[],
        FormattingStyle::Structured,
        true,
        true
    ));
    assert!(!PolishEngine::can_bypass_cloud_polish(
        "嗯，那个帮我看一下第一点不对改成第二点。",
        &[],
        FormattingStyle::Structured,
        true,
        true
    ));

    AudioLevelBus::shared().reset();
    AudioLevelBus::shared().push_recognized_count(14);
    let (smooth, target) = AudioLevelBus::shared().sample_recognized_symbol_progress();
    assert_eq!(target, 14);
    assert!(smooth > 0.0);
    AudioLevelBus::shared().reset();
}

#[test]
fn test_windows_hotkeys_left_right_isolation_and_alt_menu_suppression() {
    assert_eq!(TriggerKeyOption::PRESET_MATRIX_ORDER.len(), 10);
    assert_eq!(TriggerKeyOption::default(), TriggerKeyOption::RightAlt);

    let ralt_mods = ModifierSnapshot {
        ralt: true,
        ..Default::default()
    };
    let lalt_mods = ModifierSnapshot {
        lalt: true,
        ..Default::default()
    };
    assert!(matches_single_modifier_press(
        TriggerKeyOption::RightAlt,
        VK_RMENU,
        ralt_mods
    ));
    assert!(!matches_single_modifier_press(
        TriggerKeyOption::LeftAlt,
        VK_RMENU,
        ralt_mods
    ));
    assert!(matches_single_modifier_press(
        TriggerKeyOption::LeftAlt,
        VK_LMENU,
        lalt_mods
    ));
    assert!(!matches_single_modifier_press(
        TriggerKeyOption::RightAlt,
        VK_LMENU,
        lalt_mods
    ));

    let lctrl = ModifierSnapshot {
        lctrl: true,
        ..Default::default()
    };
    let rshift = ModifierSnapshot {
        rshift: true,
        ..Default::default()
    };
    let rctrl = ModifierSnapshot {
        rctrl: true,
        ..Default::default()
    };
    let lshift = ModifierSnapshot {
        lshift: true,
        ..Default::default()
    };
    assert!(matches_single_modifier_press(
        TriggerKeyOption::LeftCtrl,
        VK_LCONTROL,
        lctrl
    ));
    assert!(matches_single_modifier_press(
        TriggerKeyOption::RightShift,
        VK_RSHIFT,
        rshift
    ));
    assert!(matches_single_modifier_press(
        TriggerKeyOption::RightCtrl,
        VK_RCONTROL,
        rctrl
    ));
    assert!(matches_single_modifier_press(
        TriggerKeyOption::LeftShift,
        VK_LSHIFT,
        lshift
    ));

    assert_eq!(
        format_combo_label(VK_SPACE, MOD_CTRL | MOD_ALT | MOD_SHIFT),
        "Ctrl + Alt + Shift + Space"
    );

    // Synthetic events from TypeZero itself must always pass through untouched
    assert_eq!(
        HotkeyMonitor::process_key_event(VK_RMENU, true, SYNTHETIC_EVENT_MARKER),
        KeyHookDecision::PassThrough
    );

    // Bare RightAlt tap in TapToggle mode must suppress Windows menu-bar focus on release!
    HotkeyMonitor::configure(
        TriggerKeyOption::RightAlt,
        Default::default(),
        TriggerBehavior::TapToggle,
    );
    HotkeyMonitor::sync_recording_state(false);
    assert_eq!(
        HotkeyMonitor::process_key_event(VK_RMENU, true, 0),
        KeyHookDecision::PassThrough
    );
    assert_eq!(
        HotkeyMonitor::process_key_event(VK_RMENU, false, 0),
        KeyHookDecision::SuppressAltMenuAndPass
    );
    HotkeyMonitor::sync_recording_state(false);
}

#[test]
fn test_provider_switching_slots_and_payloads() {
    assert_eq!(
        credentials::provider_slot_for_url("https://api.deepseek.com/v1"),
        "deepseek_api_key"
    );
    assert_eq!(
        credentials::provider_slot_for_url("https://ark.cn-beijing.volces.com/api/v3"),
        "ark_api_key"
    );
    assert_eq!(
        credentials::provider_slot(LLMProviderOption::Dashscope),
        "dashscope_api_key"
    );
    assert_eq!(
        credentials::provider_slot(LLMProviderOption::Openai),
        "openai_api_key"
    );
    assert_eq!(
        credentials::provider_slot(LLMProviderOption::Gemini),
        "gemini_api_key"
    );
    assert_eq!(
        credentials::provider_slot(LLMProviderOption::Anthropic),
        "anthropic_api_key"
    );
    assert_eq!(
        credentials::provider_slot(LLMProviderOption::Custom),
        "custom_api_key"
    );

    let mut cfg = LLMConfig::default();
    cfg.select_provider(LLMProviderOption::Volcengine);
    cfg.model_name = "ep-20260915-fast".into();
    cfg.select_provider(LLMProviderOption::Custom);
    cfg.base_url = "http://localhost:11434/v1".into();
    cfg.model_name = "qwen2.5:7b".into();
    cfg.select_provider(LLMProviderOption::Deepseek);
    cfg.select_provider(LLMProviderOption::Volcengine);
    assert_eq!(cfg.model_name, "ep-20260915-fast");
    cfg.select_provider(LLMProviderOption::Custom);
    assert_eq!(cfg.base_url, "http://localhost:11434/v1");
    assert!(PolishEngine::is_keyless_local_endpoint(&cfg.base_url));

    assert_eq!(
        LLMProviderOption::infer_from_url("https://api.openai.com/v1"),
        LLMProviderOption::Openai
    );
    assert_eq!(
        LLMProviderOption::infer_from_url("https://generativelanguage.googleapis.com/v1beta/openai"),
        LLMProviderOption::Gemini
    );
    assert_eq!(
        LLMProviderOption::infer_from_url("https://api.anthropic.com/v1"),
        LLMProviderOption::Anthropic
    );
    assert!(PolishEngine::is_anthropic_endpoint("https://api.anthropic.com/v1"));
    assert_eq!(
        PolishEngine::normalize_anthropic_messages_endpoint("https://api.anthropic.com/v1"),
        "https://api.anthropic.com/v1/messages"
    );

    let oai_gpt5 = PolishEngine::build_openai_compatible_payload(
        "https://api.openai.com/v1/chat/completions",
        "gpt-5-mini",
        "sys",
        "hi",
        200,
        true,
    );
    assert_eq!(oai_gpt5["max_completion_tokens"], 200);
    assert!(oai_gpt5.get("max_tokens").is_none());
    assert_eq!(oai_gpt5["reasoning_effort"], "minimal");

    let gemini_25 = PolishEngine::build_openai_compatible_payload(
        "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        "gemini-2.5-flash",
        "sys",
        "hi",
        200,
        true,
    );
    assert_eq!(gemini_25["reasoning_effort"], "none");

    let gemini_38 = PolishEngine::build_openai_compatible_payload(
        "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        "gemini-3.8-flash",
        "sys",
        "hi",
        200,
        true,
    );
    assert_eq!(gemini_38["reasoning_effort"], "minimal");

    let ds = PolishEngine::build_openai_compatible_payload(
        "https://api.deepseek.com/v1/chat/completions",
        "deepseek-flash",
        "sys",
        "hi",
        200,
        true,
    );
    assert_eq!(ds["thinking"]["type"], "disabled");
}

#[test]
fn test_dsp_resampler_agc_wav_and_seed_asr_framing() {
    // 1. 48kHz -> 16kHz windowed-sinc resampler
    let wave48k: Vec<f32> = (0..4800)
        .map(|i| ((2.0 * PI * 1000.0 * (i as f64) / 48_000.0).sin() * 0.45) as f32)
        .collect();
    let resampled = resample_float_to_16khz_int16(&wave48k, 48_000.0);
    let max_amp = resampled.iter().map(|&s| (s as i32).abs()).max().unwrap_or(0);
    assert!((1580..=1620).contains(&resampled.len()));
    assert!(max_amp > 10_000);

    // 2. 25dB Whisper Boost AGC amplifies quiet speech without clipping
    let quiet: Vec<f32> = (0..1600)
        .map(|i| ((2.0 * PI * 440.0 * (i as f64) / 16_000.0).sin() * 0.01) as f32)
        .collect();
    let boosted = boost_quiet_speech_agc(&quiet);
    let peak_boosted = boosted.iter().map(|s| s.abs()).fold(0.0f32, f32::max);
    assert!(peak_boosted > 0.05 && peak_boosted < 1.0);

    // 3. OpenAI / Groq endpoint normalization, 44-byte WAV header, prompt hints
    assert_eq!(
        OpenAITranscriptionClient::normalize_transcription_endpoint("https://api.openai.com/v1"),
        "https://api.openai.com/v1/audio/transcriptions"
    );
    assert_eq!(
        OpenAITranscriptionClient::normalize_transcription_endpoint(
            "https://api.groq.com/openai/v1/"
        ),
        "https://api.groq.com/openai/v1/audio/transcriptions"
    );
    assert_eq!(
        OpenAITranscriptionClient::normalize_transcription_endpoint("https://relay.example.com"),
        "https://relay.example.com/v1/audio/transcriptions"
    );
    assert!(OpenAITranscriptionClient::is_groq_endpoint(
        "https://api.groq.com/openai/v1"
    ));

    let sample_pcm = [0i16, 1000, -1000, 32000, -32000, 500];
    let wav = OpenAITranscriptionClient::encode_pcm16_to_wav(&sample_pcm, 16_000);
    assert_eq!(wav.len(), 44 + sample_pcm.len() * 2);
    assert_eq!(&wav[0..4], b"RIFF");
    assert_eq!(&wav[8..12], b"WAVE");
    assert_eq!(&wav[36..40], b"data");
    assert_eq!(
        u32::from_le_bytes([wav[24], wav[25], wav[26], wav[27]]),
        16_000
    );
    assert_eq!(
        u32::from_le_bytes([wav[40], wav[41], wav[42], wav[43]]),
        (sample_pcm.len() * 2) as u32
    );

    let hint = OpenAITranscriptionClient::build_prompt_hint(
        &[
            "TypeZero".into(),
            "typezero".into(),
            "DeepSeek".into(),
            "Tauri".into(),
            "A".into(),
            "Groq".into(),
        ],
        24,
    );
    assert_eq!(hint, "TypeZero, DeepSeek");
    assert_eq!(
        OpenAITranscriptionClient::iso_language_code("zh-CN").as_deref(),
        Some("zh")
    );
    assert_eq!(
        OpenAITranscriptionClient::iso_language_code("en-US").as_deref(),
        Some("en")
    );

    // 4. Seed-ASR 2.0 Binary Frame + Gzip round-trip
    let payload = b"{\"hello\":\"typezero\"}";
    let gz = VolcSeedASRClient::gzip_compress(payload);
    assert_eq!(VolcSeedASRClient::gzip_decompress(&gz), payload);
    let frame = VolcSeedASRClient::make_binary_frame(0x1, 0x0, 0x1, 0x1, &gz);
    assert_eq!(frame[0], 0x11);
    assert_eq!(frame[1], 0x10);
    assert_eq!(frame[2], 0x11);
    assert_eq!(
        u32::from_be_bytes([frame[4], frame[5], frame[6], frame[7]]) as usize,
        gz.len()
    );

    // 5. Legacy config migration
    let legacy_raw: serde_json::Value = serde_json::from_str(
        r#"{"enableVolcSeedASR":false,"baseURL":"https://api.openai.com/v1","modelName":"gpt-4.1-mini"}"#,
    )
    .unwrap();
    let mut migrated: LLMConfig = serde_json::from_value(legacy_raw.clone()).unwrap();
    migrated.normalize_after_deserialize(&legacy_raw);
    assert_eq!(migrated.asr_provider, ASRProviderOption::LocalSenseVoice);
    assert!(!migrated.enable_volc_seed_asr);
}
