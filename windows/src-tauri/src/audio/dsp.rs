use once_cell::sync::Lazy;
use parking_lot::Mutex;
use std::f64::consts::PI;

/// Zero-overhead real-time audio envelope & micro-symbol rhythm bus.
/// Decouples 90Hz microphone buffer callbacks from main app state while feeding smooth 60/120fps telemetry to the floating pill.
pub struct AudioLevelBus {
    inner: Mutex<AudioLevelState>,
}

struct AudioLevelState {
    raw_target: f32,
    display_envelope: f32,
    target_symbol_count: usize,
    display_symbol_progress: f64,
}

static GLOBAL_BUS: Lazy<AudioLevelBus> = Lazy::new(AudioLevelBus::new);

impl AudioLevelBus {
    fn new() -> Self {
        Self {
            inner: Mutex::new(AudioLevelState {
                raw_target: 0.06,
                display_envelope: 0.06,
                target_symbol_count: 0,
                display_symbol_progress: 0.0,
            }),
        }
    }

    pub fn shared() -> &'static Self {
        &GLOBAL_BUS
    }

    pub fn push(&self, level: f32) {
        let mut g = self.inner.lock();
        g.raw_target = level.clamp(0.05, 1.0);
    }

    pub fn push_recognized_count(&self, count: usize) {
        let mut g = self.inner.lock();
        g.target_symbol_count = count;
    }

    pub fn reset(&self) {
        let mut g = self.inner.lock();
        g.raw_target = 0.05;
        g.display_envelope = 0.05;
        g.target_symbol_count = 0;
        g.display_symbol_progress = 0.0;
    }

    /// Fast-attack, smooth-release ballistic envelope.
    pub fn sample_ballistic_envelope(&self) -> f32 {
        let mut g = self.inner.lock();
        let coeff = if g.raw_target > g.display_envelope {
            0.38
        } else {
            0.14
        };
        g.display_envelope += (g.raw_target - g.display_envelope) * coeff;
        g.display_envelope
    }

    pub fn sample_recognized_symbol_progress(&self) -> (f64, usize) {
        let mut g = self.inner.lock();
        let target_d = g.target_symbol_count as f64;
        if target_d > g.display_symbol_progress {
            let delta = target_d - g.display_symbol_progress;
            let step = (delta * 0.24).max(0.32);
            g.display_symbol_progress = (g.display_symbol_progress + step).min(target_d);
        } else if target_d < g.display_symbol_progress {
            g.display_symbol_progress += (target_d - g.display_symbol_progress) * 0.30;
        }
        (g.display_symbol_progress, g.target_symbol_count)
    }

    pub fn current_recognized_count(&self) -> usize {
        self.inner.lock().target_symbol_count
    }
}

/// Calculates normalized UI meter level [0.06, 1.0] and raw RMS amplitude.
pub fn calculate_rms_metrics(samples: &[f32]) -> (f32, f32) {
    if samples.is_empty() {
        return (0.05, 0.0);
    }
    let mut sum = 0.0f32;
    let mut count = 0usize;
    let step = if samples.len() >= 16 { 4 } else { 1 };
    let mut i = 0;
    while i < samples.len() {
        let s = samples[i];
        sum += s * s;
        count += 1;
        i += step;
    }
    let rms = (sum / (count.max(1) as f32)).sqrt();
    let db = 20.0 * rms.max(0.000_1).log10();
    let norm = ((db + 50.0) / 42.0).clamp(0.06, 1.0);
    (norm, rms)
}

/// Soft-Knee Automatic Gain Control (25dB Whisper Boost):
/// Boosts low-volume whispers up to 7.5x with `tanh` soft-limiting so loud speech never clips.
pub fn boost_quiet_speech_agc(samples: &[f32]) -> Vec<f32> {
    if samples.is_empty() {
        return Vec::new();
    }
    let stride = (samples.len() / 2000).max(1);
    let mut sum_sq = 0.0f32;
    let mut active_count = 0usize;
    let mut i = 0;
    while i < samples.len() {
        let v = samples[i].abs();
        if v > 0.0015 {
            sum_sq += v * v;
            active_count += 1;
        }
        i += stride;
    }
    if active_count <= 12 {
        return samples.to_vec();
    }
    let active_rms = (sum_sq / active_count as f32).sqrt();
    if active_rms >= 0.065 {
        return samples.to_vec();
    }
    let target_rms = 0.085f32;
    let gain = (target_rms / active_rms.max(0.0018)).clamp(1.0, 7.5);
    if gain <= 1.15 {
        return samples.to_vec();
    }

    let mut out = Vec::with_capacity(samples.len());
    for &s in samples {
        let amplified = s * gain;
        if amplified > 0.6 || amplified < -0.6 {
            out.push(amplified.tanh());
        } else {
            out.push(amplified);
        }
    }
    out
}

