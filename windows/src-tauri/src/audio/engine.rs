use crate::audio::dsp::{
    apply_streaming_whisper_agc, boost_quiet_speech_agc, calculate_rms_metrics, downmix_to_mono,
    resample_float_to_16khz_int16, AudioLevelBus,
};
use crate::audio::openai_asr::OpenAITranscriptionClient;
use crate::audio::sherpa_ffi::{
    locate_sherpa_runtime_library, sense_voice_model_paths, SenseVoiceRecognizer,
};
use crate::audio::volc_asr::VolcSeedASRClient;
use crate::core::polish::PolishEngine;
use crate::models::ASRProviderOption;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use parking_lot::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

#[derive(Clone)]
pub struct ASREngineConfig {
    pub asr_provider: ASRProviderOption,
    pub volc_speech_api_key: String,
    pub openai_asr_base_url: String,
    pub openai_asr_model: String,
    pub openai_asr_api_key: String,
    pub enable_whisper_agc: bool,
}

impl Default for ASREngineConfig {
    fn default() -> Self {
        Self {
            asr_provider: ASRProviderOption::VolcSeedASR,
            volc_speech_api_key: String::new(),
            openai_asr_base_url: "https://api.openai.com/v1".to_string(),
            openai_asr_model: "gpt-4o-mini-transcribe".to_string(),
            openai_asr_api_key: String::new(),
            enable_whisper_agc: true,
        }
    }
}

pub type PartialCallback = Arc<dyn Fn(String, bool) + Send + Sync>;
pub type NoticeCallback = Arc<dyn Fn(String) + Send + Sync>;

struct CaptureState {
    is_capture_active: bool,
    active_uses_volc_cloud: bool,
    active_uses_openai_cloud: bool,
    current_sample_rate: u32,
    pre_roll_samples: Vec<f32>,
    active_segment_samples: Vec<f32>,
    cloud_failover_backup_samples: Vec<f32>,
    active_max_backup_samples: usize,
    frozen_transcript_prefix: String,
    latest_transcript: String,
    last_decoded_sample_count: usize,
    last_decoded_voice_mark: usize,
    total_voice_samples_in_segment: usize,
    consecutive_silent_samples: usize,
    has_detected_speech_in_segment: bool,
    has_detected_speech_overall: bool,
    did_flush_micro_pause_tail: bool,
    is_decoding_chunk: bool,
    open_ai_hotwords: Vec<String>,
    open_ai_locale: String,
    session_start: Instant,
    last_activity_at: Instant,
}

impl Default for CaptureState {
    fn default() -> Self {
        let now = Instant::now();
        Self {
            is_capture_active: false,
            active_uses_volc_cloud: false,
            active_uses_openai_cloud: false,
            current_sample_rate: 48_000,
            pre_roll_samples: Vec::new(),
            active_segment_samples: Vec::new(),
            cloud_failover_backup_samples: Vec::new(),
            active_max_backup_samples: 48_000 * 90,
            frozen_transcript_prefix: String::new(),
            latest_transcript: String::new(),
            last_decoded_sample_count: 0,
            last_decoded_voice_mark: 0,
            total_voice_samples_in_segment: 0,
            consecutive_silent_samples: 0,
            has_detected_speech_in_segment: false,
            has_detected_speech_overall: false,
            did_flush_micro_pause_tail: false,
            is_decoding_chunk: false,
            open_ai_hotwords: Vec::new(),
            open_ai_locale: "zh-CN".to_string(),
            session_start: now,
            last_activity_at: now,
        }
    }
}

/// Dedicated audio hardware owner thread (cpal::Stream is !Send on Windows WASAPI).
enum MicThreadCmd {
    EnsureRunning,
}

/// Triple-Engine Streaming ASR Subsystem:
/// 1. Volcengine Doubao Seed-ASR 2.0 (binary WS streaming + Top-65 hotwords)
/// 2. OpenAI / Groq Cloud Speech LLM (`/v1/audio/transcriptions`)
/// 3. Local `sherpa-onnx` SenseVoice FP32 (886MB lossless, 0-drop offline failover + VAD sliding window)
/// Plus Windows WASAPI hot-mic with 220ms pre-roll & 15s idle auto-shutdown.
pub struct StreamingASREngine {
    config: Arc<Mutex<ASREngineConfig>>,
    capture: Arc<Mutex<CaptureState>>,
    seed_client: Arc<VolcSeedASRClient>,
    openai_client: Arc<OpenAITranscriptionClient>,
    recognizer: Arc<Mutex<Option<SenseVoiceRecognizer>>>,
    mic_cmd_tx: Mutex<Option<std::sync::mpsc::Sender<MicThreadCmd>>>,
    is_sensevoice_loaded: Arc<AtomicBool>,
    is_full_fp32: Arc<AtomicBool>,
    on_partial: Arc<Mutex<Option<PartialCallback>>>,
    on_failover_notice: Arc<Mutex<Option<NoticeCallback>>>,
    on_error: Arc<Mutex<Option<NoticeCallback>>>,
    vad_cancel: Arc<Mutex<Option<Arc<AtomicBool>>>>,
}

