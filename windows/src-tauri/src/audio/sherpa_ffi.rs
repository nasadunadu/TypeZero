use libloading::Library;
use std::ffi::{c_char, c_void, CStr, CString};
use std::path::{Path, PathBuf};

// Exact sherpa-onnx v1.13.8 C ABI struct definitions matching Sources/CSherpaOnnx/c-api-internal/c-api.h

#[repr(C)]
#[derive(Default)]
struct SherpaOnnxFeatureConfig {
    sample_rate: i32,
    feature_dim: i32,
}

#[repr(C)]
struct SherpaOnnxOfflineTransducerModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    joiner: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineParaformerModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineNemoEncDecCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineWhisperModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    language: *const c_char,
    task: *const c_char,
    tail_paddings: i32,
    enable_token_timestamps: i32,
    enable_segment_timestamps: i32,
}

#[repr(C)]
struct SherpaOnnxOfflineTdnnModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineSenseVoiceModelConfig {
    model: *const c_char,
    language: *const c_char,
    use_itn: i32,
}

#[repr(C)]
struct SherpaOnnxOfflineMoonshineModelConfig {
    preprocessor: *const c_char,
    encoder: *const c_char,
    uncached_decoder: *const c_char,
    cached_decoder: *const c_char,
    merged_decoder: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineFireRedAsrModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineDolphinModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineZipformerCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineCanaryModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    src_lang: *const c_char,
    tgt_lang: *const c_char,
    use_pnc: i32,
}

