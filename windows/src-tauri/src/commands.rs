use crate::core::state::AppState;
use crate::models::{
    ASRProviderOption, AppSnapshot, FormattingStyle, LLMConfig, LLMProviderOption, LexiconCategory,
    TriggerBehavior, TriggerKeyOption,
};
use crate::system::autostart;
use crate::system::injector::ContextInjector;
use std::path::PathBuf;
use std::sync::Arc;
use tauri::State;

#[tauri::command]
pub fn get_app_snapshot(state: State<'_, Arc<AppState>>) -> AppSnapshot {
    state.snapshot()
}

#[tauri::command]
pub fn clear_status_banner(state: State<'_, Arc<AppState>>) {
    state.set_status_banner("");
}

#[tauri::command]
pub fn set_sandbox_text(text: String, state: State<'_, Arc<AppState>>) {
    state.set_sandbox_text(text);
}

#[tauri::command]
pub fn start_sandbox_dictation(state: State<'_, Arc<AppState>>) {
    state.inner().begin_dictation_session(true);
}

#[tauri::command]
pub async fn stop_dictation(state: State<'_, Arc<AppState>>) -> Result<(), String> {
    state.inner().finish_dictation_session().await;
    Ok(())
}

#[tauri::command]
pub fn cancel_dictation(state: State<'_, Arc<AppState>>) {
    state.cancel_dictation_session();
}

#[tauri::command]
pub fn copy_text_to_clipboard(text: String) {
    ContextInjector::save_to_safety_clipboard(&text);
}

#[tauri::command]
pub fn update_preferences(config: LLMConfig, state: State<'_, Arc<AppState>>) {
    state.update_config(|c| *c = config);
}

#[tauri::command]
pub fn set_trigger_key(key: TriggerKeyOption, state: State<'_, Arc<AppState>>) {
    state.apply_trigger_key(key);
}

#[tauri::command]
pub fn set_trigger_behavior(behavior: TriggerBehavior, state: State<'_, Arc<AppState>>) {
    state.apply_trigger_behavior(behavior);
}

#[tauri::command]
pub fn set_formatting_style(style: FormattingStyle, state: State<'_, Arc<AppState>>) {
    state.apply_formatting_style(style);
}

#[tauri::command]
pub fn start_shortcut_capture(state: State<'_, Arc<AppState>>) {
    state.inner().start_shortcut_capture();
}

#[tauri::command]
pub fn cancel_shortcut_capture(state: State<'_, Arc<AppState>>) {
    state.cancel_shortcut_capture();
}

#[tauri::command]
pub fn save_volc_speech_key(api_key: String, state: State<'_, Arc<AppState>>) {
    state.save_volc_speech_key(&api_key);
}

#[tauri::command]
pub fn save_openai_asr_config(
    base_url: String,
    model: String,
    api_key: String,
    state: State<'_, Arc<AppState>>,
) {
    state.save_openai_asr_config(&base_url, &model, &api_key);
}

#[tauri::command]
pub async fn probe_seed_asr(
    api_key: String,
    state: State<'_, Arc<AppState>>,
) -> Result<String, String> {
    state.probe_seed_asr(&api_key).await
}

#[tauri::command]
pub async fn probe_openai_asr(
    base_url: String,
    model: String,
    api_key: String,
    state: State<'_, Arc<AppState>>,
) -> Result<String, String> {
    state.probe_openai_asr(&base_url, &model, &api_key).await
}

#[tauri::command]
pub async fn activate_asr_provider(
    provider: ASRProviderOption,
    api_key: String,
    openai_url: String,
    openai_model: String,
    state: State<'_, Arc<AppState>>,
) -> Result<String, String> {
    state
        .activate_asr_provider(provider, &api_key, &openai_url, &openai_model)
        .await
}

#[tauri::command]
pub fn save_llm_provider_draft(
    provider: LLMProviderOption,
    base_url: String,
    model_name: String,
    api_key: String,
    state: State<'_, Arc<AppState>>,
) {
    state.save_llm_provider_draft(provider, &base_url, &model_name, &api_key);
}

#[tauri::command]
pub async fn benchmark_llm_provider(
    provider: LLMProviderOption,
    base_url: String,
    model_name: String,
    api_key: String,
    state: State<'_, Arc<AppState>>,
) -> Result<String, String> {
    state
        .benchmark_llm_provider(provider, &base_url, &model_name, &api_key)
        .await
}

#[tauri::command]
pub async fn activate_llm_provider(
    provider: LLMProviderOption,
    base_url: String,
    model_name: String,
    api_key: String,
    state: State<'_, Arc<AppState>>,
) -> Result<String, String> {
    state
        .activate_llm_provider(provider, &base_url, &model_name, &api_key)
        .await
}

#[tauri::command]
pub fn upsert_lexicon_entry(
    term: String,
    aliases: Vec<String>,
    category: LexiconCategory,
    weight: i32,
    state: State<'_, Arc<AppState>>,
) {
    state.upsert_lexicon(&term, aliases, category, weight);
}

