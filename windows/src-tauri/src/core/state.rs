use crate::audio::downloader::OfflineModelDownloader;
use crate::audio::dsp::AudioLevelBus;
use crate::audio::engine::{ASREngineConfig, StreamingASREngine};
use crate::audio::openai_asr::OpenAITranscriptionClient;
use crate::audio::sherpa_ffi::sense_voice_model_paths;
use crate::audio::volc_asr::VolcSeedASRClient;
use crate::core::credentials;
use crate::core::lexicon::PersonalLexiconStore;
use crate::core::polish::PolishEngine;
use crate::models::{
    ASRProviderOption, ActiveScreenContext, AppSnapshot, DashboardStats,
    DictationMode, DictationRecord, FormattingStyle, LLMConfig, LLMProviderOption,
    LexiconCategory, PillTelemetry, PipelinePhase, TriggerBehavior, TriggerKeyOption,
};
use crate::system::audio_ducker::SystemAudioDucker;
use crate::system::autostart;
use crate::system::hotkey::{HotkeyCallbacks, HotkeyMonitor, RecordedShortcutResult};
use crate::system::injector::{ContextInjector, LiveInputSession};
use crate::system::pill_window::PillWindowController;
use chrono::Utc;
use parking_lot::Mutex;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tauri::{AppHandle, Emitter};
use uuid::Uuid;

pub struct AppState {
    pub lexicon: Arc<PersonalLexiconStore>,
    pub asr: Arc<StreamingASREngine>,
    pub polish: Arc<PolishEngine>,
    pub downloader: Arc<OfflineModelDownloader>,
    pub audio_ducker: Arc<SystemAudioDucker>,
    pub pill: Arc<PillWindowController>,
    inner: Arc<Mutex<StateInner>>,
    is_session_active: Arc<AtomicBool>,
    is_finalizing: Arc<AtomicBool>,
    app_handle: Mutex<Option<AppHandle>>,
    config_path: PathBuf,
    history_path: PathBuf,
}

struct StateInner {
    phase: PipelinePhase,
    config: LLMConfig,
    history: Vec<DictationRecord>,
    status_banner: String,
    sandbox_text: String,
    sandbox_base_before_session: String,
    is_typing_inside_own_app: bool,
    is_recording_shortcut: bool,
    offline_download_progress: f64,
    offline_download_status_text: String,
    active_context: ActiveScreenContext,
    active_mode: DictationMode,
    live_session: Option<Arc<LiveInputSession>>,
}

impl AppState {
    pub fn new() -> Arc<Self> {
        let data_dir = dirs::data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("TypeZero");
        let _ = fs::create_dir_all(&data_dir);
        let config_path = data_dir.join("config.json");
        let history_path = data_dir.join("history.json");

        let config = Self::load_config_from(&config_path);
        let history = Self::load_history_from(&history_path);

        let state = Arc::new(Self {
            lexicon: Arc::new(PersonalLexiconStore::new(None)),
            asr: Arc::new(StreamingASREngine::new()),
            polish: Arc::new(PolishEngine::new()),
            downloader: Arc::new(OfflineModelDownloader::new()),
            audio_ducker: Arc::new(SystemAudioDucker::new()),
            pill: Arc::new(PillWindowController::new()),
            inner: Arc::new(Mutex::new(StateInner {
                phase: PipelinePhase::Idle,
                config,
                history,
                status_banner: String::new(),
                sandbox_text: String::new(),
                sandbox_base_before_session: String::new(),
                is_typing_inside_own_app: false,
                is_recording_shortcut: false,
                offline_download_progress: 0.0,
                offline_download_status_text: String::new(),
                active_context: ActiveScreenContext::empty(),
                active_mode: DictationMode::Dictate,
                live_session: None,
            })),
            is_session_active: Arc::new(AtomicBool::new(false)),
            is_finalizing: Arc::new(AtomicBool::new(false)),
            app_handle: Mutex::new(None),
            config_path,
            history_path,
        });

        state.sync_asr_engine_config();
        state.sync_hotkey_config();
        state
    }

    pub fn initialize_runtime(self: &Arc<Self>, app: AppHandle) {
        *self.app_handle.lock() = Some(app.clone());
        self.pill.attach(app.clone());

        // Wire ASR callbacks
        let st_partial = Arc::clone(self);
        let st_failover = Arc::clone(self);
        let st_err = Arc::clone(self);
        self.asr.set_callbacks(
            Arc::new(move |partial, _flush_tail| {
                st_partial.handle_asr_partial(partial);
            }),
            Arc::new(move |reason| {
                st_failover.set_status_banner(format!("✈️ 离线满血热备已接管：{reason}"));
            }),
            Arc::new(move |err_msg| {
                st_err.handle_asr_error(err_msg);
            }),
        );

        // Wire Global Hotkey callbacks
        let st_pre = Arc::clone(self);
        let st_start = Arc::clone(self);
        let st_stop = Arc::clone(self);
        let st_cancel = Arc::clone(self);
        HotkeyMonitor::set_callbacks(HotkeyCallbacks {
            on_prewarm_mic: Some(Arc::new(move || {
                st_pre.asr.prewarm_hot_mic();
            })),
            on_trigger_start: Some(Arc::new(move || {
                st_start.begin_dictation_session(false);
            })),
            on_trigger_stop: Some(Arc::new(move || {
                let s = Arc::clone(&st_stop);
                tauri::async_runtime::spawn(async move {
                    s.finish_dictation_session().await;
                });
            })),
            on_cancel: Some(Arc::new(move || {
                st_cancel.cancel_dictation_session();
            })),
        });
        HotkeyMonitor::start();

        // Warm up SenseVoice FP32 offline model + cloud sockets asynchronously
        let st_ready = Arc::clone(self);
        self.asr.load_sense_voice_async(Some(Arc::new(move || {
            st_ready.emit_state_changed();
        })));
        self.asr.prewarm_cloud_socket_if_ready();

        let cfg = self.inner.lock().config.clone();
        let key = credentials::load_api_key(cfg.selected_provider);
        self.polish.prewarm_connection(&cfg.base_url, &key);

        // Start lightweight 30Hz pill telemetry emitter (sleeps silently whenever idle -> ~0% CPU!)
        let st_tel = Arc::clone(self);
        tauri::async_runtime::spawn(async move {
            let mut ticker = tokio::time::interval(Duration::from_millis(33));
            loop {
                ticker.tick().await;
                let (phase, live_inline) = {
                    let g = st_tel.inner.lock();
                    (g.phase.clone(), g.config.enable_live_inline_typing)
                };
                if phase == PipelinePhase::Idle {
                    tokio::time::sleep(Duration::from_millis(120)).await;
                    continue;
                }
                let telemetry = PillTelemetry {
                    phase,
                    audio_level: AudioLevelBus::shared().sample_ballistic_envelope(),
                    recognized_count: AudioLevelBus::shared().current_recognized_count(),
                    enable_live_inline_typing: live_inline,
                };
                if let Some(h) = st_tel.app_handle.lock().as_ref() {
                    let _ = h.emit("pill-telemetry", &telemetry);
                }
            }
        });
    }

