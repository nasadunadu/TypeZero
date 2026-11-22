use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use futures_util::{SinkExt, StreamExt};
use parking_lot::Mutex;
use serde_json::{json, Value};
use std::io::{Read, Write};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, oneshot};
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::http::HeaderValue;
use tokio_tungstenite::tungstenite::Message;
use uuid::Uuid;

pub const ENDPOINT_URL: &str = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async";
pub const DEFAULT_RESOURCE_ID: &str = "volc.seedasr.sauc.duration";

/// Binary WebSocket client for Volcengine Doubao Streaming ASR 2.0 (`Seed-ASR` / `volc.seedasr.sauc.duration`).
/// - Direct domestic connection (bypasses system proxy via `reqwest::no_proxy` prewarm + direct TCP WS).
/// - Fast-start 60ms (1920B) × 3 frames then 100ms (3200B) Gzip binary frames.
/// - Injects Top-65 context-ranked hotwords + dialog_ctx directly into `corpus.context`.
pub struct VolcSeedASRClient {
    inner: Arc<Mutex<ClientInner>>,
    received_frames: Arc<AtomicUsize>,
    has_failed_over: Arc<AtomicBool>,
    last_prewarm: Mutex<Option<Instant>>,
    direct_http: reqwest::Client,
}

struct ClientInner {
    is_active: bool,
    pending_pcm16: Vec<u8>,
    sent_audio_chunks: usize,
    latest_server_text: String,
    did_receive_final: bool,
    cmd_tx: Option<mpsc::UnboundedSender<WsCommand>>,
    final_waiter: Option<oneshot::Sender<Option<String>>>,
}

enum WsCommand {
    SendFrame(Vec<u8>),
    Close,
}

impl Default for VolcSeedASRClient {
    fn default() -> Self {
        Self::new()
    }
}

impl VolcSeedASRClient {
    pub fn new() -> Self {
        let direct_http = reqwest::Client::builder()
            .no_proxy()
            .timeout(Duration::from_secs(3))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        Self {
            inner: Arc::new(Mutex::new(ClientInner {
                is_active: false,
                pending_pcm16: Vec::new(),
                sent_audio_chunks: 0,
                latest_server_text: String::new(),
                did_receive_final: false,
                cmd_tx: None,
                final_waiter: None,
            })),
            received_frames: Arc::new(AtomicUsize::new(0)),
            has_failed_over: Arc::new(AtomicBool::new(false)),
            last_prewarm: Mutex::new(None),
            direct_http,
        }
    }

    pub fn has_received_any_server_frame(&self) -> bool {
        self.received_frames.load(Ordering::Relaxed) > 0
    }

    pub fn prewarm_standby_socket(&self, api_key: &str) {
        if api_key.trim().is_empty() {
            return;
        }
        {
            let mut last = self.last_prewarm.lock();
            if let Some(t) = *last {
                if t.elapsed() < Duration::from_secs(25) {
                    return;
                }
            }
            *last = Some(Instant::now());
        }
        let client = self.direct_http.clone();
        tokio::spawn(async move {
            let _ = client.head("https://openspeech.bytedance.com/").send().await;
        });
    }