impl Default for StreamingASREngine {
    fn default() -> Self {
        Self::new()
    }
}

impl StreamingASREngine {
    pub fn new() -> Self {
        let engine = Self {
            config: Arc::new(Mutex::new(ASREngineConfig::default())),
            capture: Arc::new(Mutex::new(CaptureState::default())),
            seed_client: Arc::new(VolcSeedASRClient::new()),
            openai_client: Arc::new(OpenAITranscriptionClient::new()),
            recognizer: Arc::new(Mutex::new(None)),
            mic_cmd_tx: Mutex::new(None),
            is_sensevoice_loaded: Arc::new(AtomicBool::new(false)),
            is_full_fp32: Arc::new(AtomicBool::new(false)),
            on_partial: Arc::new(Mutex::new(None)),
            on_failover_notice: Arc::new(Mutex::new(None)),
            on_error: Arc::new(Mutex::new(None)),
            vad_cancel: Arc::new(Mutex::new(None)),
        };
        engine.spawn_mic_owner_thread();
        engine
    }

    pub fn set_callbacks(
        &self,
        on_partial: PartialCallback,
        on_failover_notice: NoticeCallback,
        on_error: NoticeCallback,
    ) {
        *self.on_partial.lock() = Some(on_partial);
        *self.on_failover_notice.lock() = Some(on_failover_notice);
        *self.on_error.lock() = Some(on_error);
    }

    pub fn update_config(&self, cfg: ASREngineConfig) {
        *self.config.lock() = cfg;
    }

    pub fn is_microphone_available() -> bool {
        let host = cpal::default_host();
        host.default_input_device().is_some()
    }

    pub fn is_using_sense_voice(&self) -> bool {
        self.is_sensevoice_loaded.load(Ordering::Relaxed)
    }

    pub fn is_full_precision_fp32(&self) -> bool {
        self.is_full_fp32.load(Ordering::Relaxed)
    }

    pub fn is_sherpa_runtime_available() -> bool {
        locate_sherpa_runtime_library().is_some()
    }

    pub fn active_session_uses_cloud_seed_asr(&self) -> bool {
        self.capture.lock().active_uses_volc_cloud
    }

    pub fn active_session_uses_openai_asr(&self) -> bool {
        self.capture.lock().active_uses_openai_cloud
    }

    pub fn active_session_uses_any_cloud_asr(&self) -> bool {
        let g = self.capture.lock();
        g.active_uses_volc_cloud || g.active_uses_openai_cloud
    }

    pub fn load_sense_voice_async(&self, on_ready: Option<Arc<dyn Fn() + Send + Sync>>) {
        let rec_lock = Arc::clone(&self.recognizer);
        let loaded_flag = Arc::clone(&self.is_sensevoice_loaded);
        let fp32_flag = Arc::clone(&self.is_full_fp32);

        std::thread::spawn(move || {
            {
                let guard = rec_lock.lock();
                if guard.is_some() {
                    loaded_flag.store(true, Ordering::SeqCst);
                    return;
                }
            }
            if let Some(loaded) = SenseVoiceRecognizer::load_if_available() {
                let fp32 = loaded.is_full_fp32;
                *rec_lock.lock() = Some(loaded);
                loaded_flag.store(true, Ordering::SeqCst);
                fp32_flag.store(fp32, Ordering::SeqCst);
                if let Some(cb) = on_ready {
                    cb();
                }
            }
        });
    }

    pub fn prewarm_cloud_socket_if_ready(&self) {
        let cfg = self.config.lock().clone();
        match cfg.asr_provider {
            ASRProviderOption::VolcSeedASR => {
                if !cfg.volc_speech_api_key.trim().is_empty() {
                    self.seed_client
                        .prewarm_standby_socket(&cfg.volc_speech_api_key);
                }
            }
            ASRProviderOption::OpenAIWhisper => {
                if !cfg.openai_asr_api_key.trim().is_empty()
                    || PolishEngine::is_keyless_local_endpoint(&cfg.openai_asr_base_url)
                {
                    self.openai_client
                        .prewarm_connection(&cfg.openai_asr_base_url, &cfg.openai_asr_api_key);
                }
            }
            ASRProviderOption::LocalSenseVoice => {}
        }
    }

    pub fn prewarm_hot_mic(&self) {
        if let Some(tx) = self.mic_cmd_tx.lock().as_ref() {
            let _ = tx.send(MicThreadCmd::EnsureRunning);
        }
    }