    pub fn emit_state_changed(&self) {
        if let Some(h) = self.app_handle.lock().as_ref() {
            let snap = self.snapshot();
            let _ = h.emit("state-changed", &snap);
        }
    }

    fn set_phase(&self, phase: PipelinePhase) {
        let visible = phase != PipelinePhase::Idle;
        {
            let mut g = self.inner.lock();
            g.phase = phase.clone();
        }
        self.pill.set_visible(visible);
        if let Some(h) = self.app_handle.lock().as_ref() {
            let live_inline = self.inner.lock().config.enable_live_inline_typing;
            let telemetry = PillTelemetry {
                phase,
                audio_level: AudioLevelBus::shared().sample_ballistic_envelope(),
                recognized_count: AudioLevelBus::shared().current_recognized_count(),
                enable_live_inline_typing: live_inline,
            };
            let _ = h.emit("pill-telemetry", &telemetry);
        }
        self.emit_state_changed();
    }

    pub fn set_status_banner(&self, banner: impl Into<String>) {
        self.inner.lock().status_banner = banner.into();
        self.emit_state_changed();
    }

    pub fn set_sandbox_text(&self, text: String) {
        self.inner.lock().sandbox_text = text;
        self.emit_state_changed();
    }

    pub fn sync_hotkey_config(&self) {
        let cfg = self.inner.lock().config.clone();
        HotkeyMonitor::configure(cfg.trigger_key, cfg.custom_hotkey, cfg.trigger_behavior);
    }

    pub fn sync_asr_engine_config(&self) {
        let cfg = self.inner.lock().config.clone();
        let volc_key = credentials::load_volc_speech_api_key();
        let openai_asr_key =
            credentials::load_effective_openai_asr_api_key(&cfg.openai_asr_base_url);
        self.asr.update_config(ASREngineConfig {
            asr_provider: cfg.asr_provider,
            volc_speech_api_key: volc_key,
            openai_asr_base_url: cfg.openai_asr_base_url,
            openai_asr_model: cfg.openai_asr_model,
            openai_asr_api_key: openai_asr_key,
            enable_whisper_agc: cfg.enable_whisper_agc,
        });
    }

    fn handle_asr_partial(&self, partial: String) {
        if !self.is_session_active.load(Ordering::Relaxed) {
            return;
        }
        let (cfg, ctx, mode, own_app, base_sandbox, live_session, uses_cloud_seed) = {
            let g = self.inner.lock();
            (
                g.config.clone(),
                g.active_context.clone(),
                g.active_mode,
                g.is_typing_inside_own_app,
                g.sandbox_base_before_session.clone(),
                g.live_session.clone(),
                self.asr.active_session_uses_cloud_seed_asr(),
            )
        };
        let entries = self.lexicon.entries();
        let instant_fixed =
            PolishEngine::apply_instant_local_dictionary(&partial, &entries, &ctx, &cfg, false);
        let spoken_count = instant_fixed
            .chars()
            .filter(|c| !c.is_whitespace())
            .count();
        AudioLevelBus::shared().push_recognized_count(spoken_count);

        if cfg.enable_live_inline_typing && mode == DictationMode::Dictate {
            if own_app {
                self.inner.lock().sandbox_text = format!("{base_sandbox}{instant_fixed}");
                self.emit_state_changed();
            } else if let Some(sess) = live_session {
                sess.update_live_text(&instant_fixed, uses_cloud_seed);
            }
        }
    }

    fn handle_asr_error(&self, err_msg: String) {
        self.is_session_active.store(false, Ordering::SeqCst);
        self.audio_ducker.restore_if_needed();
        HotkeyMonitor::sync_recording_state(false);
        self.set_phase(PipelinePhase::Error { message: err_msg });
        self.schedule_idle_reset(Duration::from_millis(2600));
    }