    pub fn start_session<FPartial, FFailover>(
        &self,
        api_key: &str,
        hotwords: &[String],
        dialog_context: &[String],
        on_partial: FPartial,
        on_failover: FFailover,
    ) where
        FPartial: Fn(String, bool) + Send + Sync + 'static,
        FFailover: Fn(String) + Send + Sync + 'static,
    {
        self.stop_and_reset();
        let clean_key = api_key.trim().to_string();
        if clean_key.is_empty() {
            on_failover("未配置豆包语音 API Key".to_string());
            return;
        }

        let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<WsCommand>();
        self.received_frames.store(0, Ordering::SeqCst);
        self.has_failed_over.store(false, Ordering::SeqCst);

        {
            let mut g = self.inner.lock();
            g.is_active = true;
            g.pending_pcm16.clear();
            g.sent_audio_chunks = 0;
            g.latest_server_text.clear();
            g.did_receive_final = false;
            g.cmd_tx = Some(cmd_tx.clone());
            g.final_waiter = None;
        }

        let init_frame = Self::build_init_frame(hotwords, dialog_context);
        let _ = cmd_tx.send(WsCommand::SendFrame(init_frame));

        let inner = Arc::clone(&self.inner);
        let received_frames = Arc::clone(&self.received_frames);
        let has_failed_over = Arc::clone(&self.has_failed_over);

        tokio::spawn(async move {
            let mut request = match ENDPOINT_URL.into_client_request() {
                Ok(r) => r,
                Err(e) => {
                    Self::trigger_failover(&inner, &has_failed_over, &on_failover, format!("无效地址：{e}"));
                    return;
                }
            };
            let headers = request.headers_mut();
            if let Ok(v) = HeaderValue::from_str(&clean_key) {
                headers.insert("X-Api-Key", v);
            }
            headers.insert(
                "X-Api-Resource-Id",
                HeaderValue::from_static(DEFAULT_RESOURCE_ID),
            );
            if let Ok(v) = HeaderValue::from_str(&Uuid::new_v4().to_string()) {
                headers.insert("X-Api-Connect-Id", v);
            }
            if let Ok(v) = HeaderValue::from_str(&Uuid::new_v4().to_string()) {
                headers.insert("X-Api-Request-Id", v);
            }

            let ws_stream = match tokio::time::timeout(
                Duration::from_secs(4),
                tokio_tungstenite::connect_async(request),
            )
            .await
            {
                Ok(Ok((ws, _))) => ws,
                Ok(Err(e)) => {
                    Self::trigger_failover(
                        &inner,
                        &has_failed_over,
                        &on_failover,
                        format!("连接失败：{e}"),
                    );
                    return;
                }
                Err(_) => {
                    Self::trigger_failover(
                        &inner,
                        &has_failed_over,
                        &on_failover,
                        "连接超时".to_string(),
                    );
                    return;
                }
            };

            let (mut write, mut read) = ws_stream.split();

            let writer_inner = Arc::clone(&inner);
            let writer_failed = Arc::clone(&has_failed_over);
            let writer_task = tokio::spawn(async move {
                while let Some(cmd) = cmd_rx.recv().await {
                    match cmd {
                        WsCommand::SendFrame(frame) => {
                            if write.send(Message::Binary(frame)).await.is_err() {
                                writer_failed.store(true, Ordering::SeqCst);
                                let mut g = writer_inner.lock();
                                if let Some(w) = g.final_waiter.take() {
                                    let _ = w.send(None);
                                }
                                break;
                            }
                        }
                        WsCommand::Close => {
                            let _ = write.close().await;
                            break;
                        }
                    }
                }
            });

            while let Some(msg_res) = read.next().await {
                match msg_res {
                    Ok(Message::Binary(raw)) => {
                        let keep_reading = Self::handle_incoming_binary_frame(
                            &raw,
                            &inner,
                            &received_frames,
                            &has_failed_over,
                            &on_partial,
                            &on_failover,
                        );
                        if !keep_reading {
                            break;
                        }
                    }
                    Ok(Message::Close(_)) => break,
                    Ok(_) => continue,
                    Err(e) => {
                        Self::trigger_failover(
                            &inner,
                            &has_failed_over,
                            &on_failover,
                            format!("连接中断：{e}"),
                        );
                        break;
                    }
                }
            }

            writer_task.abort();
            // Ensure any waiting finalizer is released
            let mut g = inner.lock();
            if let Some(waiter) = g.final_waiter.take() {
                let best = if has_failed_over.load(Ordering::SeqCst) || g.latest_server_text.is_empty() {
                    None
                } else {
                    Some(g.latest_server_text.clone())
                };
                let _ = waiter.send(best);
            }
        });
    }