    fn spawn_mic_owner_thread(&self) {
        let (tx, rx) = std::sync::mpsc::channel::<MicThreadCmd>();
        *self.mic_cmd_tx.lock() = Some(tx);

        let capture = Arc::clone(&self.capture);
        let config = Arc::clone(&self.config);
        let seed_client = Arc::clone(&self.seed_client);

        std::thread::Builder::new()
            .name("typezero-wasapi-mic".to_string())
            .spawn(move || {
                let mut active_stream: Option<cpal::Stream> = None;

                loop {
                    let cmd = match rx.recv_timeout(Duration::from_secs(2)) {
                        Ok(c) => Some(c),
                        Err(std::sync::mpsc::RecvTimeoutError::Timeout) => None,
                        Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                    };

                    if let Some(c) = cmd {
                        match c {
                            MicThreadCmd::EnsureRunning => {
                                if active_stream.is_none() {
                                    active_stream = Self::open_input_stream(
                                        Arc::clone(&capture),
                                        Arc::clone(&config),
                                        Arc::clone(&seed_client),
                                    );
                                }
                                capture.lock().last_activity_at = Instant::now();
                            }
                        }
                    }

                    // Auto-shutdown hot mic after 15s idle so Windows taskbar mic privacy indicator turns off cleanly!
                    if active_stream.is_some() {
                        let g = capture.lock();
                        if !g.is_capture_active
                            && g.last_activity_at.elapsed() >= Duration::from_secs(15)
                        {
                            drop(g);
                            active_stream = None;
                            capture.lock().pre_roll_samples.clear();
                        }
                    }
                }
            })
            .ok();
    }

    fn open_input_stream(
        capture: Arc<Mutex<CaptureState>>,
        config: Arc<Mutex<ASREngineConfig>>,
        seed_client: Arc<VolcSeedASRClient>,
    ) -> Option<cpal::Stream> {
        let host = cpal::default_host();
        let device = host.default_input_device()?;
        let default_cfg = device.default_input_config().ok()?;
        let sample_rate = default_cfg.sample_rate().0;
        let channels = default_cfg.channels() as usize;
        let stream_cfg: cpal::StreamConfig = default_cfg.clone().into();

        {
            let mut g = capture.lock();
            if g.current_sample_rate != sample_rate {
                g.current_sample_rate = sample_rate;
                g.pre_roll_samples.clear();
            }
        }

        let handle_mono = move |mono: &[f32]| {
            if mono.is_empty() {
                return;
            }
            let (is_capturing, currently_volc, currently_openai, max_backup, sr) = {
                let mut g = capture.lock();
                if !g.is_capture_active {
                    let max_pre_roll = ((g.current_sample_rate as f64) * 0.22) as usize;
                    g.pre_roll_samples.extend_from_slice(mono);
                    if g.pre_roll_samples.len() > max_pre_roll.max(1600) {
                        let drop_n = g.pre_roll_samples.len() - max_pre_roll.max(1600);
                        g.pre_roll_samples.drain(..drop_n);
                    }
                    return;
                }
                (
                    g.is_capture_active,
                    g.active_uses_volc_cloud,
                    g.active_uses_openai_cloud,
                    g.active_max_backup_samples,
                    g.current_sample_rate,
                )
            };
            if !is_capturing {
                return;
            }

            let enable_agc = config.lock().enable_whisper_agc;
            let (norm_level, raw_rms) = calculate_rms_metrics(mono);
            AudioLevelBus::shared().push(norm_level);

            let voice_threshold = if enable_agc { 0.0024 } else { 0.0080 };
            let is_voice_frame = raw_rms > voice_threshold;
            let currently_any_cloud = currently_volc || currently_openai;
            let mut virtual_openai_pulse: Option<usize> = None;

            {
                let mut g = capture.lock();
                if !g.is_capture_active {
                    return;
                }
                if !currently_openai {
                    g.active_segment_samples.extend_from_slice(mono);
                }
                if currently_any_cloud && g.cloud_failover_backup_samples.len() < max_backup {
                    g.cloud_failover_backup_samples.extend_from_slice(mono);
                }
                if is_voice_frame {
                    g.has_detected_speech_in_segment = true;
                    g.has_detected_speech_overall = true;
                    g.did_flush_micro_pause_tail = false;
                    g.total_voice_samples_in_segment += mono.len();
                    g.consecutive_silent_samples = 0;
                    if currently_openai {
                        let step = (sr as usize / 5).max(1);
                        virtual_openai_pulse = Some((g.total_voice_samples_in_segment / step).max(1));
                    }
                } else {
                    g.consecutive_silent_samples += mono.len();
                    let max_idle_pre = (sr as usize) / 4;
                    if !currently_openai
                        && !g.has_detected_speech_in_segment
                        && g.active_segment_samples.len() > max_idle_pre
                    {
                        let excess = g.active_segment_samples.len() - max_idle_pre;
                        g.active_segment_samples.drain(..excess);
                    }
                    if currently_any_cloud
                        && !g.has_detected_speech_overall
                        && g.cloud_failover_backup_samples.len() > max_idle_pre
                    {
                        let excess = g.cloud_failover_backup_samples.len() - max_idle_pre;
                        g.cloud_failover_backup_samples.drain(..excess);
                    }
                }
            }

            if let Some(pulse) = virtual_openai_pulse {
                AudioLevelBus::shared().push_recognized_count(pulse);
            }

            if currently_volc {
                let conditioned = if enable_agc {
                    apply_streaming_whisper_agc(mono, raw_rms, is_voice_frame)
                } else {
                    mono.to_vec()
                };
                let pcm16 = resample_float_to_16khz_int16(&conditioned, sr as f64);
                if !pcm16.is_empty() {
                    seed_client.append_pcm16_samples(&pcm16);
                }
            }
        };

        let stream = match default_cfg.sample_format() {
            cpal::SampleFormat::F32 => device
                .build_input_stream(
                    &stream_cfg,
                    move |data: &[f32], _| {
                        let mono = downmix_to_mono(data, channels);
                        handle_mono(&mono);
                    },
                    |err| tracing::warn!("WASAPI audio stream error: {err}"),
                    None,
                )
                .ok()?,
            cpal::SampleFormat::I16 => device
                .build_input_stream(
                    &stream_cfg,
                    move |data: &[i16], _| {
                        let floats: Vec<f32> = data.iter().map(|&s| s as f32 / 32768.0).collect();
                        let mono = downmix_to_mono(&floats, channels);
                        handle_mono(&mono);
                    },
                    |err| tracing::warn!("WASAPI audio stream error: {err}"),
                    None,
                )
                .ok()?,
            cpal::SampleFormat::U16 => device
                .build_input_stream(
                    &stream_cfg,
                    move |data: &[u16], _| {
                        let floats: Vec<f32> = data
                            .iter()
                            .map(|&s| (s as f32 - 32768.0) / 32768.0)
                            .collect();
                        let mono = downmix_to_mono(&floats, channels);
                        handle_mono(&mono);
                    },
                    |err| tracing::warn!("WASAPI audio stream error: {err}"),
                    None,
                )
                .ok()?,
            _ => return None,
        };

        stream.play().ok()?;
        Some(stream)
    }