    pub fn begin_dictation_session(self: &Arc<Self>, force_sandbox: bool) {
        if self.is_session_active.load(Ordering::SeqCst)
            || self.is_finalizing.load(Ordering::SeqCst)
        {
            HotkeyMonitor::sync_recording_state(self.is_session_active.load(Ordering::SeqCst));
            return;
        }

        let (front_name, front_proc, front_title) = ContextInjector::capture_fast_foreground_app();
        let is_own = force_sandbox || front_proc.to_lowercase().contains("typezero");

        self.is_session_active.store(true, Ordering::SeqCst);
        HotkeyMonitor::sync_recording_state(true);

        let fast_ctx = ActiveScreenContext {
            app_name: front_name.clone(),
            process_name: front_proc.clone(),
            window_title: front_title.clone(),
            selected_text: String::new(),
            preceding_text: String::new(),
            has_focused_text_input: true,
        };

        let (cfg, recent_snippets, own_sandbox_snap) = {
            let mut g = self.inner.lock();
            g.is_typing_inside_own_app = is_own;
            if is_own {
                g.sandbox_base_before_session = g.sandbox_text.clone();
            }
            g.active_context = fast_ctx.clone();
            g.active_mode = DictationMode::Dictate;
            g.live_session = if g.config.enable_live_inline_typing {
                Some(Arc::new(LiveInputSession::new(fast_ctx.clone())))
            } else {
                None
            };
            let recent: Vec<String> = g
                .history
                .iter()
                .take(2)
                .map(|r| r.polished_text.clone())
                .collect();
            let own_tail: String = if is_own {
                let chars: Vec<char> = g.sandbox_text.chars().collect();
                if chars.len() > 140 {
                    chars[chars.len() - 140..].iter().collect()
                } else {
                    g.sandbox_text.clone()
                }
            } else {
                String::new()
            };
            (g.config.clone(), recent, own_tail)
        };

        AudioLevelBus::shared().reset();
        self.set_phase(PipelinePhase::Listening {
            live_preview: String::new(),
            mode: DictationMode::Dictate,
        });

        if cfg.enable_auto_mute_during_dictation {
            self.audio_ducker.mute_if_needed();
        }

        self.sync_asr_engine_config();
        let llm_key = credentials::load_api_key(cfg.selected_provider);
        self.polish.prewarm_connection(&cfg.base_url, &llm_key);

        let raw_clip = ContextInjector::read_clipboard_text().trim().to_string();
        let short_clip = if (2..=42).contains(&raw_clip.chars().count()) && !raw_clip.contains('\n')
        {
            raw_clip
        } else {
            String::new()
        };

        let mut hint_parts = vec![
            front_name,
            front_title,
            short_clip.clone(),
            own_sandbox_snap.clone(),
        ];
        hint_parts.extend(recent_snippets.iter().cloned());
        let immediate_hint = hint_parts.join(" ");

        let mut top_terms = self.lexicon.top_acoustic_contextual_strings(&immediate_hint, 64);
        if (2..=14).contains(&short_clip.chars().count())
            && !short_clip.contains(' ')
            && !top_terms.iter().any(|t| t.eq_ignore_ascii_case(&short_clip))
        {
            top_terms.insert(0, short_clip);
        }

        let mut dialog_ctx = Vec::new();
        if !own_sandbox_snap.trim().is_empty() {
            dialog_ctx.push(own_sandbox_snap);
        }
        for s in recent_snippets.into_iter().take(2) {
            if !s.trim().is_empty() {
                dialog_ctx.push(s);
            }
        }
        dialog_ctx.truncate(2);

        if let Err(err) = self
            .asr
            .start_streaming(&cfg.speech_locale, &top_terms, &dialog_ctx)
        {
            self.handle_asr_error(err);
            return;
        }

        // Parallel UI Automation context capture (detects highlighted text -> RewriteSelection mode!)
        if !is_own {
            let st_bg = Arc::clone(self);
            std::thread::spawn(move || {
                let full_ctx = ContextInjector::capture_current_context();
                if !st_bg.is_session_active.load(Ordering::Relaxed) {
                    return;
                }
                let switched_rewrite = {
                    let mut g = st_bg.inner.lock();
                    if let Some(sess) = g.live_session.as_ref() {
                        sess.update_context(full_ctx.clone());
                    }
                    let has_sel = !full_ctx.selected_text.is_empty();
                    g.active_context = full_ctx;
                    if has_sel {
                        g.active_mode = DictationMode::RewriteSelection;
                        true
                    } else {
                        false
                    }
                };
                if switched_rewrite {
                    st_bg.set_phase(PipelinePhase::Listening {
                        live_preview: String::new(),
                        mode: DictationMode::RewriteSelection,
                    });
                }
            });
        }
    }