    /// Appends anti-aliased 16kHz Int16 PCM samples:
    /// 60ms (1920B) fast-start packets for first 3 frames, then 100ms (3200B) steady frames.
    pub fn append_pcm16_samples(&self, samples: &[i16]) {
        if samples.is_empty() || self.has_failed_over.load(Ordering::Relaxed) {
            return;
        }
        let mut chunks_to_send: Vec<Vec<u8>> = Vec::new();
        let tx_opt: Option<mpsc::UnboundedSender<WsCommand>>;
        {
            let mut g = self.inner.lock();
            if !g.is_active {
                return;
            }
            for &s in samples {
                g.pending_pcm16.extend_from_slice(&s.to_le_bytes());
            }
            loop {
                let packet_bytes = if g.sent_audio_chunks < 3 { 1920 } else { 3200 };
                if g.pending_pcm16.len() < packet_bytes {
                    break;
                }
                let chunk: Vec<u8> = g.pending_pcm16.drain(..packet_bytes).collect();
                chunks_to_send.push(chunk);
                g.sent_audio_chunks += 1;
            }
            tx_opt = g.cmd_tx.clone();
        }

        if let Some(tx) = tx_opt {
            for chunk in chunks_to_send {
                let frame = Self::make_binary_frame(0x2, 0x0, 0x0, 0x1, &Self::gzip_compress(&chunk));
                let _ = tx.send(WsCommand::SendFrame(frame));
            }
        }
    }

    /// Sends final trailing audio frame (`flags = 0x2`) and waits up to `timeout_ms` for definitive transcript.
    pub async fn finish_and_await_final_transcript(&self, timeout_ms: u64) -> Option<String> {
        let (tx, remaining_pcm, rx) = {
            let mut g = self.inner.lock();
            let failed = self.has_failed_over.load(Ordering::SeqCst);
            if !g.is_active || failed || g.cmd_tx.is_none() {
                g.is_active = false;
                let partial = if failed || g.latest_server_text.is_empty() {
                    None
                } else {
                    Some(g.latest_server_text.clone())
                };
                drop(g);
                self.stop_and_reset();
                return partial;
            }
            g.is_active = false;
            let remaining = std::mem::take(&mut g.pending_pcm16);
            if g.did_receive_final {
                let ready = if g.latest_server_text.is_empty() {
                    None
                } else {
                    Some(g.latest_server_text.clone())
                };
                drop(g);
                self.stop_and_reset();
                return ready;
            }
            let (wait_tx, wait_rx) = oneshot::channel();
            g.final_waiter = Some(wait_tx);
            (g.cmd_tx.clone().unwrap(), remaining, wait_rx)
        };

        let final_frame =
            Self::make_binary_frame(0x2, 0x2, 0x0, 0x1, &Self::gzip_compress(&remaining_pcm));
        let _ = tx.send(WsCommand::SendFrame(final_frame));

        let result = match tokio::time::timeout(Duration::from_millis(timeout_ms), rx).await {
            Ok(Ok(val)) => val,
            _ => {
                let g = self.inner.lock();
                if self.has_failed_over.load(Ordering::SeqCst) || g.latest_server_text.is_empty() {
                    None
                } else {
                    Some(g.latest_server_text.clone())
                }
            }
        };

        self.stop_and_reset();
        result
    }

    pub fn stop_and_reset(&self) {
        let (tx, waiter) = {
            let mut g = self.inner.lock();
            g.is_active = false;
            g.pending_pcm16.clear();
            (g.cmd_tx.take(), g.final_waiter.take())
        };
        if let Some(w) = waiter {
            let _ = w.send(None);
        }
        if let Some(t) = tx {
            let _ = t.send(WsCommand::Close);
        }
    }