    pub fn start_streaming(
        &self,
        locale: &str,
        contextual_strings: &[String],
        dialog_context: &[String],
    ) -> Result<(), String> {
        self.stop_background_timers();

        if !Self::is_microphone_available() {
            return Err("未检测到可用麦克风，请在 Windows「设置 → 隐私和安全性 → 麦克风」中允许 TypeZero".to_string());
        }

        let cfg = self.config.lock().clone();
        let clean_volc = cfg.volc_speech_api_key.trim().to_string();
        let clean_openai = cfg.openai_asr_api_key.trim().to_string();
        let want_volc = cfg.asr_provider == ASRProviderOption::VolcSeedASR && !clean_volc.is_empty();
        let want_openai = cfg.asr_provider == ASRProviderOption::OpenAIWhisper
            && (!clean_openai.is_empty()
                || PolishEngine::is_keyless_local_endpoint(&cfg.openai_asr_base_url));
        let has_local = self.is_using_sense_voice();

        if !want_volc && !want_openai && !has_local {
            return Err("尚未配置云端语音 API Key 且未安装本机离线模型，请先在「引擎与快捷键」页完成配置".to_string());
        }

        self.prewarm_hot_mic();

        let (pre_roll, hw_rate) = {
            let mut g = self.capture.lock();
            let sr = g.current_sample_rate.max(16_000);
            let max_inject = ((sr as f64) * 0.18) as usize;
            let pre = if g.pre_roll_samples.len() > max_inject.max(800) {
                g.pre_roll_samples[g.pre_roll_samples.len() - max_inject.max(800)..].to_vec()
            } else {
                g.pre_roll_samples.clone()
            };
            g.pre_roll_samples.clear();

            let is_any_cloud = want_volc || want_openai;
            g.active_max_backup_samples = (sr as usize) * if want_openai { 180 } else { 90 };
            g.active_uses_volc_cloud = want_volc;
            g.active_uses_openai_cloud = want_openai;
            g.open_ai_hotwords = if want_openai {
                contextual_strings.to_vec()
            } else {
                Vec::new()
            };
            g.open_ai_locale = locale.to_string();
            g.active_segment_samples.clear();
            g.cloud_failover_backup_samples.clear();
            if !pre.is_empty() {
                if !want_openai {
                    g.active_segment_samples.extend_from_slice(&pre);
                }
                if is_any_cloud {
                    g.cloud_failover_backup_samples.extend_from_slice(&pre);
                }
            }
            g.frozen_transcript_prefix.clear();
            g.latest_transcript.clear();
            g.last_decoded_sample_count = 0;
            g.last_decoded_voice_mark = 0;
            g.total_voice_samples_in_segment = 0;
            g.consecutive_silent_samples = 0;
            g.has_detected_speech_in_segment = false;
            g.has_detected_speech_overall = false;
            g.did_flush_micro_pause_tail = false;
            g.is_decoding_chunk = false;
            g.session_start = Instant::now();
            g.last_activity_at = Instant::now();
            g.is_capture_active = true;
            (pre, sr)
        };

        if want_volc {
            let cap_for_cb = Arc::clone(&self.capture);
            let partial_cb_holder = Arc::clone(&self.on_partial);
            let partial_cb_for_fail = Arc::clone(&self.on_partial);
            let cap_for_fail = Arc::clone(&self.capture);
            let notice_holder = Arc::clone(&self.on_failover_notice);
            let rec_holder = Arc::clone(&self.recognizer);
            let cfg_holder = Arc::clone(&self.config);
            let seed_for_fail = Arc::clone(&self.seed_client);
            let vad_cancel_holder = Arc::clone(&self.vad_cancel);

            self.seed_client.start_session(
                &clean_volc,
                contextual_strings,
                dialog_context,
                move |text, is_def| {
                    let should_emit = {
                        let mut g = cap_for_cb.lock();
                        if !g.is_capture_active || !g.active_uses_volc_cloud {
                            return;
                        }
                        g.did_flush_micro_pause_tail = is_def;
                        if text != g.latest_transcript || is_def {
                            g.latest_transcript = text.clone();
                            true
                        } else {
                            false
                        }
                    };
                    if should_emit {
                        if let Some(cb) = partial_cb_holder.lock().as_ref() {
                            cb(text, is_def);
                        }
                    }
                },
                move |reason| {
                    Self::switch_cloud_to_local_fp32(
                        &cap_for_fail,
                        &seed_for_fail,
                        &rec_holder,
                        &cfg_holder,
                        &partial_cb_for_fail,
                        &notice_holder,
                        &vad_cancel_holder,
                        reason,
                    );
                },
            );

            if !pre_roll.is_empty() {
                let pre_pcm = resample_float_to_16khz_int16(&pre_roll, hw_rate as f64);
                if !pre_pcm.is_empty() {
                    self.seed_client.append_pcm16_samples(&pre_pcm);
                }
            }
            self.start_cloud_watchdog_loop();
        } else if want_openai {
            self.openai_client
                .prewarm_connection(&cfg.openai_asr_base_url, &clean_openai);
        } else {
            self.start_local_vad_loop();
        }

        Ok(())
    }