#[repr(C)]
struct SherpaOnnxOfflineWenetCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineOmnilingualAsrCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineMedAsrCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineFunASRNanoModelConfig {
    encoder_adaptor: *const c_char,
    llm: *const c_char,
    embedding: *const c_char,
    tokenizer: *const c_char,
    system_prompt: *const c_char,
    user_prompt: *const c_char,
    max_new_tokens: i32,
    temperature: f32,
    top_p: f32,
    seed: i32,
    language: *const c_char,
    itn: i32,
    hotwords: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineFireRedAsrCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineQwen3ASRModelConfig {
    conv_frontend: *const c_char,
    encoder: *const c_char,
    decoder: *const c_char,
    tokenizer: *const c_char,
    max_total_len: i32,
    max_new_tokens: i32,
    temperature: f32,
    top_p: f32,
    seed: i32,
    hotwords: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineCohereTranscribeModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    language: *const c_char,
    use_punct: i32,
    use_itn: i32,
}

#[repr(C)]
struct SherpaOnnxOfflineModelConfig {
    transducer: SherpaOnnxOfflineTransducerModelConfig,
    paraformer: SherpaOnnxOfflineParaformerModelConfig,
    nemo_ctc: SherpaOnnxOfflineNemoEncDecCtcModelConfig,
    whisper: SherpaOnnxOfflineWhisperModelConfig,
    tdnn: SherpaOnnxOfflineTdnnModelConfig,
    tokens: *const c_char,
    num_threads: i32,
    debug: i32,
    provider: *const c_char,
    model_type: *const c_char,
    modeling_unit: *const c_char,
    bpe_vocab: *const c_char,
    telespeech_ctc: *const c_char,
    sense_voice: SherpaOnnxOfflineSenseVoiceModelConfig,
    moonshine: SherpaOnnxOfflineMoonshineModelConfig,
    fire_red_asr: SherpaOnnxOfflineFireRedAsrModelConfig,
    dolphin: SherpaOnnxOfflineDolphinModelConfig,
    zipformer_ctc: SherpaOnnxOfflineZipformerCtcModelConfig,
    canary: SherpaOnnxOfflineCanaryModelConfig,
    wenet_ctc: SherpaOnnxOfflineWenetCtcModelConfig,
    omnilingual: SherpaOnnxOfflineOmnilingualAsrCtcModelConfig,
    medasr: SherpaOnnxOfflineMedAsrCtcModelConfig,
    funasr_nano: SherpaOnnxOfflineFunASRNanoModelConfig,
    fire_red_asr_ctc: SherpaOnnxOfflineFireRedAsrCtcModelConfig,
    qwen3_asr: SherpaOnnxOfflineQwen3ASRModelConfig,
    cohere_transcribe: SherpaOnnxOfflineCohereTranscribeModelConfig,
}

#[repr(C)]
struct SherpaOnnxOfflineLMConfig {
    model: *const c_char,
    scale: f32,
}

#[repr(C)]
struct SherpaOnnxHomophoneReplacerConfig {
    dict_dir: *const c_char,
    lexicon: *const c_char,
    rule_fsts: *const c_char,
}

#[repr(C)]
struct SherpaOnnxOfflineRecognizerConfig {
    feat_config: SherpaOnnxFeatureConfig,
    model_config: SherpaOnnxOfflineModelConfig,
    lm_config: SherpaOnnxOfflineLMConfig,
    decoding_method: *const c_char,
    max_active_paths: i32,
    hotwords_file: *const c_char,
    hotwords_score: f32,
    rule_fsts: *const c_char,
    rule_fars: *const c_char,
    blank_penalty: f32,
    hr: SherpaOnnxHomophoneReplacerConfig,
}

#[repr(C)]
struct SherpaOnnxOfflineRecognizerResult {
    text: *const c_char,
}

type FnCreateOfflineRecognizer =
    unsafe extern "C" fn(*const SherpaOnnxOfflineRecognizerConfig) -> *const c_void;
type FnDestroyOfflineRecognizer = unsafe extern "C" fn(*const c_void);
type FnCreateOfflineStream = unsafe extern "C" fn(*const c_void) -> *const c_void;
type FnDestroyOfflineStream = unsafe extern "C" fn(*const c_void);
type FnAcceptWaveformOffline = unsafe extern "C" fn(*const c_void, i32, *const f32, i32);
type FnDecodeOfflineStream = unsafe extern "C" fn(*const c_void, *const c_void);
type FnGetOfflineStreamResult =
    unsafe extern "C" fn(*const c_void) -> *const SherpaOnnxOfflineRecognizerResult;
type FnDestroyOfflineRecognizerResult =
    unsafe extern "C" fn(*const SherpaOnnxOfflineRecognizerResult);

#[derive(Debug, Clone)]
pub struct SenseVoiceModelPaths {
    pub model_path: PathBuf,
    pub tokens_path: PathBuf,
    pub is_full_fp32: bool,
}

pub fn models_root_dir() -> PathBuf {
    let base = dirs::data_dir().unwrap_or_else(|| PathBuf::from("."));
    base.join("TypeZero").join("Models")
}

/// Priority 1: Full-precision 886MB SenseVoice FP32; Priority 2: compact INT8 fallback.
pub fn sense_voice_model_paths() -> Option<SenseVoiceModelPaths> {
    let root = models_root_dir();

    let fp32_dir = root.join("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09");
    let fp32_model = fp32_dir.join("model.onnx");
    let fp32_tokens = fp32_dir.join("tokens.txt");
    if fp32_model.exists() && fp32_tokens.exists() {
        return Some(SenseVoiceModelPaths {
            model_path: fp32_model,
            tokens_path: fp32_tokens,
            is_full_fp32: true,
        });
    }

    let int8_dir = root.join("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09");
    let int8_model = int8_dir.join("model.int8.onnx");
    let int8_tokens = int8_dir.join("tokens.txt");
    if int8_model.exists() && int8_tokens.exists() {
        return Some(SenseVoiceModelPaths {
            model_path: int8_model,
            tokens_path: int8_tokens,
            is_full_fp32: false,
        });
    }

    None
}

/// Locates `sherpa-onnx-c-api.dll` (Windows) or `.dylib` (macOS dev) next to the executable or in `%APPDATA%\TypeZero\Runtime`.
pub fn locate_sherpa_runtime_library() -> Option<PathBuf> {
    let lib_name = if cfg!(target_os = "windows") {
        "sherpa-onnx-c-api.dll"
    } else if cfg!(target_os = "macos") {
        "libsherpa-onnx-c-api.dylib"
    } else {
        "libsherpa-onnx-c-api.so"
    };

    let mut search_dirs: Vec<PathBuf> = Vec::new();
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            search_dirs.push(dir.to_path_buf());
            search_dirs.push(dir.join("runtime"));
            search_dirs.push(dir.join("resources").join("runtime"));
        }
    }
    if let Some(data_dir) = dirs::data_dir() {
        search_dirs.push(data_dir.join("TypeZero").join("Runtime"));
    }

    for dir in search_dirs {
        let candidate = dir.join(lib_name);
        if candidate.exists() {
            return Some(candidate);
        }
    }
    None
}

pub struct SenseVoiceRecognizer {
    _onnx_dep: Option<Library>,
    lib: Library,
    recognizer: *const c_void,
    pub is_full_fp32: bool,
    pub language: String,
}

// SAFETY: SenseVoiceRecognizer is only accessed behind an exclusive decode mutex.
unsafe impl Send for SenseVoiceRecognizer {}
unsafe impl Sync for SenseVoiceRecognizer {}

impl SenseVoiceRecognizer {
    pub fn load_if_available(language: &str) -> Option<Self> {
        let paths = sense_voice_model_paths()?;
        let lib_path = locate_sherpa_runtime_library()?;
        let cpu_count = std::thread::available_parallelism()
            .map(|n| n.get() as i32)
            .unwrap_or(4);
        let max_threads = if paths.is_full_fp32 { 8 } else { 6 };
        let threads = (cpu_count - 2).clamp(4, max_threads);

        Self::create(
            &lib_path,
            &paths.model_path,
            &paths.tokens_path,
            threads,
            paths.is_full_fp32,
            language,
        )
        .ok()
    }