/// Real-time frame-level whisper AGC for streaming 16kHz Seed-ASR frames.
pub fn apply_streaming_whisper_agc(samples: &[f32], raw_rms: f32, is_voice: bool) -> Vec<f32> {
    if is_voice && raw_rms > 0.0018 && raw_rms < 0.045 {
        let gain = (0.065 / raw_rms).clamp(1.0, 4.5);
        samples
            .iter()
            .map(|&s| {
                let v = s * gain;
                if v > 0.65 || v < -0.65 {
                    v.tanh()
                } else {
                    v
                }
            })
            .collect()
    } else {
        samples.to_vec()
    }
}

/// Windowed-sinc anti-aliasing resampler from arbitrary hardware rate (e.g. 48kHz / 44.1kHz) to 16kHz Int16 mono.
/// Preserves Mandarin sibilant clarity without aliasing foldback!
pub fn resample_float_to_16khz_int16(samples: &[f32], source_rate: f64) -> Vec<i16> {
    if samples.is_empty() || source_rate <= 0.0 {
        return Vec::new();
    }
    let target_rate = 16_000.0f64;
    if (source_rate - target_rate).abs() < 1.0 {
        return samples
            .iter()
            .map(|&s| (s.clamp(-1.0, 1.0) * 32767.0).round() as i16)
            .collect();
    }

    let ratio = source_rate / target_rate;
    let out_len = ((samples.len() as f64) / ratio).round() as usize;
    if out_len == 0 {
        return Vec::new();
    }

    // Cutoff slightly below Nyquist of 16kHz (7.2kHz) with Hann-windowed sinc kernel
    let cutoff = (target_rate * 0.45) / source_rate; // normalized cycles per input sample
    let half_width: isize = ((6.0 * ratio).ceil() as isize).clamp(6, 24);
    let n = samples.len() as isize;
    let mut out = Vec::with_capacity(out_len);

    for j in 0..out_len {
        let center = (j as f64) * ratio;
        let center_idx = center.floor() as isize;
        let mut acc = 0.0f64;
        let mut weight_sum = 0.0f64;

        let start = (center_idx - half_width).max(0);
        let end = (center_idx + half_width).min(n - 1);

        for k in start..=end {
            let dist = (k as f64) - center;
            let norm_w = dist / (half_width as f64);
            if norm_w.abs() >= 1.0 {
                continue;
            }
            // Hann window * sinc(2 * cutoff * dist)
            let window = 0.5 * (1.0 + (PI * norm_w).cos());
            let x = 2.0 * PI * cutoff * dist;
            let sinc = if x.abs() < 1e-8 { 1.0 } else { x.sin() / x };
            let w = window * sinc;
            acc += (samples[k as usize] as f64) * w;
            weight_sum += w;
        }

        let val = if weight_sum.abs() > 1e-9 {
            (acc / weight_sum) as f32
        } else {
            0.0
        };
        out.push((val.clamp(-1.0, 1.0) * 32767.0).round() as i16);
    }

    out
}

/// Downmixes interleaved multi-channel f32 audio into mono f32.
pub fn downmix_to_mono(interleaved: &[f32], channels: usize) -> Vec<f32> {
    if channels <= 1 {
        return interleaved.to_vec();
    }
    let frames = interleaved.len() / channels;
    let mut mono = Vec::with_capacity(frames);
    let inv = 1.0 / (channels as f32);
    for frame in interleaved.chunks_exact(channels) {
        let sum: f32 = frame.iter().copied().sum();
        mono.push(sum * inv);
    }
    mono
}
