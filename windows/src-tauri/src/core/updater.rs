use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Duration;

pub const CURRENT_APP_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowsReleaseAsset {
    #[serde(default)]
    pub setup_url: String,
    #[serde(default)]
    pub fallback_setup_url: String,
    #[serde(default)]
    pub portable_url: String,
    #[serde(default)]
    pub file_name: String,
    #[serde(default)]
    pub size_bytes: u64,
    #[serde(default)]
    pub sha256: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppVersionManifest {
    #[serde(default)]
    pub ok: bool,
    pub version: String,
    pub tag: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub published_at: String,
    #[serde(default)]
    pub release_notes: String,
    #[serde(default)]
    pub release_url: String,
    pub windows: Option<WindowsReleaseAsset>,
}

/// Semantic version comparator: returns `true` iff `remote` is strictly newer than `current`.
pub fn is_newer_version(remote: &str, current: &str) -> bool {
    fn parse_parts(v: &str) -> Vec<u32> {
        let trimmed = v.trim().trim_start_matches(['v', 'V']);
        let core = trimmed.split('-').next().unwrap_or(trimmed);
        core.split('.')
            .map(|p| p.parse::<u32>().unwrap_or(0))
            .collect()
    }
    let r = parse_parts(remote);
    let c = parse_parts(current);
    let len = r.len().max(c.len());
    for i in 0..len {
        let rv = *r.get(i).unwrap_or(&0);
        let cv = *c.get(i).unwrap_or(&0);
        if rv != cv {
            return rv > cv;
        }
    }
    false
}

pub async fn fetch_latest_manifest(force_refresh: bool) -> Result<AppVersionManifest, String> {
    let base = format!("{}/api/version", crate::core::cloud::CLOUD_BASE_URL);
    let url = if force_refresh {
        format!("{base}?refresh=1")
    } else {
        base
    };
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(15))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new());
    let resp = client
        .get(&url)
        .send()
        .await
        .map_err(|e| format!("无法连接版本更新服务：{e}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(format!("版本服务返回 HTTP {}", status.as_u16()));
    }
    serde_json::from_str::<AppVersionManifest>(&text)
        .map_err(|e| format!("版本清单解析失败：{e}"))
}

pub async fn download_and_launch_windows_installer<F>(
    manifest: &AppVersionManifest,
    mut on_progress: F,
) -> Result<PathBuf, String>
where
    F: FnMut(f64, String) + Send,
{
    let asset = manifest
        .windows
        .as_ref()
        .ok_or_else(|| "更新清单中未包含 Windows 安装包".to_string())?;
    let candidates: Vec<String> = [asset.setup_url.trim(), asset.fallback_setup_url.trim()]
        .into_iter()
        .filter(|s| !s.is_empty())
        .map(ToString::to_string)
        .collect();
    if candidates.is_empty() {
        return Err("Windows 安装包下载地址无效".to_string());
    }

    let work_dir = std::env::temp_dir().join("TypeZero-Update");
    std::fs::create_dir_all(&work_dir).map_err(|e| format!("创建临时更新目录失败：{e}"))?;
    let file_name = if asset.file_name.trim().is_empty() {
        format!("TypeZero-{}-Windows-x64-setup.exe", manifest.tag)
    } else {
        asset.file_name.trim().to_string()
    };
    let dest = work_dir.join(&file_name);

    let client = reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(12))
        .timeout(Duration::from_secs(180))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new());

    on_progress(0.05, "正在连接高速下载节点…".to_string());
    let mut last_err = "无可用下载节点".to_string();
    let mut downloaded = false;

    for (idx, url) in candidates.iter().enumerate() {
        match stream_download(&client, url, &dest, asset.size_bytes, &mut on_progress).await {
            Ok(()) => {
                downloaded = true;
                break;
            }
            Err(err) => {
                last_err = err;
                if idx + 1 < candidates.len() {
                    on_progress(0.08, "主节点较慢，自动切换备用高速线路…".to_string());
                }
            }
        }
    }
    if !downloaded {
        return Err(format!("下载安装包失败：{last_err}"));
    }

    let expected_sha = asset.sha256.trim().to_lowercase();
    if expected_sha.len() == 64 {
        on_progress(0.92, "正在校验安装包完整性 (SHA-256)…".to_string());
        verify_sha256(&dest, &expected_sha)?;
    }

    on_progress(0.98, format!("正在启动 TypeZero {} 安装程序…", manifest.tag));
    Command::new(&dest)
        .spawn()
        .map_err(|e| format!("启动安装程序失败：{e}"))?;
    Ok(dest)
}

async fn stream_download<F>(
    client: &reqwest::Client,
    url: &str,
    dest: &Path,
    expected_size: u64,
    on_progress: &mut F,
) -> Result<(), String>
where
    F: FnMut(f64, String),
{
    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| format!("网络请求失败：{e}"))?;
    if !resp.status().is_success() {
        return Err(format!("HTTP {}", resp.status().as_u16()));
    }
    let total = resp.content_length().unwrap_or(expected_size);
    let mut file =
        std::fs::File::create(dest).map_err(|e| format!("写入本地临时文件失败：{e}"))?;
    let mut stream = resp.bytes_stream();
    let mut received: u64 = 0;
    let mut last_pct: i32 = -1;

    while let Some(chunk_res) = stream.next().await {
        let chunk = chunk_res.map_err(|e| format!("下载中断：{e}"))?;
        file.write_all(&chunk)
            .map_err(|e| format!("磁盘写入失败：{e}"))?;
        received += chunk.len() as u64;
        if total > 0 {
            let frac = (received as f64 / total as f64).clamp(0.0, 1.0);
            let pct = (frac * 100.0) as i32;
            if pct != last_pct {
                last_pct = pct;
                let mb_done = received as f64 / 1_048_576.0;
                let mb_total = total as f64 / 1_048_576.0;
                on_progress(
                    0.06 + frac * 0.84,
                    format!("正在下载新版安装包 {mb_done:.1} / {mb_total:.1} MB ({pct}%)…"),
                );
            }
        }
    }
    file.flush().map_err(|e| format!("落盘失败：{e}"))?;
    if received < 500_000 {
        return Err(format!("安装包体积异常（仅 {received} 字节）"));
    }
    Ok(())
}

fn verify_sha256(path: &Path, expected_hex: &str) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    let output = Command::new("certutil")
        .args(["-hashfile", &path.to_string_lossy(), "SHA256"])
        .output()
        .map_err(|e| format!("无法调用 certutil 校验哈希：{e}"))?;

    #[cfg(not(target_os = "windows"))]
    let output = Command::new("shasum")
        .args(["-a", "256", &path.to_string_lossy()])
        .output()
        .map_err(|e| format!("无法调用 shasum 校验哈希：{e}"))?;

    if !output.status.success() {
        return Err("系统哈希校验工具返回异常".to_string());
    }
    let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
    let actual = stdout
        .split_whitespace()
        .find(|tok| tok.len() == 64 && tok.bytes().all(|b| b.is_ascii_hexdigit()))
        .unwrap_or("");
    if actual != expected_hex {
        return Err("安装包 SHA-256 校验未通过，已中止升级".to_string());
    }
    Ok(())
}