    pub async fn finish_dictation_session(self: &Arc<Self>) {
        if !self.is_session_active.load(Ordering::SeqCst)
            || self.is_finalizing.swap(true, Ordering::SeqCst)
        {
            return;
        }
        HotkeyMonitor::sync_recording_state(false);

        // 100ms tail-capture grace window so trailing syllables finish cleanly
        tokio::time::sleep(Duration::from_millis(100)).await;
        self.is_session_active.store(false, Ordering::SeqCst);
        self.audio_ducker.restore_if_needed();

        let used_punctuated_cloud = self.asr.active_session_uses_any_cloud_asr();
        if self.asr.active_session_uses_openai_asr() {
            self.set_phase(PipelinePhase::Polishing {
                raw_text: "云端语音转写中…".to_string(),
            });
        }

        let (raw_text, duration) = self.asr.finish_streaming().await;
        if raw_text.trim().is_empty() {
            let should_clear = {
                let mut g = self.inner.lock();
                if g.is_typing_inside_own_app {
                    g.sandbox_text = g.sandbox_base_before_session.clone();
                }
                g.live_session = None;
                !matches!(g.phase, PipelinePhase::Error { .. })
            };
            if should_clear {
                self.set_phase(PipelinePhase::Idle);
            }
            self.is_finalizing.store(false, Ordering::SeqCst);
            return;
        }

        let (cfg, ctx, mode, own_app, base_sandbox, recent_texts, live_session) = {
            let g = self.inner.lock();
            let recent: Vec<String> = g
                .history
                .iter()
                .take(3)
                .map(|r| r.polished_text.clone())
                .rev()
                .collect();
            (
                g.config.clone(),
                g.active_context.clone(),
                g.active_mode,
                g.is_typing_inside_own_app,
                g.sandbox_base_before_session.clone(),
                recent,
                g.live_session.clone(),
            )
        };

        let entries = self.lexicon.entries();
        let tail_fixed =
            PolishEngine::apply_instant_local_dictionary(&raw_text, &entries, &ctx, &cfg, true);

        if own_app && cfg.enable_live_inline_typing && mode == DictationMode::Dictate {
            self.inner.lock().sandbox_text = format!("{base_sandbox}{tail_fixed}");
            self.emit_state_changed();
        }

        let recalled = self
            .lexicon
            .recall_relevant_terms(&raw_text, &ctx.window_title, 26);

        let api_key = credentials::load_api_key(cfg.selected_provider);
        if api_key.trim().is_empty()
            && !PolishEngine::is_keyless_local_endpoint(&cfg.base_url)
            && cfg.formatting_style != FormattingStyle::VerbatimLocal
        {
            self.set_status_banner(format!(
                "⚠️ 当前生效的「{}」尚未填入 API Key，本次仅执行本地词库纠偏",
                cfg.selected_provider.short_name()
            ));
        }

        self.set_phase(PipelinePhase::Polishing {
            raw_text: tail_fixed.clone(),
        });

        let can_stream_sse_live = !own_app
            && cfg.enable_live_inline_typing
            && mode == DictationMode::Dictate
            && live_session
                .as_ref()
                .map(|s| s.prepare_for_sse_polish())
                .unwrap_or(false);

        let did_stream_sse = Arc::new(AtomicBool::new(false));
        let did_stream_cb = Arc::clone(&did_stream_sse);
        let st_stream = Arc::clone(self);
        let live_cb = live_session.clone();
        let base_sb_cb = base_sandbox.clone();
        let inline_flag = cfg.enable_live_inline_typing;

        let polish_res = self
            .polish
            .polish(
                &raw_text,
                mode,
                &ctx,
                &recalled,
                &recent_texts,
                &cfg,
                &api_key,
                self.asr.is_using_sense_voice(),
                used_punctuated_cloud,
                Some(move |chunk: String, is_first: bool| {
                    if own_app && inline_flag {
                        {
                            let mut g = st_stream.inner.lock();
                            if is_first {
                                g.sandbox_text = format!("{base_sb_cb}{chunk}");
                            } else {
                                g.sandbox_text.push_str(&chunk);
                            }
                        }
                        st_stream.emit_state_changed();
                        did_stream_cb.store(true, Ordering::SeqCst);
                    } else if can_stream_sse_live {
                        if let Some(sess) = live_cb.as_ref() {
                            sess.consume_sse_chunk(&chunk);
                            did_stream_cb.store(true, Ordering::SeqCst);
                        }
                    }
                }),
            )
            .await;

        let final_text = polish_res.text;
        let polish_ms = polish_res.latency_ms;
        if final_text.is_empty() {
            self.inner.lock().live_session = None;
            self.set_phase(PipelinePhase::Idle);
            self.is_finalizing.store(false, Ordering::SeqCst);
            return;
        }

        let mut landed_in_input = true;
        if own_app {
            self.inner.lock().sandbox_text = format!("{base_sandbox}{final_text}");
        } else if did_stream_sse.load(Ordering::SeqCst) {
            if let Some(sess) = live_session.as_ref() {
                sess.finish_sse_polish(&final_text);
            }
        } else if cfg.enable_live_inline_typing && mode == DictationMode::Dictate {
            landed_in_input = live_session
                .as_ref()
                .map(|s| s.finalize_after_key_release(&final_text))
                .unwrap_or(false);
        } else if ContextInjector::is_likely_editable_focus_now() || ctx.has_focused_text_input {
            let final_clone = final_text.clone();
            let ctx_clone = ctx.clone();
            let _ = tokio::task::spawn_blocking(move || {
                ContextInjector::inject_text_at_cursor(&final_clone, &ctx_clone);
            })
            .await;
        } else {
            ContextInjector::save_to_safety_clipboard(&final_text);
            landed_in_input = false;
        }

        let lower_final = final_text.to_lowercase();
        let truly_used: Vec<_> = recalled
            .iter()
            .filter(|e| lower_final.contains(&e.term.to_lowercase()))
            .cloned()
            .collect();
        self.lexicon.record_term_hits(&truly_used);

        // Voice Teach-in Loop: selection rewrite permanently updates personal lexicon
        if mode == DictationMode::RewriteSelection && cfg.enable_auto_learn {
            if let Some((wrong, right)) = self
                .lexicon
                .learn_from_selection_rewrite(&ctx.selected_text, &final_text)
            {
                self.set_status_banner(format!(
                    "✨ 语音纠偏已永久记入词库：「{wrong}」➔「{right}」"
                ));
            }
        }

        let record = DictationRecord {
            id: Uuid::new_v4().to_string(),
            timestamp: Utc::now(),
            raw_transcript: raw_text,
            polished_text: final_text.clone(),
            duration_seconds: duration.max(0.2),
            polish_latency_ms: polish_ms,
            target_app_name: if own_app {
                "TypeZero 试音沙盒".to_string()
            } else if ctx.app_name.is_empty() {
                "外部应用".to_string()
            } else {
                ctx.app_name.clone()
            },
            mode,
            matched_terms: recalled.iter().take(5).map(|e| e.term.clone()).collect(),
        };

        let gen_count = {
            let mut g = self.inner.lock();
            g.history.insert(0, record);
            if g.history.len() > 1000 {
                g.history.truncate(1000);
            }
            g.live_session = None;
            g.history.len()
        };
        self.save_history();

        if !landed_in_input {
            self.set_phase(PipelinePhase::SavedToClipboard {
                text_preview: "已暂存剪贴板 · Ctrl+V 粘贴".to_string(),
            });
            self.schedule_idle_reset(Duration::from_millis(2600));
        } else {
            self.set_phase(PipelinePhase::Completed {
                final_text: final_text.clone(),
                latency_ms: polish_ms,
            });
            self.schedule_idle_reset(Duration::from_millis(380));

            if cfg.enable_auto_learn {
                self.schedule_auto_learn_observation(
                    final_text,
                    ctx.process_name.clone(),
                    own_app,
                    gen_count,
                );
            }
        }

        self.is_finalizing.store(false, Ordering::SeqCst);
    }