    fn stop_background_timers(&self) {
        if let Some(flag) = self.vad_cancel.lock().take() {
            flag.store(true, Ordering::SeqCst);
        }
    }

    fn start_cloud_watchdog_loop(&self) {
        let cancel = Arc::new(AtomicBool::new(false));
        *self.vad_cancel.lock() = Some(Arc::clone(&cancel));

        let capture = Arc::clone(&self.capture);
        let seed = Arc::clone(&self.seed_client);
        let recognizer = Arc::clone(&self.recognizer);
        let config = Arc::clone(&self.config);
        let on_partial = Arc::clone(&self.on_partial);
        let on_notice = Arc::clone(&self.on_failover_notice);
        let vad_cancel = Arc::clone(&self.vad_cancel);

        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(Duration::from_millis(110));
            while !cancel.load(Ordering::Relaxed) {
                ticker.tick().await;
                let (active_volc, silence_sec, voice_sec, flush_text) = {
                    let mut g = capture.lock();
                    if !g.is_capture_active || !g.active_uses_volc_cloud {
                        break;
                    }
                    let sr = g.current_sample_rate.max(1) as f64;
                    let silence = g.consecutive_silent_samples as f64 / sr;
                    let voice = g.total_voice_samples_in_segment as f64 / sr;
                    let flush = if g.has_detected_speech_overall
                        && silence >= 0.20
                        && !g.did_flush_micro_pause_tail
                        && !g.latest_transcript.is_empty()
                    {
                        g.did_flush_micro_pause_tail = true;
                        Some(g.latest_transcript.clone())
                    } else {
                        None
                    };
                    (g.active_uses_volc_cloud, silence, voice, flush)
                };
                if !active_volc {
                    break;
                }
                let _ = silence_sec;

                // Dead-Wi-Fi 1.5s Watchdog -> 0-word-loss switch to local 886MB SenseVoice FP32!
                if voice_sec >= 1.50
                    && !seed.has_received_any_server_frame()
                    && recognizer.lock().is_some()
                {
                    Self::switch_cloud_to_local_fp32(
                        &capture,
                        &seed,
                        &recognizer,
                        &config,
                        &on_partial,
                        &on_notice,
                        &vad_cancel,
                        "弱网超时，已自动无损切回本机满血模型".to_string(),
                    );
                    break;
                }

                if let Some(txt) = flush_text {
                    if let Some(cb) = on_partial.lock().as_ref() {
                        cb(txt, true);
                    }
                }
            }
        });
    }

    #[allow(clippy::too_many_arguments)]
    fn switch_cloud_to_local_fp32(
        capture: &Arc<Mutex<CaptureState>>,
        seed: &Arc<VolcSeedASRClient>,
        recognizer: &Arc<Mutex<Option<SenseVoiceRecognizer>>>,
        config: &Arc<Mutex<ASREngineConfig>>,
        on_partial: &Arc<Mutex<Option<PartialCallback>>>,
        on_notice: &Arc<Mutex<Option<NoticeCallback>>>,
        vad_cancel: &Arc<Mutex<Option<Arc<AtomicBool>>>>,
        reason: String,
    ) {
        {
            let mut g = capture.lock();
            if !g.active_uses_volc_cloud {
                return;
            }
            g.active_uses_volc_cloud = false;
            if !g.cloud_failover_backup_samples.is_empty() {
                g.active_segment_samples = std::mem::take(&mut g.cloud_failover_backup_samples);
            }
        }
        seed.stop_and_reset();

        if recognizer.lock().is_some() && capture.lock().is_capture_active {
            Self::spawn_local_vad_loop(
                Arc::clone(capture),
                Arc::clone(recognizer),
                Arc::clone(config),
                Arc::clone(on_partial),
                Arc::clone(vad_cancel),
            );
        }

        if let Some(cb) = on_notice.lock().as_ref() {
            cb(reason);
        }
    }

    fn start_local_vad_loop(&self) {
        Self::spawn_local_vad_loop(
            Arc::clone(&self.capture),
            Arc::clone(&self.recognizer),
            Arc::clone(&self.config),
            Arc::clone(&self.on_partial),
            Arc::clone(&self.vad_cancel),
        );
    }

    fn spawn_local_vad_loop(
        capture: Arc<Mutex<CaptureState>>,
        recognizer: Arc<Mutex<Option<SenseVoiceRecognizer>>>,
        config: Arc<Mutex<ASREngineConfig>>,
        on_partial: Arc<Mutex<Option<PartialCallback>>>,
        vad_cancel: Arc<Mutex<Option<Arc<AtomicBool>>>>,
    ) {
        let cancel = Arc::new(AtomicBool::new(false));
        if let Some(prev) = vad_cancel.lock().replace(Arc::clone(&cancel)) {
            prev.store(true, Ordering::SeqCst);
        }

        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(Duration::from_millis(58));
            while !cancel.load(Ordering::Relaxed) {
                ticker.tick().await;
                enum VadAction {
                    None,
                    FlushMicroPause(String),
                    SealSegment {
                        samples: Vec<f32>,
                        sr: i32,
                        was_long_pause: bool,
                    },
                    LiveDecode {
                        samples: Vec<f32>,
                        sr: i32,
                        prefix_copy: String,
                        voice_mark: usize,
                    },
                }

                let action = {
                    let mut g = capture.lock();
                    if !g.is_capture_active {
                        break;
                    }
                    if g.is_decoding_chunk {
                        VadAction::None
                    } else {
                        let sr = g.current_sample_rate.max(1) as usize;
                        let total = g.active_segment_samples.len();
                        let seg_sec = total as f64 / sr as f64;
                        let sil_sec = g.consecutive_silent_samples as f64 / sr as f64;

                        let should_seal = g.has_detected_speech_in_segment
                            && ((seg_sec >= 4.8 && sil_sec >= 0.72)
                                || (seg_sec >= 9.5 && sil_sec >= 0.25)
                                || seg_sec >= 14.5);

                        if should_seal {
                            g.is_decoding_chunk = true;
                            let seg = g.active_segment_samples.clone();
                            let tail_keep = total.min(sr / 10);
                            g.active_segment_samples =
                                g.active_segment_samples[total - tail_keep..].to_vec();
                            g.last_decoded_sample_count = 0;
                            g.last_decoded_voice_mark = 0;
                            g.total_voice_samples_in_segment = 0;
                            g.has_detected_speech_in_segment = false;
                            g.did_flush_micro_pause_tail = false;
                            g.consecutive_silent_samples = 0;
                            VadAction::SealSegment {
                                samples: seg,
                                sr: sr as i32,
                                was_long_pause: sil_sec >= 0.72,
                            }
                        } else if g.has_detected_speech_in_segment
                            && sil_sec >= 0.185
                            && !g.did_flush_micro_pause_tail
                            && !g.latest_transcript.is_empty()
                        {
                            g.did_flush_micro_pause_tail = true;
                            VadAction::FlushMicroPause(g.latest_transcript.clone())
                        } else if g.has_detected_speech_in_segment
                            && total >= sr / 9
                            && total.saturating_sub(g.last_decoded_sample_count) >= sr / 18
                        {
                            g.is_decoding_chunk = true;
                            g.last_decoded_sample_count = total;
                            VadAction::LiveDecode {
                                samples: g.active_segment_samples.clone(),
                                sr: sr as i32,
                                prefix_copy: g.frozen_transcript_prefix.clone(),
                                voice_mark: g.total_voice_samples_in_segment,
                            }
                        } else {
                            VadAction::None
                        }
                    }
                };

                let apply_agc = config.lock().enable_whisper_agc;
                match action {
                    VadAction::None => {}
                    VadAction::FlushMicroPause(cached) => {
                        if let Some(cb) = on_partial.lock().as_ref() {
                            cb(cached, true);
                        }
                    }
                    VadAction::SealSegment {
                        samples,
                        sr,
                        was_long_pause,
                    } => {
                        let rec = Arc::clone(&recognizer);
                        let seg_text = tokio::task::spawn_blocking(move || {
                            let processed = if apply_agc {
                                boost_quiet_speech_agc(&samples)
                            } else {
                                samples
                            };
                            rec.lock()
                                .as_ref()
                                .map(|r| r.transcribe(&processed, sr))
                                .unwrap_or_default()
                        })
                        .await
                        .unwrap_or_default();

                        let combined = {
                            let mut g = capture.lock();
                            if !seg_text.is_empty() {
                                g.frozen_transcript_prefix.push_str(&seg_text);
                                if was_long_pause {
                                    if let Some(last) = seg_text.chars().last() {
                                        if !"。！？；，,.;!?".contains(last) {
                                            g.frozen_transcript_prefix.push('，');
                                        }
                                    }
                                }
                            }
                            g.is_decoding_chunk = false;
                            let full = g.frozen_transcript_prefix.clone();
                            if g.is_capture_active && !full.is_empty() {
                                g.latest_transcript = full.clone();
                                Some(full)
                            } else {
                                None
                            }
                        };
                        if let Some(text) = combined {
                            if let Some(cb) = on_partial.lock().as_ref() {
                                cb(text, true);
                            }
                        }
                    }
                    VadAction::LiveDecode {
                        samples,
                        sr,
                        prefix_copy,
                        voice_mark,
                    } => {
                        let rec = Arc::clone(&recognizer);
                        let active_text = tokio::task::spawn_blocking(move || {
                            let processed = if apply_agc {
                                boost_quiet_speech_agc(&samples)
                            } else {
                                samples
                            };
                            rec.lock()
                                .as_ref()
                                .map(|r| r.transcribe(&processed, sr))
                                .unwrap_or_default()
                        })
                        .await
                        .unwrap_or_default();

                        let emit = {
                            let mut g = capture.lock();
                            g.is_decoding_chunk = false;
                            if g.frozen_transcript_prefix == prefix_copy {
                                g.last_decoded_voice_mark = voice_mark;
                                if g.is_capture_active && !active_text.is_empty() {
                                    let combined =
                                        format!("{}{}", g.frozen_transcript_prefix, active_text);
                                    if combined != g.latest_transcript {
                                        g.latest_transcript = combined.clone();
                                        Some(combined)
                                    } else {
                                        None
                                    }
                                } else {
                                    None
                                }
                            } else {
                                None
                            }
                        };
                        if let Some(text) = emit {
                            if let Some(cb) = on_partial.lock().as_ref() {
                                cb(text, false);
                            }
                        }
                    }
                }
            }
        });
    }

    pub async fn finish_streaming(&self) -> (String, f64) {
        self.stop_background_timers();
        AudioLevelBus::shared().reset();

        let (
            elapsed,
            was_volc,
            was_openai,
            had_speech,
            backup_samples,
            backup_sr,
            openai_hotwords,
            openai_locale,
            latest_cached,
        ) = {
            let mut g = self.capture.lock();
            g.is_capture_active = false;
            g.last_activity_at = Instant::now();
            let elapsed = g.session_start.elapsed().as_secs_f64().max(0.2);
            let was_volc = g.active_uses_volc_cloud;
            let was_openai = g.active_uses_openai_cloud;
            g.active_uses_volc_cloud = false;
            g.active_uses_openai_cloud = false;
            let had_speech = g.has_detected_speech_overall;
            let backup = std::mem::take(&mut g.cloud_failover_backup_samples);
            let sr = g.current_sample_rate.max(16_000);
            let hw = std::mem::take(&mut g.open_ai_hotwords);
            let loc = g.open_ai_locale.clone();
            let cached = g.latest_transcript.trim().to_string();
            (elapsed, was_volc, was_openai, had_speech, backup, sr, hw, loc, cached)
        };

        let cfg = self.config.lock().clone();

        // 1. OpenAI / Groq Cloud Speech
        if was_openai {
            if !had_speech || backup_samples.len() <= (backup_sr as usize) / 8 {
                self.clear_session_buffers();
                return (String::new(), elapsed);
            }
            let backup_for_wav = backup_samples.clone();
            let agc = cfg.enable_whisper_agc;
            let wav_data = tokio::task::spawn_blocking(move || {
                let conditioned = if agc {
                    boost_quiet_speech_agc(&backup_for_wav)
                } else {
                    backup_for_wav
                };
                let pcm16 = resample_float_to_16khz_int16(&conditioned, backup_sr as f64);
                OpenAITranscriptionClient::encode_pcm16_to_wav(&pcm16, 16_000)
            })
            .await
            .unwrap_or_default();

            let dynamic_timeout = (elapsed * 0.45 + 5.5).clamp(6.5, 14.0);
            match self
                .openai_client
                .transcribe(
                    wav_data,
                    &cfg.openai_asr_base_url,
                    &cfg.openai_asr_model,
                    &cfg.openai_asr_api_key,
                    &openai_hotwords,
                    Some(&openai_locale),
                    dynamic_timeout,
                )
                .await
            {
                Ok((txt, _)) if !txt.trim().is_empty() => {
                    self.clear_session_buffers();
                    return (txt.trim().to_string(), elapsed);
                }
                Ok(_) => {
                    self.clear_session_buffers();
                    return (String::new(), elapsed);
                }
                Err(err) => {
                    // Seamless zero-word-loss failover to local 886MB SenseVoice FP32!
                    if self.is_using_sense_voice() && backup_samples.len() > (backup_sr as usize) / 10
                    {
                        let rec = Arc::clone(&self.recognizer);
                        let local_fallback = tokio::task::spawn_blocking(move || {
                            let processed = if agc {
                                boost_quiet_speech_agc(&backup_samples)
                            } else {
                                backup_samples
                            };
                            rec.lock()
                                .as_ref()
                                .map(|r| r.transcribe(&processed, backup_sr as i32))
                                .unwrap_or_default()
                        })
                        .await
                        .unwrap_or_default();
                        self.clear_session_buffers();
                        if !local_fallback.is_empty() {
                            if let Some(cb) = self.on_failover_notice.lock().as_ref() {
                                cb(format!("云端语音回包异常（{err}），已由本机满血 FP32 模型无缝兜底"));
                            }
                            return (local_fallback, elapsed);
                        }
                    }
                    self.clear_session_buffers();
                    if let Some(cb) = self.on_error.lock().as_ref() {
                        cb(format!("云端语音识别失败：{err}"));
                    }
                    return (String::new(), elapsed);
                }
            }
        }

        // 2. Volcengine Doubao Seed-ASR 2.0
        if was_volc {
            if !had_speech && latest_cached.is_empty() {
                self.seed_client.stop_and_reset();
                self.clear_session_buffers();
                return (String::new(), elapsed);
            }
            if let Some(cloud_final) = self.seed_client.finish_and_await_final_transcript(1200).await
            {
                let trimmed = cloud_final.trim().to_string();
                if !trimmed.is_empty() {
                    self.clear_session_buffers();
                    self.prewarm_cloud_socket_if_ready();
                    return (trimmed, elapsed);
                }
            }
            // Seamless failover to local SenseVoice FP32 on drop/timeout!
            if had_speech
                && self.is_using_sense_voice()
                && backup_samples.len() > (backup_sr as usize) / 10
            {
                let rec = Arc::clone(&self.recognizer);
                let agc = cfg.enable_whisper_agc;
                let local_fallback = tokio::task::spawn_blocking(move || {
                    let processed = if agc {
                        boost_quiet_speech_agc(&backup_samples)
                    } else {
                        backup_samples
                    };
                    rec.lock()
                        .as_ref()
                        .map(|r| r.transcribe(&processed, backup_sr as i32))
                        .unwrap_or_default()
                })
                .await
                .unwrap_or_default();
                self.clear_session_buffers();
                if !local_fallback.is_empty() {
                    if let Some(cb) = self.on_failover_notice.lock().as_ref() {
                        cb("云端回包超时，已由本机满血 FP32 模型无缝兜底".to_string());
                    }
                    return (local_fallback, elapsed);
                }
            }
            self.clear_session_buffers();
            return (latest_cached, elapsed);
        }

        // 3. Local SenseVoice FP32 final tail decode
        if self.is_using_sense_voice() {
            let (remaining, needs_decode, cached_full, sr) = {
                let mut g = self.capture.lock();
                let sr = g.current_sample_rate.max(16_000);
                let undecoded = g
                    .total_voice_samples_in_segment
                    .saturating_sub(g.last_decoded_voice_mark);
                let needs = g.has_detected_speech_in_segment
                    && (undecoded > (sr as usize) / 16 || g.latest_transcript.is_empty());
                let cached = g.latest_transcript.trim().to_string();
                let rem = std::mem::take(&mut g.active_segment_samples);
                g.has_detected_speech_in_segment = false;
                g.last_decoded_voice_mark = 0;
                g.total_voice_samples_in_segment = 0;
                (rem, needs, cached, sr)
            };

            if !needs_decode && !cached_full.is_empty() {
                self.clear_session_buffers();
                return (cached_full, elapsed);
            }

            let rec = Arc::clone(&self.recognizer);
            let agc = cfg.enable_whisper_agc;
            let tail_text = if needs_decode && remaining.len() > (sr as usize) / 10 {
                tokio::task::spawn_blocking(move || {
                    let processed = if agc {
                        boost_quiet_speech_agc(&remaining)
                    } else {
                        remaining
                    };
                    rec.lock()
                        .as_ref()
                        .map(|r| r.transcribe(&processed, sr as i32))
                        .unwrap_or_default()
                })
                .await
                .unwrap_or_default()
            } else {
                String::new()
            };

            let prefix = std::mem::take(&mut self.capture.lock().frozen_transcript_prefix);
            let merged = format!("{prefix}{tail_text}").trim().to_string();
            self.clear_session_buffers();
            return (if merged.is_empty() { cached_full } else { merged }, elapsed);
        }

        self.clear_session_buffers();
        (latest_cached, elapsed)
    }

    pub fn cancel(&self) {
        self.stop_background_timers();
        self.seed_client.stop_and_reset();
        AudioLevelBus::shared().reset();
        let mut g = self.capture.lock();
        g.is_capture_active = false;
        g.last_activity_at = Instant::now();
        drop(g);
        self.clear_session_buffers();
    }

    fn clear_session_buffers(&self) {
        let mut g = self.capture.lock();
        g.active_uses_volc_cloud = false;
        g.active_uses_openai_cloud = false;
        g.open_ai_hotwords.clear();
        g.active_segment_samples.clear();
        g.cloud_failover_backup_samples.clear();
        g.frozen_transcript_prefix.clear();
        g.has_detected_speech_in_segment = false;
        g.has_detected_speech_overall = false;
        g.consecutive_silent_samples = 0;
    }

    pub fn has_local_model_files() -> bool {
        sense_voice_model_paths().is_some()
    }
}
