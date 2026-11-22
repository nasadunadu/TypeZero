use crate::audio::sherpa_ffi::models_root_dir;
use futures_util::StreamExt;
use std::fs::{self, File};
use std::io::Write;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

const MIRROR_URLS: &[&str] = &[
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09.tar.bz2",
    "https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09.tar.bz2",
];

pub struct OfflineModelDownloader {
    is_running: Arc<AtomicBool>,
    cancel_flag: Arc<AtomicBool>,
}

impl Default for OfflineModelDownloader {
    fn default() -> Self {
        Self::new()
    }
}

impl OfflineModelDownloader {
    pub fn new() -> Self {
        Self {
            is_running: Arc::new(AtomicBool::new(false)),
            cancel_flag: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn is_downloading(&self) -> bool {
        self.is_running.load(Ordering::SeqCst)
    }

    pub fn cancel(&self) {
        self.cancel_flag.store(true, Ordering::SeqCst);
    }

    pub fn start_download<FProg, FDone>(&self, on_progress: FProg, on_done: FDone)
    where
        FProg: Fn(f64, String) + Send + Sync + 'static,
        FDone: Fn(bool, String) + Send + Sync + 'static,
    {
        if self.is_running.swap(true, Ordering::SeqCst) {
            return;
        }
        self.cancel_flag.store(false, Ordering::SeqCst);

        let is_running = Arc::clone(&self.is_running);
        let cancel_flag = Arc::clone(&self.cancel_flag);

        tokio::spawn(async move {
            let res = Self::run_download_flow(&cancel_flag, &on_progress).await;
            is_running.store(false, Ordering::SeqCst);
            match res {
                Ok(msg) => on_done(true, msg),
                Err(err) => on_done(false, err),
            }
        });
    }

    async fn run_download_flow<FProg>(
        cancel_flag: &Arc<AtomicBool>,
        on_progress: &FProg,
    ) -> Result<String, String>
    where
        FProg: Fn(f64, String) + Send + Sync,
    {
        let root = models_root_dir();
        fs::create_dir_all(&root).map_err(|e| format!("无法创建模型目录：{e}"))?;
        let archive_path = root.join("sensevoice-fp32-download.tar.bz2");

        let client = reqwest::Client::builder()
            .connect_timeout(Duration::from_secs(20))
            .timeout(Duration::from_secs(3600))
            .build()
            .map_err(|e| format!("初始化下载器失败：{e}"))?;

        let mut last_error = String::new();
        let mut downloaded_ok = false;

        for (idx, url) in MIRROR_URLS.iter().enumerate() {
            if cancel_flag.load(Ordering::SeqCst) {
                let _ = fs::remove_file(&archive_path);
                return Err("已取消离线模型下载".to_string());
            }

            let mirror_note = if idx == 0 {
                "连接官方源下载 886MB 无损模型…"
            } else {
                "已自动切换国内加速镜像下载…"
            };
            on_progress(0.01, mirror_note.to_string());

            let resp = match client.get(*url).send().await {
                Ok(r) if r.status().is_success() => r,
                Ok(r) => {
                    last_error = format!("HTTP {}", r.status().as_u16());
                    continue;
                }
                Err(e) => {
                    last_error = e.to_string();
                    continue;
                }
            };

            let expected = resp.content_length().unwrap_or(886_000_000).max(1);
            let mut file = match File::create(&archive_path) {
                Ok(f) => f,
                Err(e) => return Err(format!("无法写入临时压缩包：{e}")),
            };

            let mut written: u64 = 0;
            let mut last_reported_mb: u64 = 0;
            let mut stream = resp.bytes_stream();
            let mut stream_err = None;

            while let Some(chunk_res) = stream.next().await {
                if cancel_flag.load(Ordering::SeqCst) {
                    drop(file);
                    let _ = fs::remove_file(&archive_path);
                    return Err("已取消离线模型下载".to_string());
                }
                match chunk_res {
                    Ok(chunk) => {
                        if let Err(e) = file.write_all(&chunk) {
                            stream_err = Some(format!("写入磁盘失败：{e}"));
                            break;
                        }
                        written += chunk.len() as u64;
                        let mb_done = written / 1_048_576;
                        if mb_done != last_reported_mb {
                            last_reported_mb = mb_done;
                            let frac = ((written as f64) / (expected as f64)).clamp(0.01, 0.94);
                            let mb_total = (expected / 1_048_576).max(mb_done);
                            let pct = (frac * 100.0) as u32;
                            on_progress(
                                frac,
                                format!("正在下载离线满血包 {mb_done} / {mb_total} MB ({pct}%)"),
                            );
                        }
                    }
                    Err(e) => {
                        stream_err = Some(e.to_string());
                        break;
                    }
                }
            }

            if let Some(err) = stream_err {
                last_error = err;
                let _ = fs::remove_file(&archive_path);
                continue;
            }
            let _ = file.flush();
            downloaded_ok = true;
            break;
        }

        if !downloaded_ok {
            return Err(format!("❌ 离线模型下载失败：{last_error}"));
        }

        on_progress(0.96, "下载完成，正在纯原生解压 886MB 无损权重…".to_string());

        let extract_archive = archive_path.clone();
        let extract_root = root.clone();
        let extract_res = tokio::task::spawn_blocking(move || -> Result<(), String> {
            let f = File::open(&extract_archive).map_err(|e| format!("打开压缩包失败：{e}"))?;
            let bz = bzip2_rs::DecoderReader::new(std::io::BufReader::new(f));
            let mut archive = tar::Archive::new(bz);
            archive
                .unpack(&extract_root)
                .map_err(|e| format!("解压 tar.bz2 失败：{e}"))?;
            Ok(())
        })
        .await
        .map_err(|e| format!("解压线程异常：{e}"))?;

        let _ = fs::remove_file(&archive_path);
        extract_res?;

        let model_file = root
            .join("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09")
            .join("model.onnx");
        if model_file.exists() {
            on_progress(1.0, "离线满血底座安装完成".to_string());
            Ok("✅ 本机 886MB SenseVoice FP32 离线满血底座已安装并激活".to_string())
        } else {
            Err("❌ 解压完成但未找到 model.onnx 权重文件".to_string())
        }
    }
}