    pub fn cancel_dictation_session(&self) {
        if !self.is_session_active.swap(false, Ordering::SeqCst) {
            return;
        }
        self.audio_ducker.restore_if_needed();
        HotkeyMonitor::sync_recording_state(false);
        self.asr.cancel();
        AudioLevelBus::shared().reset();

        let emitted_to_erase = {
            let mut g = self.inner.lock();
            if g.is_typing_inside_own_app {
                g.sandbox_text = g.sandbox_base_before_session.clone();
                g.live_session = None;
                0usize
            } else {
                let count = g
                    .live_session
                    .as_ref()
                    .map(|s| s.current_text().chars().count())
                    .unwrap_or(0);
                g.live_session = None;
                count
            }
        };
        if emitted_to_erase > 0 {
            ContextInjector::send_clean_backspaces(emitted_to_erase);
        }
        self.set_phase(PipelinePhase::Idle);
    }

    fn schedule_idle_reset(&self, delay: Duration) {
        let inner = Arc::clone(&self.inner);
        let pill = Arc::clone(&self.pill);
        let app_handle = self.app_handle.lock().clone();
        tauri::async_runtime::spawn(async move {
            tokio::time::sleep(delay).await;
            let should_reset = {
                let mut g = inner.lock();
                if matches!(
                    g.phase,
                    PipelinePhase::Listening { .. } | PipelinePhase::Polishing { .. }
                ) {
                    false
                } else {
                    g.phase = PipelinePhase::Idle;
                    true
                }
            };
            if should_reset {
                pill.set_visible(false);
                if let Some(h) = app_handle {
                    let _ = h.emit(
                        "pill-telemetry",
                        &PillTelemetry {
                            phase: PipelinePhase::Idle,
                            audio_level: 0.05,
                            recognized_count: 0,
                            enable_live_inline_typing: false,
                        },
                    );
                }
            }
        });
    }

    fn schedule_auto_learn_observation(
        self: &Arc<Self>,
        injected_text: String,
        expected_proc: String,
        was_sandbox: bool,
        generation_count: usize,
    ) {
        let st = Arc::clone(self);
        tauri::async_runtime::spawn(async move {
            for delay_ms in [5500u64, 6800u64] {
                tokio::time::sleep(Duration::from_millis(delay_ms)).await;
                if st.is_session_active.load(Ordering::Relaxed)
                    || st.inner.lock().history.len() != generation_count
                {
                    return;
                }
                let edited_box = if was_sandbox {
                    Some(st.inner.lock().sandbox_text.clone())
                } else {
                    let (_, cur_proc, _) = ContextInjector::capture_fast_foreground_app();
                    if !cur_proc.eq_ignore_ascii_case(&expected_proc) {
                        continue;
                    }
                    tokio::task::spawn_blocking(ContextInjector::read_current_focused_value)
                        .await
                        .ok()
                        .flatten()
                };
                if let Some(box_val) = edited_box {
                    if let Some((wrong, right)) = st
                        .lexicon
                        .learn_from_manual_edit_if_applicable(&injected_text, &box_val)
                    {
                        st.set_status_banner(format!(
                            "✨ 自学习词典已自动记住纠偏：「{wrong}」➔「{right}」"
                        ));
                        return;
                    }
                }
            }
        });
    }

    // MARK: - Settings, Verification & Provider Activation

    pub fn update_config<F: FnOnce(&mut LLMConfig)>(&self, mutate: F) {
        let (prev_provider, prev_asr, prev_login) = {
            let g = self.inner.lock();
            (
                g.config.selected_provider,
                g.config.asr_provider,
                g.config.launch_at_login,
            )
        };
        let new_cfg = {
            let mut g = self.inner.lock();
            mutate(&mut g.config);
            g.config.clone()
        };
        if new_cfg.launch_at_login != prev_login {
            let _ = autostart::set_launch_at_login(new_cfg.launch_at_login);
        }
        self.save_config();
        self.sync_asr_engine_config();
        self.sync_hotkey_config();
        if new_cfg.asr_provider != prev_asr {
            self.asr.prewarm_cloud_socket_if_ready();
        }
        if new_cfg.selected_provider != prev_provider {
            let key = credentials::load_api_key(new_cfg.selected_provider);
            self.polish.prewarm_connection(&new_cfg.base_url, &key);
        }
        self.emit_state_changed();
    }

    pub fn start_shortcut_capture(self: &Arc<Self>) {
        self.inner.lock().is_recording_shortcut = true;
        self.emit_state_changed();
        let st = Arc::clone(self);
        HotkeyMonitor::begin_interactive_capture(move |res| {
            st.inner.lock().is_recording_shortcut = false;
            match res {
                RecordedShortcutResult::Preset(opt) => {
                    st.update_config(|c| c.trigger_key = opt);
                    st.set_status_banner(format!(
                        "✅ 全局快捷键已切换为「{}」",
                        opt.display_name()
                    ));
                }
                RecordedShortcutResult::Custom(spec) => {
                    let label = spec.label.clone();
                    st.update_config(|c| {
                        c.custom_hotkey = spec;
                        c.trigger_key = TriggerKeyOption::Custom;
                    });
                    st.set_status_banner(format!("✅ 自定义全局快捷键已生效：「{label}」"));
                }
                RecordedShortcutResult::Cancelled => {
                    st.emit_state_changed();
                }
            }
        });
    }

    pub fn cancel_shortcut_capture(&self) {
        HotkeyMonitor::cancel_interactive_capture();
        self.inner.lock().is_recording_shortcut = false;
        self.emit_state_changed();
    }

    pub fn save_volc_speech_key(&self, key: &str) {
        credentials::save_volc_speech_api_key(key);
        self.sync_asr_engine_config();
        let saved = credentials::load_volc_speech_api_key();
        let is_active = self.inner.lock().config.asr_provider == ASRProviderOption::VolcSeedASR;
        if saved.is_empty() {
            self.set_status_banner("已清空豆包语音密钥");
        } else if is_active {
            self.set_status_banner("✅ 豆包 Seed-ASR 2.0 语音密钥已保存至 Windows 凭据管理器");
        } else {
            self.set_status_banner("💾 豆包语音密钥已保存（点击「校验并切换」启用）");
        }
    }