    pub fn create(
        lib_path: &Path,
        model_path: &Path,
        tokens_path: &Path,
        num_threads: i32,
        is_full_fp32: bool,
        language: &str,
    ) -> Result<Self, String> {
        // Preload sibling onnxruntime.dll if present so Windows loader resolves dependent DLLs seamlessly
        let onnx_dep = if let Some(dir) = lib_path.parent() {
            let dep_name = if cfg!(target_os = "windows") {
                "onnxruntime.dll"
            } else if cfg!(target_os = "macos") {
                "libonnxruntime.dylib"
            } else {
                "libonnxruntime.so"
            };
            let dep_path = dir.join(dep_name);
            if dep_path.exists() {
                unsafe { Library::new(&dep_path).ok() }
            } else {
                None
            }
        } else {
            None
        };

        let lib = unsafe { Library::new(lib_path) }
            .map_err(|e| format!("无法加载 sherpa-onnx 运行时：{e}"))?;

        let c_model = CString::new(model_path.to_string_lossy().as_ref())
            .map_err(|_| "模型路径含非法空字符".to_string())?;
        let c_tokens = CString::new(tokens_path.to_string_lossy().as_ref())
            .map_err(|_| "tokens 路径含非法空字符".to_string())?;
        let effective_lang = if language.trim().is_empty() {
            "auto"
        } else {
            language.trim()
        };
        let c_lang = CString::new(effective_lang).unwrap_or_else(|_| CString::new("auto").unwrap());
        let c_provider = CString::new("cpu").unwrap();
        let c_decoding = CString::new("greedy_search").unwrap();

        let recognizer = unsafe {
            let create_fn: libloading::Symbol<FnCreateOfflineRecognizer> = lib
                .get(b"SherpaOnnxCreateOfflineRecognizer\0")
                .map_err(|e| format!("缺少符号 SherpaOnnxCreateOfflineRecognizer：{e}"))?;

            let mut cfg: SherpaOnnxOfflineRecognizerConfig = std::mem::zeroed();
            cfg.feat_config.sample_rate = 16000;
            cfg.feat_config.feature_dim = 80;
            cfg.model_config.sense_voice.model = c_model.as_ptr();
            cfg.model_config.sense_voice.language = c_lang.as_ptr();
            cfg.model_config.sense_voice.use_itn = 1;
            cfg.model_config.tokens = c_tokens.as_ptr();
            cfg.model_config.num_threads = if num_threads > 0 { num_threads } else { 4 };
            cfg.model_config.debug = 0;
            cfg.model_config.provider = c_provider.as_ptr();
            cfg.decoding_method = c_decoding.as_ptr();

            create_fn(&cfg)
        };

        if recognizer.is_null() {
            return Err("SherpaOnnxCreateOfflineRecognizer 返回空句柄".to_string());
        }

        Ok(Self {
            _onnx_dep: onnx_dep,
            lib,
            recognizer,
            is_full_fp32,
            language: effective_lang.to_string(),
        })
    }

    pub fn transcribe(&self, samples: &[f32], sample_rate: i32) -> String {
        if self.recognizer.is_null() || samples.is_empty() {
            return String::new();
        }
        unsafe {
            let Ok(create_stream) = self
                .lib
                .get::<FnCreateOfflineStream>(b"SherpaOnnxCreateOfflineStream\0")
            else {
                return String::new();
            };
            let Ok(accept_wave) = self
                .lib
                .get::<FnAcceptWaveformOffline>(b"SherpaOnnxAcceptWaveformOffline\0")
            else {
                return String::new();
            };
            let Ok(decode_stream) = self
                .lib
                .get::<FnDecodeOfflineStream>(b"SherpaOnnxDecodeOfflineStream\0")
            else {
                return String::new();
            };
            let Ok(get_result) = self
                .lib
                .get::<FnGetOfflineStreamResult>(b"SherpaOnnxGetOfflineStreamResult\0")
            else {
                return String::new();
            };
            let Ok(destroy_result) = self.lib.get::<FnDestroyOfflineRecognizerResult>(
                b"SherpaOnnxDestroyOfflineRecognizerResult\0",
            ) else {
                return String::new();
            };
            let Ok(destroy_stream) = self
                .lib
                .get::<FnDestroyOfflineStream>(b"SherpaOnnxDestroyOfflineStream\0")
            else {
                return String::new();
            };

            let stream = create_stream(self.recognizer);
            if stream.is_null() {
                return String::new();
            }
            accept_wave(stream, sample_rate, samples.as_ptr(), samples.len() as i32);
            decode_stream(self.recognizer, stream);

            let res_ptr = get_result(stream);
            let out = if !res_ptr.is_null() && !(*res_ptr).text.is_null() {
                CStr::from_ptr((*res_ptr).text)
                    .to_string_lossy()
                    .trim()
                    .to_string()
            } else {
                String::new()
            };

            if !res_ptr.is_null() {
                destroy_result(res_ptr);
            }
            destroy_stream(stream);
            out
        }
    }
}

impl Drop for SenseVoiceRecognizer {
    fn drop(&mut self) {
        if !self.recognizer.is_null() {
            unsafe {
                if let Ok(destroy_fn) = self
                    .lib
                    .get::<FnDestroyOfflineRecognizer>(b"SherpaOnnxDestroyOfflineRecognizer\0")
                {
                    destroy_fn(self.recognizer);
                }
            }
            self.recognizer = std::ptr::null();
        }
    }
}
