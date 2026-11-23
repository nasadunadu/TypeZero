use crate::core::polish::PolishEngine;
use reqwest::multipart::{Form, Part};
use reqwest::Client;
use serde_json::Value;
use std::collections::HashSet;
use std::f64::consts::PI;
use std::time::{Duration, Instant};

/// OpenAI-compatible Cloud Audio Transcription Client (`/v1/audio/transcriptions`).
/// Supports OpenAI (`gpt-4o-mini-transcribe` / `gpt-4o-transcribe`), Groq (`whisper-large-v3-turbo`), and local `whisper.cpp`.
pub struct OpenAITranscriptionClient {
    client: Client,
}

impl Default for OpenAITranscriptionClient {
    fn default() -> Self {
        Self::new()
    }
}

impl OpenAITranscriptionClient {
    pub fn new() -> Self {
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(6))
            .timeout(Duration::from_secs(16))
            .pool_max_idle_per_host(4)
            .build()
            .unwrap_or_else(|_| Client::new());
        Self { client }
    }

    pub fn normalize_transcription_endpoint(raw_base_url: &str) -> String {
        let mut trimmed = raw_base_url.trim().to_string();
        if trimmed.is_empty() {
            trimmed = "https://api.openai.com/v1".to_string();
        }
        while trimmed.ends_with('/') {
            trimmed.pop();
        }
        let lower = trimmed.to_lowercase();
        if lower.ends_with("/audio/transcriptions") {
            return trimmed;
        }
        if lower.ends_with("/v1") || lower.ends_with("/openai/v1") || lower.contains("/v1/") {
            return format!("{trimmed}/audio/transcriptions");
        }
        format!("{trimmed}/v1/audio/transcriptions")
    }

    pub fn is_groq_endpoint(raw_base_url: &str) -> bool {
        raw_base_url.to_lowercase().contains("groq.com")
    }

    /// Encodes 16kHz mono 16-bit signed little-endian PCM into an in-memory standard 44-byte RIFF/WAVE payload.
    pub fn encode_pcm16_to_wav(pcm16: &[i16], sample_rate: u32) -> Vec<u8> {
        let num_channels: u16 = 1;
        let bits_per_sample: u16 = 16;
        let byte_rate: u32 = sample_rate * (num_channels as u32) * ((bits_per_sample / 8) as u32);
        let block_align: u16 = num_channels * (bits_per_sample / 8);
        let data_size: u32 = (pcm16.len() * 2) as u32;
        let chunk_size: u32 = 36 + data_size;

        let mut wav = Vec::with_capacity(44 + data_size as usize);
        wav.extend_from_slice(b"RIFF");
        wav.extend_from_slice(&chunk_size.to_le_bytes());
        wav.extend_from_slice(b"WAVE");
        wav.extend_from_slice(b"fmt ");
        wav.extend_from_slice(&16u32.to_le_bytes());
        wav.extend_from_slice(&1u16.to_le_bytes()); // PCM
        wav.extend_from_slice(&num_channels.to_le_bytes());
        wav.extend_from_slice(&sample_rate.to_le_bytes());
        wav.extend_from_slice(&byte_rate.to_le_bytes());
        wav.extend_from_slice(&block_align.to_le_bytes());
        wav.extend_from_slice(&bits_per_sample.to_le_bytes());
        wav.extend_from_slice(b"data");
        wav.extend_from_slice(&data_size.to_le_bytes());
        for &s in pcm16 {
            wav.extend_from_slice(&s.to_le_bytes());
        }
        wav
    }

    pub fn build_prompt_hint(hotwords: &[String], max_chars: usize) -> String {
        Self::build_prompt_hint_for_locale(hotwords, max_chars, None)
    }

    pub fn build_prompt_hint_for_locale(
        hotwords: &[String],
        max_chars: usize,
        language_locale: Option<&str>,
    ) -> String {
        let prefer_latin_only = language_locale
            .and_then(Self::iso_language_code)
            .as_deref()
            == Some("en");
        let mut seen = HashSet::new();
        let mut collected = Vec::new();
        let mut total_len = 0usize;
        for raw in hotwords {
            let term = raw.trim();
            let len = term.chars().count();
            if !(2..=32).contains(&len) {
                continue;
            }
            if prefer_latin_only
                && term
                    .chars()
                    .any(|c| ('\u{4E00}'..='\u{9FFF}').contains(&c) || ('\u{3400}'..='\u{4DBF}').contains(&c))
            {
                continue;
            }
            let key = term.to_lowercase();
            if !seen.insert(key) {
                continue;
            }
            let projected = total_len + len + if collected.is_empty() { 0 } else { 2 };
            if projected > max_chars {
                break;
            }
            collected.push(term.to_string());
            total_len = projected;
        }
        collected.join(", ")
    }

    pub fn iso_language_code(speech_locale: &str) -> Option<String> {
        let trimmed = speech_locale.trim();
        if trimmed.is_empty() || trimmed.eq_ignore_ascii_case("auto") {
            return None;
        }
        if let Some((head, _)) = trimmed.split_once('-').or_else(|| trimmed.split_once('_')) {
            return Some(head.to_lowercase());
        }
        Some(trimmed.to_lowercase())
    }

    pub fn prewarm_connection(&self, base_url: &str, api_key: &str) {
        let trimmed = base_url.trim().to_string();
        if trimmed.is_empty() {
            return;
        }
        let client = self.client.clone();
        let key = api_key.trim().to_string();
        tokio::spawn(async move {
            let mut req = client.head(&trimmed).timeout(Duration::from_secs(3));
            if !key.is_empty() {
                req = req.header("Authorization", format!("Bearer {key}"));
            }
            let _ = req.send().await;
        });
    }

    pub async fn transcribe(
        &self,
        wav_data: Vec<u8>,
        base_url: &str,
        model: &str,
        api_key: &str,
        hotwords: &[String],
        language_locale: Option<&str>,
        timeout_secs: f64,
    ) -> Result<(String, u64), String> {
        let endpoint = Self::normalize_transcription_endpoint(base_url);
        let clean_key = api_key.trim();
        if clean_key.is_empty() && !PolishEngine::is_keyless_local_endpoint(base_url) {
            return Err("未配置 OpenAI / Groq 语音 API Key".to_string());
        }
        let effective_model = if model.trim().is_empty() {
            "gpt-4o-mini-transcribe".to_string()
        } else {
            model.trim().to_string()
        };

        let mut form = Form::new()
            .text("model", effective_model)
            .text("response_format", "json")
            .text("temperature", "0");

        if let Some(locale) = language_locale {
            if let Some(iso) = Self::iso_language_code(locale) {
                form = form.text("language", iso);
            }
        }
        let prompt_hint = Self::build_prompt_hint_for_locale(hotwords, 380, language_locale);
        if !prompt_hint.is_empty() {
            form = form.text("prompt", prompt_hint);
        }

        let file_part = Part::bytes(wav_data)
            .file_name("speech.wav")
            .mime_str("audio/wav")
            .map_err(|e| format!("构造 WAV 失败：{e}"))?;
        form = form.part("file", file_part);

        let mut req = self
            .client
            .post(&endpoint)
            .timeout(Duration::from_secs_f64(timeout_secs.max(4.0)))
            .multipart(form);
        if !clean_key.is_empty() {
            req = req.header("Authorization", format!("Bearer {clean_key}"));
        }

        let t0 = Instant::now();
        let resp = req
            .send()
            .await
            .map_err(|e| format!("上传语音失败：{e}"))?;
        let latency_ms = t0.elapsed().as_millis() as u64;
        let status = resp.status();
        let body_bytes = resp
            .bytes()
            .await
            .map_err(|e| format!("读取语音响应失败：{e}"))?;

        if !status.is_success() {
            let detail = Self::extract_error_message(&body_bytes)
                .unwrap_or_else(|| format!("HTTP {}", status.as_u16()));
            return Err(format!("HTTP {}：{}", status.as_u16(), detail));
        }

        if let Ok(json) = serde_json::from_slice::<Value>(&body_bytes) {
            if let Some(text) = json.get("text").and_then(|v| v.as_str()) {
                return Ok((text.trim().to_string(), latency_ms));
            }
        }
        let plain = String::from_utf8_lossy(&body_bytes).trim().to_string();
        Ok((plain, latency_ms))
    }

    pub async fn probe_latency(base_url: &str, model: &str, api_key: &str) -> Result<u64, String> {
        let sample_count = 5_600usize; // 0.35s @ 16kHz (~11.2KB)
        let mut pcm = Vec::with_capacity(sample_count);
        for i in 0..sample_count {
            let phase = (i as f64) * 2.0 * PI * 440.0 / 16_000.0;
            pcm.push((phase.sin() * 18.0) as i16);
        }
        let wav = Self::encode_pcm16_to_wav(&pcm, 16_000);
        let client = Self::new();
        let (_, ms) = client
            .transcribe(wav, base_url, model, api_key, &[], None, 8.5)
            .await?;
        Ok(ms)
    }

    fn extract_error_message(data: &[u8]) -> Option<String> {
        if let Ok(obj) = serde_json::from_slice::<Value>(data) {
            if let Some(m) = obj.pointer("/error/message").and_then(|v| v.as_str()) {
                if !m.is_empty() {
                    return Some(m.to_string());
                }
            }
            if let Some(m) = obj.get("message").and_then(|v| v.as_str()) {
                if !m.is_empty() {
                    return Some(m.to_string());
                }
            }
        }
        let s = String::from_utf8_lossy(data).trim().to_string();
        if s.is_empty() {
            None
        } else {
            Some(s.chars().take(160).collect())
        }
    }
}