    pub fn save_openai_asr_config(&self, base_url: &str, model: &str, override_key: &str) {
        let clean_url = if base_url.trim().is_empty() {
            "https://api.openai.com/v1".to_string()
        } else {
            base_url.trim().to_string()
        };
        let is_groq = OpenAITranscriptionClient::is_groq_endpoint(&clean_url);
        let clean_model = if model.trim().is_empty() {
            if is_groq {
                "whisper-large-v3-turbo".to_string()
            } else {
                "gpt-4o-mini-transcribe".to_string()
            }
        } else {
            model.trim().to_string()
        };
        credentials::save_openai_asr_api_key(override_key);
        self.update_config(|c| {
            c.openai_asr_base_url = clean_url.clone();
            c.openai_asr_model = clean_model.clone();
        });
        let label = if is_groq { "Groq Whisper" } else { "OpenAI 语音大模型" };
        self.set_status_banner(format!("✅ {label}（{clean_model}）配置已保存"));
    }

    pub async fn probe_seed_asr(&self, key_input: &str) -> Result<String, String> {
        if !key_input.trim().is_empty() {
            credentials::save_volc_speech_api_key(key_input);
            self.sync_asr_engine_config();
        }
        let key = credentials::load_volc_speech_api_key();
        let rtt = VolcSeedASRClient::probe_handshake_latency(&key).await?;
        let hot_count = self.lexicon.entries().len().min(65);
        let summary = format!(
            "⚡ 实测通过（volc.seedasr.sauc.duration）：国内直连握手+首帧 {rtt}ms · 已挂载 {hot_count} 个专属热词"
        );
        self.set_status_banner(format!("⚡ 豆包 Seed-ASR 2.0 连通成功：首帧 {rtt}ms"));
        Ok(summary)
    }

    pub async fn probe_openai_asr(
        &self,
        base_url: &str,
        model: &str,
        override_key: &str,
    ) -> Result<String, String> {
        if !override_key.trim().is_empty() {
            credentials::save_openai_asr_api_key(override_key);
            self.sync_asr_engine_config();
        }
        let eff_key = if !override_key.trim().is_empty() {
            override_key.trim().to_string()
        } else {
            credentials::load_effective_openai_asr_api_key(base_url)
        };
        let rtt = OpenAITranscriptionClient::probe_latency(base_url, model, &eff_key).await?;
        let hot_count = self.lexicon.entries().len().min(40);
        let summary = format!(
            "⚡ 实测通过（{model}）：音频上传+转写 {rtt}ms · 将注入 Top-{hot_count} 词库提示"
        );
        self.set_status_banner(format!("⚡ 云端语音连通成功：实测 {rtt}ms"));
        Ok(summary)
    }

    pub async fn activate_asr_provider(
        &self,
        provider: ASRProviderOption,
        key_input: &str,
        openai_url: &str,
        openai_model: &str,
    ) -> Result<String, String> {
        match provider {
            ASRProviderOption::VolcSeedASR => {
                let summary = self.probe_seed_asr(key_input).await?;
                self.update_config(|c| c.select_asr_provider(ASRProviderOption::VolcSeedASR));
                self.set_status_banner("✅ 豆包流式语音大模型 2.0 校验通过，已切换为当前唯一生效引擎");
                Ok(summary)
            }
            ASRProviderOption::OpenAIWhisper => {
                self.save_openai_asr_config(openai_url, openai_model, key_input);
                let (url, model) = {
                    let g = self.inner.lock();
                    (
                        g.config.openai_asr_base_url.clone(),
                        g.config.openai_asr_model.clone(),
                    )
                };
                let summary = self.probe_openai_asr(&url, &model, key_input).await?;
                self.update_config(|c| c.select_asr_provider(ASRProviderOption::OpenAIWhisper));
                self.set_status_banner("✅ OpenAI / Groq 云端语音校验通过，已切换为当前唯一生效引擎");
                Ok(summary)
            }
            ASRProviderOption::LocalSenseVoice => {
                if sense_voice_model_paths().is_none() {
                    return Err("本机 SenseVoice 离线模型尚未下载就绪，请先点击下载 886MB 离线满血模型".to_string());
                }
                if !StreamingASREngine::is_sherpa_runtime_available() {
                    return Err("未检测到 sherpa-onnx-c-api.dll 运行时库，请使用官方安装包或运行 fetch-sherpa-win64.ps1".to_string());
                }
                self.asr.load_sense_voice_async(None);
                self.update_config(|c| c.select_asr_provider(ASRProviderOption::LocalSenseVoice));
                self.set_status_banner("✅ 纯本机 SenseVoice FP32 离线模型已校验就绪并设为当前唯一生效引擎");
                Ok("⚡ 本机 886MB SenseVoice FP32 离线模型已启用".to_string())
            }
        }
    }

    pub fn save_llm_provider_draft(
        &self,
        provider: LLMProviderOption,
        base_url: &str,
        model_name: &str,
        api_key: &str,
    ) {
        let final_model = if model_name.trim().is_empty() {
            provider.default_model_name().to_string()
        } else {
            model_name.trim().to_string()
        };
        let final_url = if base_url.trim().is_empty() {
            provider.default_base_url().to_string()
        } else {
            base_url.trim().to_string()
        };

        credentials::save_api_key(api_key, provider);
        self.update_config(|c| {
            c.provider_models
                .insert(provider.key_name().to_string(), final_model.clone());
            if provider == LLMProviderOption::Custom {
                c.custom_base_url = final_url.clone();
            }
            if c.selected_provider == provider {
                c.model_name = final_model.clone();
                c.base_url = final_url.clone();
            }
        });
        let saved = credentials::load_api_key(provider);
        if saved.is_empty() && !PolishEngine::is_keyless_local_endpoint(&final_url) {
            self.set_status_banner(format!("已清空「{}」API Key", provider.short_name()));
        } else {
            self.set_status_banner(format!("💾 「{}」密钥与模型已安全保存", provider.title()));
        }
    }