    /// Live diagnostic probe: verifies `volc.seedasr.sauc.duration` WebSocket auth + direct RTT in milliseconds.
    pub async fn probe_handshake_latency(api_key: &str) -> Result<u64, String> {
        let clean_key = api_key.trim();
        if clean_key.is_empty() {
            return Err("请先粘贴豆包语音 API Key".to_string());
        }
        let mut request = ENDPOINT_URL
            .into_client_request()
            .map_err(|e| format!("无效地址：{e}"))?;
        let headers = request.headers_mut();
        headers.insert(
            "X-Api-Key",
            HeaderValue::from_str(clean_key).map_err(|_| "API Key 包含非法字符".to_string())?,
        );
        headers.insert(
            "X-Api-Resource-Id",
            HeaderValue::from_static(DEFAULT_RESOURCE_ID),
        );
        headers.insert(
            "X-Api-Connect-Id",
            HeaderValue::from_str(&Uuid::new_v4().to_string()).unwrap(),
        );
        headers.insert(
            "X-Api-Request-Id",
            HeaderValue::from_str(&Uuid::new_v4().to_string()).unwrap(),
        );

        let t0 = Instant::now();
        let (mut ws, _) = tokio::time::timeout(
            Duration::from_secs(5),
            tokio_tungstenite::connect_async(request),
        )
        .await
        .map_err(|_| "连接豆包语音服务超时（5s）".to_string())?
        .map_err(|e| format!("握手失败：{e}"))?;

        let init_payload = json!({
            "user": { "uid": "typezero_windows_probe" },
            "audio": { "format": "pcm", "codec": "raw", "rate": 16000, "bits": 16, "channel": 1 },
            "request": { "model_name": "bigmodel", "enable_itn": true, "enable_punc": true, "result_type": "full" }
        });
        let init_json = serde_json::to_vec(&init_payload).unwrap_or_default();
        let init_frame =
            Self::make_binary_frame(0x1, 0x0, 0x1, 0x1, &Self::gzip_compress(&init_json));
        ws.send(Message::Binary(init_frame))
            .await
            .map_err(|e| format!("发送初始化帧失败：{e}"))?;

        let silent_pcm = vec![0u8; 3200];
        let audio_frame =
            Self::make_binary_frame(0x2, 0x2, 0x0, 0x1, &Self::gzip_compress(&silent_pcm));
        ws.send(Message::Binary(audio_frame))
            .await
            .map_err(|e| format!("发送静音帧失败：{e}"))?;

        let reply = tokio::time::timeout(Duration::from_secs(5), ws.next())
            .await
            .map_err(|_| "等待豆包语音首帧超时".to_string())?;
        let elapsed_ms = t0.elapsed().as_millis().max(1) as u64;
        let _ = ws.close(None).await;

        if let Some(Ok(Message::Binary(raw))) = reply {
            if raw.len() >= 8 {
                let msg_type = raw[1] >> 4;
                let comp = raw[2] & 0x0F;
                if msg_type == 0xF {
                    let mut detail = "鉴权或资源包错误".to_string();
                    if raw.len() >= 12 {
                        let err_len =
                            u32::from_be_bytes([raw[8], raw[9], raw[10], raw[11]]) as usize;
                        let end = raw.len().min(12 + err_len);
                        let body = &raw[12..end];
                        let unzipped = if comp == 0x1 {
                            Self::gzip_decompress(body)
                        } else {
                            body.to_vec()
                        };
                        if let Ok(s) = String::from_utf8(unzipped) {
                            if !s.trim().is_empty() {
                                detail = s;
                            }
                        }
                    }
                    return Err(detail);
                }
            }
        }
        Ok(elapsed_ms)
    }

