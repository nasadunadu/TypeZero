use serde::{Deserialize, Serialize};
use std::path::Path;
use std::time::Duration;
use uuid::Uuid;

pub const CLOUD_BASE_URL: &str = "https://typezero.mykkai.com";
pub const CLOUD_ASR_WS_URL: &str = "wss://typezero.mykkai.com/api/asr/ws";
pub const CLOUD_LLM_BASE_URL: &str = "https://typezero.mykkai.com/api/llm/v1";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudUserProfile {
    pub id: String,
    pub email: String,
    pub balance_cny: f64,
    #[serde(default)]
    pub balance_micro_cny: i64,
    #[serde(default)]
    pub total_used_cny: f64,
    #[serde(default)]
    pub asr_seconds_used: i64,
    #[serde(default)]
    pub llm_requests_used: i64,
    #[serde(default)]
    pub trial_granted: bool,
    #[serde(default)]
    pub is_banned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudAuthSuccess {
    pub ok: bool,
    pub token: String,
    #[serde(default)]
    pub is_new: bool,
    #[serde(default)]
    pub granted_trial: bool,
    pub user: CloudUserProfile,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudGoogleStartResponse {
    pub ok: bool,
    pub session_id: String,
    pub auth_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudGooglePollResponse {
    pub status: String,
    pub token: Option<String>,
    pub user: Option<CloudUserProfile>,
    #[serde(default)]
    pub granted_trial: bool,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudVoucherProfile {
    pub code: String,
    #[serde(default)]
    pub note: String,
    #[serde(default)]
    pub quota_seconds: f64,
    #[serde(default)]
    pub used_seconds: f64,
    #[serde(default)]
    pub remaining_seconds: f64,
    #[serde(default)]
    pub quota_minutes: f64,
    #[serde(default)]
    pub used_minutes: f64,
    #[serde(default)]
    pub remaining_minutes: f64,
    #[serde(default)]
    pub session_count: i64,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub exhausted: bool,
    #[serde(default)]
    pub revoked: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CloudVoucherResp {
    asr_ready: bool,
    voucher: CloudVoucherProfile,
}

#[derive(Debug, Deserialize)]
struct CloudMeResp {
    user: CloudUserProfile,
}

#[derive(Debug, Deserialize)]
struct CloudErrResp {
    error: Option<String>,
    message: Option<String>,
}

fn http_client() -> reqwest::Client {
    reqwest::Client::builder()
        .timeout(Duration::from_secs(15))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new())
}

pub fn load_or_create_device_id(data_dir: &Path) -> String {
    let path = data_dir.join("cloud_device_id.txt");
    if let Ok(existing) = std::fs::read_to_string(&path) {
        let trimmed = existing.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    let fresh = format!("win-{}", Uuid::new_v4());
    let _ = std::fs::write(&path, &fresh);
    fresh
}

fn parse_err(status: reqwest::StatusCode, body: &str) -> String {
    if let Ok(e) = serde_json::from_str::<CloudErrResp>(body) {
        if let Some(m) = e.error.or(e.message) {
            if !m.trim().is_empty() {
                return m;
            }
        }
    }
    format!("云端服务返回 HTTP {}", status.as_u16())
}

pub async fn send_email_code(email: &str) -> Result<String, String> {
    let resp = http_client()
        .post(format!("{CLOUD_BASE_URL}/api/auth/email/send-code"))
        .json(&serde_json::json!({ "email": email.trim() }))
        .send()
        .await
        .map_err(|e| format!("无法连接 TypeZero 云端服务：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(parse_err(status, &text));
    }
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) {
        if let Some(m) = v.get("message").and_then(|x| x.as_str()) {
            return Ok(m.to_string());
        }
    }
    Ok("验证码已发送至您的邮箱，请查收".to_string())
}

pub async fn verify_email_code(
    email: &str,
    code: &str,
    device_id: &str,
) -> Result<CloudAuthSuccess, String> {
    let resp = http_client()
        .post(format!("{CLOUD_BASE_URL}/api/auth/email/verify"))
        .json(&serde_json::json!({
            "email": email.trim(),
            "code": code.trim(),
            "deviceId": device_id,
            "platform": "windows"
        }))
        .send()
        .await
        .map_err(|e| format!("无法连接 TypeZero 云端服务：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(parse_err(status, &text));
    }
    serde_json::from_str::<CloudAuthSuccess>(&text)
        .map_err(|e| format!("登录响应解析失败：{e}"))
}

pub async fn start_google_login(device_id: &str) -> Result<CloudGoogleStartResponse, String> {
    let resp = http_client()
        .post(format!("{CLOUD_BASE_URL}/api/auth/google/start"))
        .json(&serde_json::json!({
            "deviceId": device_id,
            "platform": "windows"
        }))
        .send()
        .await
        .map_err(|e| format!("无法连接 TypeZero 云端服务：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(parse_err(status, &text));
    }
    serde_json::from_str::<CloudGoogleStartResponse>(&text)
        .map_err(|e| format!("Google 登录初始化解析失败：{e}"))
}

pub async fn poll_google_login(session_id: &str) -> Result<CloudGooglePollResponse, String> {
    let resp = http_client()
        .get(format!("{CLOUD_BASE_URL}/api/auth/google/poll"))
        .query(&[("session", session_id)])
        .send()
        .await
        .map_err(|e| format!("轮询 Google 登录状态失败：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if status.as_u16() == 404 {
        return Ok(CloudGooglePollResponse {
            status: "expired".to_string(),
            token: None,
            user: None,
            granted_trial: false,
            error: Some("登录会话已过期".to_string()),
        });
    }
    if let Ok(parsed) = serde_json::from_str::<CloudGooglePollResponse>(&text) {
        return Ok(parsed);
    }
    Err(parse_err(status, &text))
}

pub fn normalized_voucher_code(raw: &str) -> String {
    raw.trim().to_uppercase()
}

pub fn is_voucher_code(raw: &str) -> bool {
    let clean = normalized_voucher_code(raw);
    clean.starts_with("TZ-")
        && clean.len() >= 10
        && clean
            .bytes()
            .all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b == b'-')
}

pub async fn fetch_voucher_status(code: &str) -> Result<(bool, CloudVoucherProfile), String> {
    let clean = normalized_voucher_code(code);
    if !is_voucher_code(&clean) {
        return Err("兑换码格式无效（应类似 TZ-XXXX-XXXX）".to_string());
    }
    let resp = http_client()
        .get(format!("{CLOUD_BASE_URL}/api/voucher/status"))
        .bearer_auth(&clean)
        .send()
        .await
        .map_err(|e| format!("无法连接 TypeZero 云端校验兑换码：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(parse_err(status, &text));
    }
    let parsed = serde_json::from_str::<CloudVoucherResp>(&text)
        .map_err(|e| format!("兑换码状态解析失败：{e}"))?;
    Ok((parsed.asr_ready, parsed.voucher))
}

pub async fn fetch_profile(token: &str) -> Result<CloudUserProfile, String> {
    let resp = http_client()
        .get(format!("{CLOUD_BASE_URL}/api/me"))
        .bearer_auth(token.trim())
        .send()
        .await
        .map_err(|e| format!("无法获取云端账号状态：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(parse_err(status, &text));
    }
    serde_json::from_str::<CloudMeResp>(&text)
        .map(|r| r.user)
        .map_err(|e| format!("云端账号信息解析失败：{e}"))
}