    pub async fn benchmark_llm_provider(
        &self,
        provider: LLMProviderOption,
        base_url: &str,
        model_name: &str,
        api_key: &str,
    ) -> Result<String, String> {
        let final_model = if model_name.trim().is_empty() {
            provider.default_model_name().to_string()
        } else {
            model_name.trim().to_string()
        };
        let final_url = if base_url.trim().is_empty() {
            provider.default_base_url().to_string()
        } else {
            base_url.trim().to_string()
        };
        let eff_key = if !api_key.trim().is_empty() {
            credentials::save_api_key(api_key, provider);
            api_key.trim().to_string()
        } else {
            credentials::load_api_key(provider)
        };

        let mut probe_cfg = self.inner.lock().config.clone();
        probe_cfg.selected_provider = provider;
        probe_cfg.base_url = final_url;
        probe_cfg.model_name = final_model.clone();

        let res = self.polish.benchmark_latency(&probe_cfg, &eff_key).await?;
        let flat = res.sample_output.replace('\n', " ↵ ");
        let summary = format!(
            "⚡ 实测通过（{final_model}）：首字 TTFT {}ms · 总耗时 {}ms · 样例：「{flat}」",
            res.ttft_ms, res.total_ms
        );
        self.set_status_banner(format!(
            "⚡ {} 实测成功：首字 TTFT {}ms",
            provider.short_name(),
            res.ttft_ms
        ));
        Ok(summary)
    }

    pub async fn activate_llm_provider(
        &self,
        provider: LLMProviderOption,
        base_url: &str,
        model_name: &str,
        api_key: &str,
    ) -> Result<String, String> {
        let summary = self
            .benchmark_llm_provider(provider, base_url, model_name, api_key)
            .await?;
        let final_model = if model_name.trim().is_empty() {
            provider.default_model_name().to_string()
        } else {
            model_name.trim().to_string()
        };
        let final_url = if base_url.trim().is_empty() {
            provider.default_base_url().to_string()
        } else {
            base_url.trim().to_string()
        };
        self.update_config(|c| {
            c.select_provider(provider);
            c.base_url = final_url;
            c.model_name = final_model;
            c.sync_active_endpoint_edits();
        });
        self.set_status_banner(format!(
            "✅ 「{}」校验通过，已切换为当前唯一生效排版模型",
            provider.title()
        ));
        Ok(summary)
    }

    pub async fn distill_pasted_corpus(&self, raw_corpus: &str) -> Result<usize, String> {
        let cfg = self.inner.lock().config.clone();
        let key = credentials::load_api_key(cfg.selected_provider);
        let extracted = self
            .polish
            .distill_terms_from_raw_corpus(raw_corpus, &cfg, &key)
            .await?;
        let added = self.lexicon.bulk_upsert(extracted);
        let total = self.lexicon.entries().len();
        self.set_status_banner(format!(
            "✨ 智能蒸馏完成：新增 {added} 个专属词条（总词库 {total} 词）"
        ));
        Ok(added)
    }

    pub fn start_offline_model_download(self: &Arc<Self>) {
        if self.downloader.is_downloading() {
            return;
        }
        {
            let mut g = self.inner.lock();
            g.offline_download_progress = 0.01;
            g.offline_download_status_text = "正在初始化 886MB 离线满血包下载…".to_string();
        }
        self.emit_state_changed();

        let st_prog = Arc::clone(self);
        let st_done = Arc::clone(self);
        self.downloader.start_download(
            move |frac, status| {
                {
                    let mut g = st_prog.inner.lock();
                    g.offline_download_progress = frac;
                    g.offline_download_status_text = status;
                }
                st_prog.emit_state_changed();
            },
            move |success, msg| {
                {
                    let mut g = st_done.inner.lock();
                    g.offline_download_status_text = msg.clone();
                    g.status_banner = msg;
                }
                if success {
                    let st_r = Arc::clone(&st_done);
                    st_done.asr.load_sense_voice_async(Some(Arc::new(move || {
                        st_r.emit_state_changed();
                    })));
                }
                st_done.emit_state_changed();
            },
        );
    }

    pub fn cancel_offline_model_download(&self) {
        self.downloader.cancel();
        self.emit_state_changed();
    }

    pub fn minimize_to_tray_enabled(&self) -> bool {
        self.inner.lock().config.minimize_to_tray
    }

    pub fn copy_latest_record_to_clipboard(&self) -> bool {
        let latest = self
            .inner
            .lock()
            .history
            .first()
            .map(|r| r.polished_text.clone());
        if let Some(txt) = latest {
            ContextInjector::save_to_safety_clipboard(&txt);
            true
        } else {
            false
        }
    }