    fn build_init_frame(hotwords: &[String], dialog_context: &[String]) -> Vec<u8> {
        let hotword_objs: Vec<Value> = hotwords
            .iter()
            .take(65)
            .map(|w| json!({ "word": w }))
            .collect();
        let dialog_objs: Vec<Value> = dialog_context
            .iter()
            .map(|s| {
                let t = s.trim();
                let chars: Vec<char> = t.chars().collect();
                let tail: String = if chars.len() > 120 {
                    chars[chars.len() - 120..].iter().collect()
                } else {
                    t.to_string()
                };
                tail
            })
            .filter(|s| !s.is_empty())
            .take(2)
            .map(|s| json!({ "text": s }))
            .collect();

        let mut ctx_map = serde_json::Map::new();
        if !hotword_objs.is_empty() {
            ctx_map.insert("hotwords".into(), Value::Array(hotword_objs));
        }
        if !dialog_objs.is_empty() {
            ctx_map.insert("context_type".into(), json!("dialog_ctx"));
            ctx_map.insert("context_data".into(), Value::Array(dialog_objs));
        }

        let mut req_map = serde_json::Map::new();
        req_map.insert("model_name".into(), json!("bigmodel"));
        req_map.insert("enable_itn".into(), json!(true));
        req_map.insert("enable_punc".into(), json!(true));
        req_map.insert("enable_ddc".into(), json!(true));
        req_map.insert("enable_nonstream".into(), json!(true));
        req_map.insert("show_utterances".into(), json!(true));
        req_map.insert("result_type".into(), json!("full"));
        if !ctx_map.is_empty() {
            if let Ok(ctx_str) = serde_json::to_string(&Value::Object(ctx_map)) {
                req_map.insert("corpus".into(), json!({ "context": ctx_str }));
            }
        }

        let init_payload = json!({
            "user": { "uid": "typezero_windows_client" },
            "audio": {
                "format": "pcm",
                "codec": "raw",
                "rate": 16000,
                "bits": 16,
                "channel": 1
            },
            "request": Value::Object(req_map)
        });
        let json_bytes = serde_json::to_vec(&init_payload).unwrap_or_default();
        Self::make_binary_frame(0x1, 0x0, 0x1, 0x1, &Self::gzip_compress(&json_bytes))
    }

    fn trigger_failover<F>(
        inner: &Arc<Mutex<ClientInner>>,
        has_failed_over: &Arc<AtomicBool>,
        on_failover: &F,
        reason: String,
    ) where
        F: Fn(String),
    {
        if has_failed_over.swap(true, Ordering::SeqCst) {
            return;
        }
        let waiter = {
            let mut g = inner.lock();
            g.final_waiter.take()
        };
        if let Some(w) = waiter {
            let _ = w.send(None);
        }
        on_failover(reason);
    }