#[tauri::command]
pub fn update_lexicon_entry(
    id: String,
    new_term: String,
    new_aliases: Vec<String>,
    new_category: LexiconCategory,
    new_weight: i32,
    state: State<'_, Arc<AppState>>,
) {
    state.update_lexicon_entry(&id, &new_term, new_aliases, new_category, new_weight);
}

#[tauri::command]
pub fn remove_lexicon_entry(id: String, state: State<'_, Arc<AppState>>) {
    state.remove_lexicon_entry(&id);
}

#[tauri::command]
pub fn remove_lexicon_batch(ids: Vec<String>, state: State<'_, Arc<AppState>>) {
    state.remove_lexicon_batch(ids);
}

#[tauri::command]
pub fn bulk_import_lexicon_lines(
    raw_text: String,
    category: LexiconCategory,
    state: State<'_, Arc<AppState>>,
) -> usize {
    let items: Vec<(String, Vec<String>, LexiconCategory)> = raw_text
        .split(['\n', ',', '，', '、', ';', '；'])
        .map(str::trim)
        .filter(|s| s.chars().count() >= 2)
        .map(|s| (s.to_string(), Vec::new(), category))
        .collect();
    let count = state.lexicon.bulk_upsert(items);
    state.set_status_banner(format!("直接批量导入 {count} 个词条"));
    count
}

#[tauri::command]
pub async fn distill_pasted_corpus(
    raw_corpus: String,
    state: State<'_, Arc<AppState>>,
) -> Result<usize, String> {
    state.distill_pasted_corpus(&raw_corpus).await
}

#[tauri::command]
pub fn import_lexicon_from_folder(
    folder_path: String,
    state: State<'_, Arc<AppState>>,
) -> usize {
    let added = state
        .lexicon
        .import_from_markdown_folder(&PathBuf::from(folder_path), 120);
    state.set_status_banner(format!("扫描文件夹完成：新增 {added} 个高频词条"));
    added
}

#[tauri::command]
pub fn import_lexicon_from_browsers(state: State<'_, Arc<AppState>>) -> usize {
    let added = state.lexicon.import_from_local_browser_history(60);
    state.set_status_banner(format!(
        "已从本机 Edge / Chrome 浏览历史只读提取 {added} 个高频专有词"
    ));
    added
}

#[tauri::command]
pub fn start_offline_model_download(state: State<'_, Arc<AppState>>) {
    state.inner().start_offline_model_download();
}

#[tauri::command]
pub fn cancel_offline_model_download(state: State<'_, Arc<AppState>>) {
    state.cancel_offline_model_download();
}

#[tauri::command]
pub fn complete_onboarding(state: State<'_, Arc<AppState>>) {
    state.update_config(|c| c.onboarding_completed = true);
}

#[tauri::command]
pub fn open_windows_mic_settings() {
    autostart::open_microphone_privacy_settings();
}

#[tauri::command]
pub async fn cloud_refresh_profile(
    state: State<'_, Arc<AppState>>,
) -> Result<Option<crate::core::cloud::CloudUserProfile>, String> {
    state.cloud_refresh_profile().await
}

#[tauri::command]
pub async fn cloud_send_email_code(email: String) -> Result<String, String> {
    crate::core::cloud::send_email_code(&email).await
}

#[tauri::command]
pub async fn cloud_verify_email_code(
    email: String,
    code: String,
    state: State<'_, Arc<AppState>>,
) -> Result<crate::core::cloud::CloudAuthSuccess, String> {
    let device_id = state.cloud_device_id();
    let res = crate::core::cloud::verify_email_code(&email, &code, &device_id).await?;
    state.apply_cloud_auth_success(&res.token, res.user.clone(), res.granted_trial);
    Ok(res)
}

#[tauri::command]
pub async fn cloud_start_google_login(
    state: State<'_, Arc<AppState>>,
) -> Result<crate::core::cloud::CloudGoogleStartResponse, String> {
    let device_id = state.cloud_device_id();
    crate::core::cloud::start_google_login(&device_id).await
}

#[tauri::command]
pub async fn cloud_poll_google_login(
    session_id: String,
    state: State<'_, Arc<AppState>>,
) -> Result<crate::core::cloud::CloudGooglePollResponse, String> {
    let res = crate::core::cloud::poll_google_login(&session_id).await?;
    if res.status == "completed" {
        if let (Some(tok), Some(user)) = (res.token.as_ref(), res.user.as_ref()) {
            state.apply_cloud_auth_success(tok, user.clone(), res.granted_trial);
        }
    }
    Ok(res)
}

#[tauri::command]
pub fn cloud_set_use_trial(enabled: bool, state: State<'_, Arc<AppState>>) -> Result<(), String> {
    state.cloud_set_use_trial(enabled)
}

#[tauri::command]
pub fn cloud_logout(state: State<'_, Arc<AppState>>) {
    state.cloud_logout();
}