    pub fn snapshot(&self) -> AppSnapshot {
        let g = self.inner.lock();
        let mut saved_keys = HashMap::new();
        for p in LLMProviderOption::ALL {
            saved_keys.insert(p.key_name().to_string(), credentials::has_saved_api_key(p));
        }
        let has_volc = !credentials::load_volc_speech_api_key().is_empty();
        let override_oai = credentials::load_openai_asr_override_key();
        let has_oai_override = !override_oai.is_empty();
        let is_groq = OpenAITranscriptionClient::is_groq_endpoint(&g.config.openai_asr_base_url);
        let is_reusing = !has_oai_override
            && !is_groq
            && *saved_keys
                .get(LLMProviderOption::Openai.key_name())
                .unwrap_or(&false);
        let has_eff_oai = !credentials::load_effective_openai_asr_api_key(
            &g.config.openai_asr_base_url,
        )
        .is_empty()
            || PolishEngine::is_keyless_local_endpoint(&g.config.openai_asr_base_url);

        let active_trigger_display = if g.config.trigger_key == TriggerKeyOption::Custom {
            format!("自定义快捷键 ({})", g.config.custom_hotkey.label)
        } else {
            g.config.trigger_key.display_name().to_string()
        };
        let active_trigger_compact = if g.config.trigger_key == TriggerKeyOption::Custom {
            g.config.custom_hotkey.label.clone()
        } else {
            g.config.trigger_key.compact_label().to_string()
        };

        let stats = Self::compute_stats(&g.history);
        let local_paths = sense_voice_model_paths();

        AppSnapshot {
            phase: g.phase.clone(),
            config: g.config.clone(),
            history: g.history.clone(),
            lexicon: self.lexicon.entries(),
            saved_provider_keys: saved_keys,
            has_volc_speech_key: has_volc,
            has_openai_asr_override_key: has_oai_override,
            has_effective_openai_asr_key: has_eff_oai,
            is_openai_asr_reusing_llm_key: is_reusing,
            mic_available: StreamingASREngine::is_microphone_available(),
            sense_voice_loaded: self.asr.is_using_sense_voice() || local_paths.is_some(),
            sense_voice_full_fp32: self.asr.is_full_precision_fp32()
                || local_paths.map(|p| p.is_full_fp32).unwrap_or(false),
            sherpa_runtime_available: StreamingASREngine::is_sherpa_runtime_available(),
            status_banner: g.status_banner.clone(),
            sandbox_text: g.sandbox_text.clone(),
            is_recording_shortcut: g.is_recording_shortcut,
            is_downloading_offline_model: self.downloader.is_downloading(),
            offline_download_progress: g.offline_download_progress,
            offline_download_status_text: g.offline_download_status_text.clone(),
            active_trigger_display_name: active_trigger_display,
            active_trigger_compact_label: active_trigger_compact,
            stats,
        }
    }

    fn compute_stats(history: &[DictationRecord]) -> DashboardStats {
        let total_chars: usize = history.iter().map(|r| r.character_count()).sum();
        let total_mins: f64 = history.iter().map(|r| r.duration_seconds).sum::<f64>() / 60.0;
        let avg_cpm = if total_mins > 0.05 {
            ((total_chars as f64) / total_mins).round() as u64
        } else {
            0
        };
        let manual_mins = (total_chars as f64) / 45.0;
        let saved_mins = (manual_mins - total_mins).max(0.0).round() as u64;
        let avg_latency = if history.is_empty() {
            0
        } else {
            history.iter().map(|r| r.polish_latency_ms).sum::<u64>() / history.len() as u64
        };

        let mut daily_counts: HashMap<String, usize> = HashMap::new();
        let mut active_days = HashSet::new();
        for rec in history {
            let day = rec.timestamp.format("%Y-%m-%d").to_string();
            active_days.insert(day.clone());
            *daily_counts.entry(day).or_insert(0) += rec.character_count();
        }

        DashboardStats {
            total_characters: total_chars,
            time_saved_minutes: saved_mins,
            average_cpm: avg_cpm,
            average_latency_ms: avg_latency,
            active_days: active_days.len(),
            daily_counts,
        }
    }

    // MARK: - Persistence

    fn load_config_from(path: &PathBuf) -> LLMConfig {
        let Ok(bytes) = fs::read(path) else {
            return LLMConfig::default();
        };
        let Ok(raw_val) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
            return LLMConfig::default();
        };
        let mut cfg = serde_json::from_value::<LLMConfig>(raw_val.clone()).unwrap_or_default();
        cfg.normalize_after_deserialize(&raw_val);
        cfg
    }

    fn save_config(&self) {
        let cfg = self.inner.lock().config.clone();
        if let Ok(bytes) = serde_json::to_vec_pretty(&cfg) {
            let tmp = self.config_path.with_extension("json.tmp");
            if fs::write(&tmp, &bytes).is_ok() {
                let _ = fs::rename(&tmp, &self.config_path);
            } else {
                let _ = fs::write(&self.config_path, &bytes);
            }
        }
    }

    fn load_history_from(path: &PathBuf) -> Vec<DictationRecord> {
        let Ok(bytes) = fs::read(path) else {
            return Vec::new();
        };
        serde_json::from_slice::<Vec<DictationRecord>>(&bytes).unwrap_or_default()
    }

    fn save_history(&self) {
        let hist = self.inner.lock().history.clone();
        if let Ok(bytes) = serde_json::to_vec_pretty(&hist) {
            let tmp = self.history_path.with_extension("json.tmp");
            if fs::write(&tmp, &bytes).is_ok() {
                let _ = fs::rename(&tmp, &self.history_path);
            } else {
                let _ = fs::write(&self.history_path, &bytes);
            }
        }
    }

    // Expose typed mutators for commands
    pub fn apply_formatting_style(&self, style: FormattingStyle) {
        self.update_config(|c| c.formatting_style = style);
    }
    pub fn apply_trigger_key(&self, key: TriggerKeyOption) {
        self.update_config(|c| c.trigger_key = key);
    }
    pub fn apply_trigger_behavior(&self, beh: TriggerBehavior) {
        self.update_config(|c| c.trigger_behavior = beh);
    }
    pub fn upsert_lexicon(
        &self,
        term: &str,
        aliases: Vec<String>,
        category: LexiconCategory,
        weight: i32,
    ) {
        self.lexicon.upsert(term, aliases, category, weight);
        self.emit_state_changed();
    }
    pub fn update_lexicon_entry(
        &self,
        id: &str,
        new_term: &str,
        new_aliases: Vec<String>,
        new_category: LexiconCategory,
        new_weight: i32,
    ) {
        self.lexicon
            .update_entry(id, new_term, new_aliases, new_category, new_weight);
        self.emit_state_changed();
    }
    pub fn remove_lexicon_entry(&self, id: &str) {
        self.lexicon.remove(id);
        self.emit_state_changed();
    }
    pub fn remove_lexicon_batch(&self, ids: Vec<String>) {
        let set: HashSet<String> = ids.into_iter().collect();
        self.lexicon.remove_batch(&set);
        self.emit_state_changed();
    }
}