    fn handle_incoming_binary_frame<FPartial, FFailover>(
        raw: &[u8],
        inner: &Arc<Mutex<ClientInner>>,
        received_frames: &Arc<AtomicUsize>,
        has_failed_over: &Arc<AtomicBool>,
        on_partial: &FPartial,
        on_failover: &FFailover,
    ) -> bool
    where
        FPartial: Fn(String, bool),
        FFailover: Fn(String),
    {
        if raw.len() < 8 {
            return true;
        }
        let byte1 = raw[1];
        let byte2 = raw[2];
        let msg_type = byte1 >> 4;
        let flags = byte1 & 0x0F;
        let serial = byte2 >> 4;
        let comp = byte2 & 0x0F;

        if msg_type == 0xF {
            let mut err_msg = "Seed-ASR server error".to_string();
            if raw.len() >= 12 {
                let err_len = u32::from_be_bytes([raw[8], raw[9], raw[10], raw[11]]) as usize;
                let end = raw.len().min(12 + err_len);
                let body = &raw[12..end];
                let unzipped = if comp == 0x1 {
                    Self::gzip_decompress(body)
                } else {
                    body.to_vec()
                };
                if let Ok(s) = String::from_utf8(unzipped) {
                    if !s.trim().is_empty() {
                        err_msg = s;
                    }
                }
            }
            Self::trigger_failover(inner, has_failed_over, on_failover, err_msg);
            return false;
        }

        let mut offset = 4usize;
        if flags == 0x1 || flags == 0x2 || flags == 0x3 {
            offset += 4;
        }
        let is_final = flags == 0x2 || flags == 0x3;
        received_frames.fetch_add(1, Ordering::SeqCst);

        if raw.len() < offset + 4 {
            if is_final {
                Self::complete_final(inner);
                return false;
            }
            return true;
        }
        let payload_size = u32::from_be_bytes([
            raw[offset],
            raw[offset + 1],
            raw[offset + 2],
            raw[offset + 3],
        ]) as usize;
        offset += 4;
        if payload_size == 0 || raw.len() < offset {
            if is_final {
                Self::complete_final(inner);
                return false;
            }
            return true;
        }

        let end = raw.len().min(offset + payload_size);
        let body = &raw[offset..end];
        let unzipped = if comp == 0x1 {
            Self::gzip_decompress(body)
        } else {
            body.to_vec()
        };

        if serial == 0x1 {
            if let Ok(json) = serde_json::from_slice::<Value>(&unzipped) {
                if let Some(text) = json.pointer("/result/text").and_then(|v| v.as_str()) {
                    let trimmed = text.trim().to_string();
                    let is_definite = json
                        .pointer("/result/utterances")
                        .and_then(|v| v.as_array())
                        .and_then(|arr| arr.last())
                        .and_then(|u| u.get("definite"))
                        .and_then(|d| d.as_bool())
                        .unwrap_or(false);

                    let waiter_and_out = {
                        let mut g = inner.lock();
                        if !trimmed.is_empty() {
                            g.latest_server_text = trimmed.clone();
                        }
                        if is_final {
                            g.did_receive_final = true;
                            let out = if g.latest_server_text.is_empty() {
                                None
                            } else {
                                Some(g.latest_server_text.clone())
                            };
                            Some((g.final_waiter.take(), out))
                        } else {
                            None
                        }
                    };

                    if let Some((waiter, final_out)) = waiter_and_out {
                        if !trimmed.is_empty() {
                            on_partial(trimmed, true);
                        }
                        if let Some(w) = waiter {
                            let _ = w.send(final_out);
                        }
                        return false;
                    }

                    if !trimmed.is_empty() {
                        on_partial(trimmed, is_definite);
                    }
                    return true;
                }
            }
        }

        if is_final {
            Self::complete_final(inner);
            return false;
        }
        true
    }

    fn complete_final(inner: &Arc<Mutex<ClientInner>>) {
        let (waiter, out) = {
            let mut g = inner.lock();
            g.did_receive_final = true;
            let out = if g.latest_server_text.is_empty() {
                None
            } else {
                Some(g.latest_server_text.clone())
            };
            (g.final_waiter.take(), out)
        };
        if let Some(w) = waiter {
            let _ = w.send(out);
        }
    }

    pub fn make_binary_frame(
        msg_type: u8,
        flags: u8,
        serialization: u8,
        compression: u8,
        payload: &[u8],
    ) -> Vec<u8> {
        let mut d = Vec::with_capacity(8 + payload.len());
        d.push((0x1 << 4) | 0x1);
        d.push((msg_type << 4) | (flags & 0x0F));
        d.push((serialization << 4) | (compression & 0x0F));
        d.push(0x00);
        d.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        d.extend_from_slice(payload);
        d
    }

    pub fn gzip_compress(data: &[u8]) -> Vec<u8> {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        let _ = encoder.write_all(data);
        encoder.finish().unwrap_or_else(|_| data.to_vec())
    }

    pub fn gzip_decompress(data: &[u8]) -> Vec<u8> {
        let mut decoder = GzDecoder::new(data);
        let mut out = Vec::new();
        if decoder.read_to_end(&mut out).is_ok() {
            out
        } else {
            data.to_vec()
        }
    }
}
