"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const express = require("express");
const nodemailer = require("nodemailer");
const { WebSocketServer, WebSocket } = require("ws");
const { CloudDB, MICRO_PER_CNY } = require("./db");

// ---------- Configuration ----------
const PORT = Number(process.env.PORT || 3890);
const DB_PATH = process.env.DB_PATH || path.join(__dirname, "data", "typezero-cloud.sqlite");
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "https://typezero.mykkai.com").replace(/\/+$/, "");
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString("hex");
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || "";

// Upstream provider credentials (NEVER sent to clients!)
const VOLC_SPEECH_API_KEY = (process.env.VOLC_SPEECH_API_KEY || "").trim();
const VOLC_RESOURCE_ID = (process.env.VOLC_RESOURCE_ID || "volc.seedasr.sauc.duration").trim();
const DEEPSEEK_API_KEY = (process.env.DEEPSEEK_API_KEY || "").trim();
const DEEPSEEK_BASE_URL = (process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com/v1").replace(/\/+$/, "");

// Google OAuth 2.0 (optional — lights up Google 1-click sign-in when configured)
const GOOGLE_CLIENT_ID = (process.env.GOOGLE_CLIENT_ID || "").trim();
const GOOGLE_CLIENT_SECRET = (process.env.GOOGLE_CLIENT_SECRET || "").trim();

// Email SMTP (optional — sends 6-digit OTP to Gmail / QQ / 163 / Outlook / any email)
const SMTP_HOST = (process.env.SMTP_HOST || "").trim();
const SMTP_PORT = Number(process.env.SMTP_PORT || 465);
const SMTP_USER = (process.env.SMTP_USER || "").trim();
const SMTP_PASS = (process.env.SMTP_PASS || "").trim();
const SMTP_FROM = (process.env.SMTP_FROM || SMTP_USER || "TypeZero <noreply@mykkai.com>").trim();

// Feishu Alert Channels (supports both Feishu App Bot Open API AND Custom Bot Webhook!)
const FEISHU_APP_ID = (process.env.FEISHU_APP_ID || process.env.FEISHU_BOT_APP_ID || "").trim();
const FEISHU_APP_SECRET = (process.env.FEISHU_APP_SECRET || process.env.FEISHU_BOT_APP_SECRET || "").trim();
const FEISHU_RECEIVE_ID = (process.env.FEISHU_RECEIVE_ID || process.env.FEISHU_CLI_NOTIFICATION_RECEIVE_ID || "").trim();
const FEISHU_API_BASE = (process.env.FEISHU_API_BASE || "https://open.feishu.cn").replace(/\/+$/, "");
const FEISHU_WEBHOOK_URL = (process.env.FEISHU_WEBHOOK_URL || "").trim();
const FEISHU_WEBHOOK_SECRET = (process.env.FEISHU_WEBHOOK_SECRET || "").trim();

// Pricing constants (micro-CNY; 100,000 = ¥1.00)
// Seed-ASR 2.0: ~¥0.008/min -> bill 14 micro-CNY/sec (~¥0.0084/min, 300 min ≈ ¥2.52)
const ASR_MICRO_CNY_PER_SEC = 14;
// DeepSeek 4 Flash: ~¥0.0003/req with KV cache -> bill by tokens (min 30 micro-CNY = ¥0.00030/req, 1500 req ≈ ¥0.45)
const LLM_MIN_MICRO_CNY_PER_REQ = 30;

// Known disposable temp-mail domains blocked from free trial abuse
const DISPOSABLE_DOMAINS = new Set([
  "tempmail.com",
  "temp-mail.org",
  "temp-mail.io",
  "guerrillamail.com",
  "guerrillamail.org",
  "guerrillamail.net",
  "10minutemail.com",
  "10minutemail.net",
  "mailinator.com",
  "yopmail.com",
  "yopmail.fr",
  "yopmail.net",
  "trashmail.com",
  "trashmail.me",
  "sharklasers.com",
  "dispostable.com",
  "maildrop.cc",
  "mohmal.com",
  "getnada.com",
  "nada.email",
  "linshi-email.com",
  "bccto.me",
  "chacuo.net",
  "027168.com",
  "mail.tm",
  "mail.gw",
  "emailondeck.com",
  "fakeinbox.com",
  "throwawaymail.com",
  "mintemail.com",
  "spamgourmet.com",
  "burnermail.io",
  "moakt.com",
  "moakt.ws",
  "tmailor.com",
  "tempr.email",
  "dropmail.me",
  "harakirimail.com",
  "mailnesia.com",
  "mytemp.email",
  "snapmail.cc",
  "mvrht.net",
]);

// ---------- Helpers ----------
function signJwt(payload, expiresInSec = 30 * 86400) {
  const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const body = Buffer.from(
    JSON.stringify({ ...payload, iat: now, exp: now + expiresInSec }),
  ).toString("base64url");
  const sig = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(`${header}.${body}`)
    .digest("base64url");
  return `${header}.${body}.${sig}`;
}

function verifyJwt(token) {
  if (!token || typeof token !== "string") return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [header, body, sig] = parts;
  const expected = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(`${header}.${body}`)
    .digest("base64url");
  const sigBuf = Buffer.from(sig);
  const expBuf = Buffer.from(expected);
  if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) return null;
  try {
    const parsed = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
    if (parsed.exp && parsed.exp < Math.floor(Date.now() / 1000)) return null;
    return parsed;
  } catch {
    return null;
  }
}

function hashOtp(email, code) {
  return crypto
    .createHmac("sha256", JWT_SECRET)
    .update(`${email.trim().toLowerCase()}:${code.trim()}`)
    .digest("hex");
}

// GitHub Release Auto-Update Feed (Stale-While-Revalidate + SQLite persisted for <50ms instant checks in CN & globally)
const GITHUB_REPO = (process.env.GITHUB_REPO || "nasadunadu/TypeZero").trim();
const SITE_DOWNLOADS_DIR = process.env.TYPEZERO_DOWNLOADS_DIR || "/srv/typezero-site/downloads";
const VERSION_CACHE_TTL_MS = 5 * 60 * 1000;
let cachedVersionManifest = null;
let cachedVersionFetchedAt = 0;
let inflightVersionRefresh = null;

function extractSha256FromText(text) {
  const m = String(text || "").match(/\b([a-f0-9]{64})\b/i);
  return m ? m[1].toLowerCase() : "";
}

function fetchWithTimeout(url, opts = {}, timeoutMs = 4500) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { ...opts, signal: controller.signal }).finally(() => clearTimeout(timer));
}

async function refreshReleaseManifestFromGitHub(db) {
  if (inflightVersionRefresh) {
    return inflightVersionRefresh;
  }
  inflightVersionRefresh = (async () => {
    const resp = await fetchWithTimeout(
      `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`,
      {
        headers: {
          Accept: "application/vnd.github+json",
          "User-Agent": "typezero-cloud-updater/1.0",
        },
      },
      4500,
    );
    if (!resp.ok) {
      throw new Error(`GitHub releases API HTTP ${resp.status}`);
    }
    const rel = await resp.json();
    const tag = String(rel.tag_name || "").trim();
    const version = tag.replace(/^v/i, "");
    const assets = Array.isArray(rel.assets) ? rel.assets : [];

    const findAssetIn = (list, re) => (Array.isArray(list) ? list : []).find((a) => re.test(String(a.name || "")));
    let macRel = rel;
    let macDmg = findAssetIn(assets, /macOS-arm64\.dmg$/i);
    let macShaAsset = findAssetIn(assets, /macOS-arm64\.dmg\.sha256$/i);
    let winRel = rel;
    let winSetup = findAssetIn(assets, /Windows-x64-setup\.exe$/i);
    let winSetupShaAsset = findAssetIn(assets, /Windows-x64-setup\.exe\.sha256$/i);
    let winPortable = findAssetIn(assets, /Windows-x64-portable\.zip$/i);

    // When a macOS-only (or Windows-only) release ships, keep the other platform pointing
    // to its most recent stable release so website / updater links never break.
    if (!winSetup || !macDmg) {
      try {
        const listResp = await fetchWithTimeout(
          `https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=10`,
          {
            headers: {
              Accept: "application/vnd.github+json",
              "User-Agent": "typezero-cloud-updater/1.0",
            },
          },
          4500,
        );
        if (listResp.ok) {
          const releases = await listResp.json();
          if (Array.isArray(releases)) {
            for (const candidate of releases) {
              if (!candidate || candidate.draft || candidate.prerelease) continue;
              const candAssets = Array.isArray(candidate.assets) ? candidate.assets : [];
              if (!macDmg) {
                const candMac = findAssetIn(candAssets, /macOS-arm64\.dmg$/i);
                if (candMac) {
                  macRel = candidate;
                  macDmg = candMac;
                  macShaAsset = findAssetIn(candAssets, /macOS-arm64\.dmg\.sha256$/i);
                }
              }
              if (!winSetup) {
                const candWin = findAssetIn(candAssets, /Windows-x64-setup\.exe$/i);
                if (candWin) {
                  winRel = candidate;
                  winSetup = candWin;
                  winSetupShaAsset = findAssetIn(candAssets, /Windows-x64-setup\.exe\.sha256$/i);
                  winPortable = findAssetIn(candAssets, /Windows-x64-portable\.zip$/i);
                }
              }
              if (macDmg && winSetup) break;
            }
          }
        }
      } catch {
        // Non-fatal: fall through to cached manifest fallback below
      }
    }

    const checkEcsMirror = (filename) => {
      if (!filename) return "";
      try {
        if (fs.existsSync(path.join(SITE_DOWNLOADS_DIR, filename))) {
          return `${PUBLIC_BASE_URL}/downloads/${filename}`;
        }
      } catch {
        // Non-fatal
      }
      return "";
    };

    const readShaAsset = async (asset) => {
      if (!asset?.browser_download_url) return "";
      try {
        const r = await fetchWithTimeout(
          asset.browser_download_url,
          { headers: { "User-Agent": "typezero-cloud-updater/1.0" } },
          2500,
        );
        if (!r.ok) return "";
        return extractSha256FromText(await r.text());
      } catch {
        return "";
      }
    };

    const macBodySha = extractSha256FromText(macRel?.body);
    const [macSha, winSha] = await Promise.all([
      macBodySha ? Promise.resolve(macBodySha) : readShaAsset(macShaAsset),
      readShaAsset(winSetupShaAsset),
    ]);

    const macTag = String(macRel?.tag_name || tag).trim();
    const winTag = String(winRel?.tag_name || tag).trim();
    const ecsMacUrl = checkEcsMirror(macDmg?.name);
    const ecsWinSetupUrl = checkEcsMirror(winSetup?.name);
    const ecsWinPortableUrl = checkEcsMirror(winPortable?.name);

    const prevMac = cachedVersionManifest?.macos;
    const prevWin = cachedVersionManifest?.windows;

    const macosEntry = macDmg
      ? {
          version: macTag.replace(/^v/i, ""),
          tag: macTag,
          dmgUrl: ecsMacUrl || macDmg.browser_download_url || "",
          fallbackDmgUrl: macDmg.browser_download_url || ecsMacUrl || "",
          fileName: macDmg.name || `TypeZero-${macTag}-macOS-arm64.dmg`,
          sizeBytes: Number(macDmg.size || 0),
          sha256: macSha || macBodySha,
        }
      : prevMac && prevMac.dmgUrl
        ? prevMac
        : {
            version: macTag.replace(/^v/i, ""),
            tag: macTag,
            dmgUrl: "",
            fallbackDmgUrl: "",
            fileName: `TypeZero-${macTag}-macOS-arm64.dmg`,
            sizeBytes: 0,
            sha256: "",
          };

    const windowsEntry = winSetup
      ? {
          version: winTag.replace(/^v/i, ""),
          tag: winTag,
          setupUrl: ecsWinSetupUrl || winSetup.browser_download_url || "",
          fallbackSetupUrl: winSetup.browser_download_url || ecsWinSetupUrl || "",
          portableUrl: ecsWinPortableUrl || winPortable?.browser_download_url || "",
          fileName: winSetup.name || `TypeZero-${winTag}-Windows-x64-setup.exe`,
          sizeBytes: Number(winSetup.size || 0),
          sha256: winSha,
        }
      : prevWin && prevWin.setupUrl
        ? prevWin
        : {
            version: winTag.replace(/^v/i, ""),
            tag: winTag,
            setupUrl: "",
            fallbackSetupUrl: "",
            portableUrl: "",
            fileName: `TypeZero-${winTag}-Windows-x64-setup.exe`,
            sizeBytes: 0,
            sha256: "",
          };

    const manifest = {
      ok: true,
      version,
      tag,
      name: String(rel.name || `TypeZero ${tag}`),
      publishedAt: rel.published_at || "",
      releaseNotes: String(rel.body || "").slice(0, 2400),
      releaseUrl: String(rel.html_url || `https://github.com/${GITHUB_REPO}/releases/tag/${tag}`),
      macos: macosEntry,
      windows: windowsEntry,
    };
    cachedVersionManifest = manifest;
    cachedVersionFetchedAt = Date.now();
    if (db) {
      try {
        db.setSetting("cached_version_manifest_json", JSON.stringify(manifest));
      } catch {
        // Non-fatal
      }
    }
    return manifest;
  })().finally(() => {
    inflightVersionRefresh = null;
  });
  return inflightVersionRefresh;
}

async function getLatestReleaseManifest(db, { forceRefresh = false, waitSync = false } = {}) {
  if (!cachedVersionManifest && db) {
    try {
      const saved = db.getSetting("cached_version_manifest_json", "");
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && parsed.version) {
          cachedVersionManifest = parsed;
        }
      }
    } catch {
      // Ignore corrupt persisted cache
    }
  }

  const now = Date.now();
  const isStale = !cachedVersionManifest || now - cachedVersionFetchedAt >= VERSION_CACHE_TTL_MS;

  if (waitSync) {
    try {
      return await refreshReleaseManifestFromGitHub(db);
    } catch (err) {
      if (cachedVersionManifest) return cachedVersionManifest;
      throw err;
    }
  }

  // Instant Stale-While-Revalidate: return cached manifest in <50ms, refresh GitHub asynchronously
  if (cachedVersionManifest) {
    if (forceRefresh || isStale) {
      refreshReleaseManifestFromGitHub(db).catch(() => {});
    }
    return cachedVersionManifest;
  }

  return refreshReleaseManifestFromGitHub(db);
}

function isVoucherCodeFormat(raw) {
  if (typeof raw !== "string") return false;
  const clean = raw.trim().toUpperCase();
  return /^TZ-[A-Z0-9]{4,}(?:-[A-Z0-9]{4,})*$/.test(clean);
}

function formatVoucherPublic(row) {
  if (!row) return null;
  const quotaSec = Number(row.quota_seconds || 0);
  const usedSec = Number(row.used_seconds || 0);
  const remSec = Math.max(0, quotaSec - usedSec);
  const status = row.status || "active";
  return {
    code: row.code,
    note: row.note || "",
    quotaSeconds: Number(quotaSec.toFixed(1)),
    usedSeconds: Number(usedSec.toFixed(1)),
    remainingSeconds: Number(remSec.toFixed(1)),
    quotaMinutes: Number((quotaSec / 60).toFixed(1)),
    usedMinutes: Number((usedSec / 60).toFixed(1)),
    remainingMinutes: Number((remSec / 60).toFixed(1)),
    sessionCount: Number(row.session_count || 0),
    status,
    exhausted: remSec <= 0,
    revoked: status !== "active",
    notifiedExhausted: Boolean(row.notified_exhausted),
    activated: Boolean(row.activated_at || Number(row.session_count || 0) > 0 || usedSec > 0),
    activatedAt: row.activated_at || row.last_used_at || null,
    createdAt: row.created_at,
    lastUsedAt: row.last_used_at || null,
  };
}

function maskWebhookUrl(url) {
  const s = String(url || "").trim();
  if (!s) return "";
  if (s.length <= 28) return "***";
  return `${s.slice(0, 36)}...${s.slice(-6)}`;
}

function feishuReceiveIdType(receiveId) {
  const id = String(receiveId || "").trim();
  if (/^ou_/.test(id)) return "open_id";
  if (/^oc_/.test(id)) return "chat_id";
  if (/^on_/.test(id)) return "union_id";
  if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(id)) return "email";
  return "chat_id";
}

function buildFeishuCardObject({ title, template = "orange", markdown }) {
  return {
    header: {
      title: { tag: "plain_text", content: title },
      template,
    },
    elements: [
      {
        tag: "markdown",
        content: markdown,
      },
    ],
  };
}

async function postFeishuAppBotCard({ appId, appSecret, receiveId, title, template = "orange", markdown }) {
  const tokResp = await fetch(`${FEISHU_API_BASE}/open-apis/auth/v3/tenant_access_token/internal`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ app_id: appId, app_secret: appSecret }),
  });
  const tokJson = await tokResp.json();
  if (!tokResp.ok || Number(tokJson.code) !== 0 || !tokJson.tenant_access_token) {
    throw new Error(`Feishu auth failed: ${tokJson.msg || tokResp.status}`);
  }

  const receiveIdType = feishuReceiveIdType(receiveId);
  const card = buildFeishuCardObject({ title, template, markdown });
  const msgResp = await fetch(
    `${FEISHU_API_BASE}/open-apis/im/v1/messages?receive_id_type=${encodeURIComponent(receiveIdType)}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${tokJson.tenant_access_token}`,
      },
      body: JSON.stringify({
        receive_id: receiveId,
        msg_type: "interactive",
        content: JSON.stringify(card),
      }),
    },
  );
  const msgJson = await msgResp.json();
  if (!msgResp.ok || Number(msgJson.code) !== 0) {
    throw new Error(`Feishu send failed: ${msgJson.msg || msgResp.status}`);
  }
  return { sent: true, channel: "app_bot", messageId: msgJson?.data?.message_id || "" };
}

async function postFeishuCard({ webhookUrl, secret = "", title, template = "orange", markdown }) {
  const url = String(webhookUrl || "").trim();
  if (!url) {
    return { sent: false, reason: "FEISHU_WEBHOOK_URL 未配置" };
  }
  const payload = {
    msg_type: "interactive",
    card: buildFeishuCardObject({ title, template, markdown }),
  };
  const cleanSecret = String(secret || "").trim();
  if (cleanSecret) {
    const timestamp = String(Math.floor(Date.now() / 1000));
    const sign = crypto
      .createHmac("sha256", `${timestamp}\n${cleanSecret}`)
      .update("")
      .digest("base64");
    payload.timestamp = timestamp;
    payload.sign = sign;
  }
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`Feishu HTTP ${resp.status}: ${text.slice(0, 160)}`);
  }
  try {
    const parsed = JSON.parse(text);
    const code = parsed.code ?? parsed.StatusCode ?? 0;
    if (Number(code) !== 0) {
      throw new Error(parsed.msg || parsed.StatusMessage || `Feishu code ${code}`);
    }
  } catch (err) {
    if (err instanceof SyntaxError) return { sent: true };
    throw err;
  }
  return { sent: true };
}

function evaluateUserTrial(row, nowMs = Date.now()) {
  const balanceMicro = Math.max(0, Number(row.balance_micro_cny || 0));
  const usedMicro = Math.max(0, Number(row.total_used_micro_cny || 0));
  const initialMicro = Math.max(
    Number(row.trial_initial_micro_cny || 0),
    balanceMicro + usedMicro,
    0,
  );
  const asrUsedSec = Math.max(0, Number(row.asr_seconds_used || 0));
  const llmUsedCount = Math.max(0, Number(row.llm_requests_used || 0));
  const asrQuotaSec = Math.max(0, Number(row.trial_asr_quota_sec ?? 18_000));
  const llmQuotaCount = Math.max(0, Number(row.trial_llm_quota_count ?? 1500));
  const expiresAt = row.trial_expires_at ? String(row.trial_expires_at) : null;
  const expiresMs = expiresAt ? Date.parse(expiresAt) : NaN;
  const hasExpiry = Number.isFinite(expiresMs) && expiresMs > 0;
  const isExpired = hasExpiry && nowMs >= expiresMs;
  const daysRemaining = hasExpiry ? Math.max(0, Math.ceil((expiresMs - nowMs) / 86400_000)) : null;

  const asrRemainingSec = Math.max(0, asrQuotaSec - asrUsedSec);
  const llmRemainingCount = Math.max(0, llmQuotaCount - llmUsedCount);

  if (!row.trial_granted && balanceMicro <= 0) {
    return {
      status: "not_granted",
      canUseAsr: false,
      canUseLlm: false,
      remainingPercent: 0,
      daysRemaining: 0,
      expiresAt,
      asrUsedMinutes: Number((asrUsedSec / 60).toFixed(1)),
      asrQuotaMinutes: Math.round(asrQuotaSec / 60),
      asrRemainingMinutes: 0,
      llmUsedCount,
      llmQuotaCount,
      llmRemainingCount: 0,
    };
  }

  const budgetExhausted = balanceMicro <= 0;
  const asrExhausted = budgetExhausted || (asrQuotaSec > 0 && asrRemainingSec <= 0);
  const llmExhausted = budgetExhausted || (llmQuotaCount > 0 && llmRemainingCount <= 0);
  const fullyExhausted = budgetExhausted || (asrExhausted && llmExhausted);

  const asrPct = asrQuotaSec > 0 ? Math.max(0, Math.min(1, asrRemainingSec / asrQuotaSec)) : 1;
  const llmPct = llmQuotaCount > 0 ? Math.max(0, Math.min(1, llmRemainingCount / llmQuotaCount)) : 1;
  const budgetPct = initialMicro > 0 ? Math.max(0, Math.min(1, balanceMicro / initialMicro)) : 0;

  let status = "active";
  let remainingPercent = Math.max(1, Math.round(Math.min(asrPct, llmPct, budgetPct) * 100));

  if (isExpired) {
    status = "expired";
    remainingPercent = 0;
  } else if (fullyExhausted || asrExhausted) {
    status = "exhausted";
    remainingPercent = 0;
  } else if (remainingPercent <= 20 || (daysRemaining !== null && daysRemaining <= 5)) {
    status = "low";
  }

  return {
    status,
    canUseAsr: !isExpired && !asrExhausted && !row.is_banned,
    canUseLlm: !isExpired && !llmExhausted && !row.is_banned,
    remainingPercent,
    daysRemaining,
    expiresAt,
    asrUsedMinutes: Number((asrUsedSec / 60).toFixed(1)),
    asrQuotaMinutes: Math.round(asrQuotaSec / 60),
    asrRemainingMinutes: Number((asrRemainingSec / 60).toFixed(1)),
    llmUsedCount,
    llmQuotaCount,
    llmRemainingCount,
  };
}

function formatUserPublic(row) {
  if (!row) return null;
  const trial = evaluateUserTrial(row);
  return {
    id: row.id,
    email: row.email,
    balanceCny: Number((row.balance_micro_cny / MICRO_PER_CNY).toFixed(4)),
    balanceMicroCny: Number(row.balance_micro_cny),
    totalUsedCny: Number((row.total_used_micro_cny / MICRO_PER_CNY).toFixed(4)),
    asrSecondsUsed: Math.round(Number(row.asr_seconds_used || 0)),
    llmRequestsUsed: Number(row.llm_requests_used || 0),
    trialGranted: Boolean(row.trial_granted),
    isBanned: Boolean(row.is_banned),
    createdAt: row.created_at,
    trial,
  };
}

function isValidEmail(email) {
  if (typeof email !== "string") return false;
  const trimmed = email.trim().toLowerCase();
  if (trimmed.length < 5 || trimmed.length > 120) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(trimmed);
}

function isDisposableEmail(email) {
  const domain = email.trim().toLowerCase().split("@")[1] || "";
  return DISPOSABLE_DOMAINS.has(domain);
}

function getClientIp(req) {
  const xff = req.headers["x-forwarded-for"];
  if (typeof xff === "string" && xff.length > 0) {
    return xff.split(",")[0].trim();
  }
  return req.socket?.remoteAddress || "unknown";
}

// In-memory rate limiters & Google desktop polling sessions
const rateWindows = new Map();
function checkRateLimit(key, maxCount, windowMs) {
  const now = Date.now();
  let bucket = rateWindows.get(key);
  if (!bucket) {
    bucket = [];
    rateWindows.set(key, bucket);
  }
  while (bucket.length > 0 && now - bucket[0] > windowMs) {
    bucket.shift();
  }
  if (bucket.length >= maxCount) return false;
  bucket.push(now);
  return true;
}

const activeLlmConcurrency = new Map();
const activeAsrConcurrency = new Map();
const recentAsrFinishGrace = new Map(); // userId -> expiresAtMs (allows final sentence LLM polish right after ASR exhausts quota)
const googleSessions = new Map(); // sessionId -> { status, deviceId, platform, token, user, expiresAt }

setInterval(() => {
  const now = Date.now();
  for (const [k, s] of googleSessions.entries()) {
    if (s.expiresAt < now) googleSessions.delete(k);
  }
  for (const [k, exp] of recentAsrFinishGrace.entries()) {
    if (exp < now) recentAsrFinishGrace.delete(k);
  }
}, 60_000).unref();

function buildMailer() {
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) return null;
  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
}

async function createApp(customDbPath, options = {}) {
  const db = await new CloudDB(customDbPath || DB_PATH).init();
  const mailer = buildMailer();
  const app = express();
  app.set("trust proxy", 1);
  app.use("/api/pet/analyze-photo", express.json({ limit: "1536kb" }));
  app.use(express.json({ limit: "256kb" }));

  function resolveFeishuConfig() {
    const settings = db.getSettings();
    const webhookUrl = settings.feishuWebhookUrl || FEISHU_WEBHOOK_URL;
    const secret = settings.feishuWebhookSecret || FEISHU_WEBHOOK_SECRET;
    const appBotReady = Boolean(FEISHU_APP_ID && FEISHU_APP_SECRET && FEISHU_RECEIVE_ID);
    return {
      appBotReady,
      appId: FEISHU_APP_ID,
      appSecret: FEISHU_APP_SECRET,
      receiveId: FEISHU_RECEIVE_ID,
      webhookUrl,
      secret,
      anyReady: appBotReady || Boolean(webhookUrl),
      channelLabel: appBotReady
        ? `飞书应用直推 (${feishuReceiveIdType(FEISHU_RECEIVE_ID)}:${FEISHU_RECEIVE_ID.slice(0, 6)}...)`
        : webhookUrl
          ? `Webhook (${maskWebhookUrl(webhookUrl)})`
          : "",
    };
  }

  async function sendFeishuNotification({ title, template = "orange", markdown }) {
    const cfg = resolveFeishuConfig();
    if (cfg.appBotReady) {
      return postFeishuAppBotCard({
        appId: cfg.appId,
        appSecret: cfg.appSecret,
        receiveId: cfg.receiveId,
        title,
        template,
        markdown,
      });
    }
    if (cfg.webhookUrl) {
      return postFeishuCard({
        webhookUrl: cfg.webhookUrl,
        secret: cfg.secret,
        title,
        template,
        markdown,
      });
    }
    throw new Error("飞书提醒通道尚未配置（请配置飞书应用或 Webhook）");
  }

  async function notifyFeishuVoucherExhausted(voucherRow) {
    const v = formatVoucherPublic(voucherRow);
    const cfg = resolveFeishuConfig();
    const title = `⏰ TypeZero 豆包语音兑换码时长已用完`;
    const markdown = [
      `**兑换码**：\`${v.code}\``,
      `**备注/朋友**：${v.note || "未填写"}`,
      `**已用 / 总额度**：${v.usedMinutes} 分钟 / ${v.quotaMinutes} 分钟（共 ${v.sessionCount} 次听写）`,
      `**状态**：已自动停止该兑换码的豆包语音中转，客户端已同步提醒用户。`,
      `[打开 TypeZero 管理后台一键续期](${PUBLIC_BASE_URL}/admin)`,
    ].join("\n");

    if (typeof options.onFeishuNotify === "function") {
      await options.onFeishuNotify({ webhookUrl: cfg.webhookUrl, title, markdown, voucher: v });
      return;
    }
    if (!cfg.anyReady) return;
    try {
      await sendFeishuNotification({ title, template: "orange", markdown });
    } catch (err) {
      console.error("[TypeZero Cloud] Feishu notify failed:", err.message);
    }
  }

  async function notifyFeishuBudgetAlert(alert) {
    const cfg = resolveFeishuConfig();
    const b = alert.snapshot;
    const isTotal = alert.kind.startsWith("total_");
    const is100 = alert.kind.endsWith("_100");
    const title = is100
      ? `🚨 TypeZero ${isTotal ? "总预算" : "今日预算"}已触达 100% 熔断`
      : `⚠️ TypeZero ${isTotal ? "总预算" : "今日预算"}已消耗达 80%`;
    const markdown = [
      `**今日消耗**：¥${(b.todaySpentMicroCny / MICRO_PER_CNY).toFixed(3)} / ¥${(b.dailyBudgetMicroCny / MICRO_PER_CNY).toFixed(2)}`,
      `**累计总消耗**：¥${(b.totalSpentMicroCny / MICRO_PER_CNY).toFixed(3)} / ¥${(b.totalBudgetMicroCny / MICRO_PER_CNY).toFixed(2)}`,
      `**当前状态**：${is100 ? "已自动触发熔断保护，避免超支" : "仍在正常运行，请提前留意水位"}`,
      `[打开 TypeZero 管理后台调整预算](${PUBLIC_BASE_URL}/admin)`,
    ].join("\n");

    if (typeof options.onFeishuNotify === "function") {
      await options.onFeishuNotify({ webhookUrl: cfg.webhookUrl, title, markdown, alertKind: alert.kind });
      return;
    }
    if (!cfg.anyReady) return;
    try {
      await sendFeishuNotification({ title, template: is100 ? "red" : "orange", markdown });
    } catch (err) {
      console.error("[TypeZero Cloud] Feishu budget alert failed:", err.message);
    }
  }

  function checkAndDispatchBudgetAlerts() {
    const alerts = db.consumePendingBudgetAlerts();
    for (const a of alerts) {
      void notifyFeishuBudgetAlert(a);
    }
  }

  // Serve Admin Console static page
  app.use("/admin", express.static(path.join(__dirname, "public")));
  app.get("/admin", (_req, res) => {
    res.sendFile(path.join(__dirname, "public", "admin.html"));
  });

  // ---------- 1. Health & Public Capabilities ----------
  app.get("/api/health", (_req, res) => {
    const budget = db.getBudgetSnapshot();
    res.json({
      ok: true,
      service: "typezero-cloud",
      version: "1.1.0",
      googleOAuthEnabled: Boolean(GOOGLE_CLIENT_ID && GOOGLE_CLIENT_SECRET),
      smtpEnabled: Boolean(mailer),
      volcAsrReady: Boolean(VOLC_SPEECH_API_KEY),
      deepseekReady: Boolean(DEEPSEEK_API_KEY),
      cloudEngineReady: Boolean(VOLC_SPEECH_API_KEY) && Boolean(DEEPSEEK_API_KEY),
      trialSignupEnabled: budget.trialSignupEnabled && budget.withinBudget,
      trialBonusCny: Number((budget.trialBonusMicroCny / MICRO_PER_CNY).toFixed(2)),
      trialDurationDays: budget.trialDurationDays,
      trialAsrMinutes: Math.round(budget.trialAsrQuotaSec / 60),
      trialLlmCount: budget.trialLlmQuotaCount,
    });
  });

  app.get("/api/version", async (req, res) => {
    const forceRefresh = String(req.query.refresh || "") === "1";
    const waitSync = String(req.query.sync || "") === "1";
    try {
      const manifest = typeof options.getVersionManifest === "function"
        ? await options.getVersionManifest()
        : await getLatestReleaseManifest(db, { forceRefresh, waitSync });
      res.setHeader("Cache-Control", "public, max-age=120");
      res.json(manifest);
    } catch (err) {
      res.status(502).json({ ok: false, error: `版本信息拉取失败：${err.message}` });
    }
  });

  // ---------- 2. Email OTP Login / Register (Gmail + Any Email) ----------
  app.post("/api/auth/email/send-code", async (req, res) => {
    const email = String(req.body?.email || "").trim().toLowerCase();
    const ip = getClientIp(req);

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: "请输入有效的邮箱地址（如 Gmail / QQ / 163 / Outlook）" });
    }
    if (isDisposableEmail(email)) {
      return res.status(403).json({ error: "暂不支持一次性临时邮箱，请使用常用邮箱（推荐 Gmail）" });
    }
    if (!checkRateLimit(`otp_ip:${ip}`, 12, 3600_000)) {
      return res.status(429).json({ error: "当前网络请求过于频繁，请稍后再试" });
    }
    if (!checkRateLimit(`otp_email:${email}`, 1, 55_000)) {
      return res.status(429).json({ error: "验证码已发送，请 60 秒后再重试" });
    }

    const code = String(crypto.randomInt(100000, 999999));
    const now = Date.now();
    const expiresAt = now + 10 * 60 * 1000;
    db.exec(
      "INSERT INTO email_otps (email, code_hash, ip, expires_at, used, created_at) VALUES (?, ?, ?, ?, 0, ?)",
      [email, hashOtp(email, code), ip, expiresAt, now],
    );

    if (!mailer) {
      return res.status(503).json({
        error: "服务器邮件发信服务尚未配置（请管理员在 ECS 配置 SMTP 或 Google OAuth）",
      });
    }

    try {
      await mailer.sendMail({
        from: SMTP_FROM,
        to: email,
        subject: `TypeZero 登录验证码：${code}`,
        text: `您的 TypeZero 登录验证码为：${code}（10 分钟内有效）。如非本人操作请忽略。`,
        html: `
          <div style="font-family: -apple-system, 'Segoe UI', sans-serif; max-width: 460px; margin: 0 auto; padding: 28px; background: #F6F5F0; border-radius: 14px; color: #17161B;">
            <h2 style="margin: 0 0 8px; font-size: 20px;">TypeZero 登录验证码</h2>
            <p style="margin: 0 0 18px; color: #66646D; font-size: 14px;">欢迎使用 TypeZero！新用户首次登录即可免费领取 1 个月 TypeZero 自研云端引擎体验（30 天 · 300 分钟语音 + 1,500 次智能成文）。</p>
            <div style="background: #FDFCF9; border: 1px solid rgba(23,22,27,0.1); border-radius: 10px; padding: 18px; text-align: center; font-size: 32px; font-weight: 700; letter-spacing: 8px; color: #5A46E8; font-family: monospace;">
              ${code}
            </div>
            <p style="margin: 16px 0 0; color: #908D97; font-size: 12px;">验证码 10 分钟内有效，请勿转发给他人。</p>
          </div>
        `,
      });
      res.json({ ok: true, message: "验证码已发送至您的邮箱，请查收（如未收到请检查垃圾邮件箱）" });
    } catch (err) {
      res.status(500).json({ error: `发送验证码邮件失败：${err.message}` });
    }
  });

  app.post("/api/auth/email/verify", (req, res) => {
    const email = String(req.body?.email || "").trim().toLowerCase();
    const code = String(req.body?.code || "").trim();
    const deviceId = String(req.body?.deviceId || "").trim();
    const platform = String(req.body?.platform || "").trim();
    const ip = getClientIp(req);

    if (!isValidEmail(email) || !/^\d{6}$/.test(code)) {
      return res.status(400).json({ error: "请输入有效的邮箱与 6 位数字验证码" });
    }
    if (!checkRateLimit(`verify_ip:${ip}`, 20, 600_000)) {
      return res.status(429).json({ error: "尝试次数过多，请稍后再试" });
    }

    const row = db.queryOne(
      "SELECT * FROM email_otps WHERE email = ? AND used = 0 ORDER BY id DESC LIMIT 1",
      [email],
    );
    if (!row || row.expires_at < Date.now() || row.code_hash !== hashOtp(email, code)) {
      return res.status(401).json({ error: "验证码无效或已过期，请重新获取" });
    }

    db.exec("UPDATE email_otps SET used = 1 WHERE id = ?", [row.id]);

    const { user, isNew, grantedTrial } = db.upsertUserAndMaybeGrantTrial({
      id: crypto.randomUUID(),
      email,
      deviceId,
      platform,
      ip,
    });
    if (user.is_banned) {
      return res.status(403).json({ error: "该账号已被暂停使用" });
    }

    const token = signJwt({ uid: user.id, email: user.email });
    res.json({
      ok: true,
      token,
      isNew,
      grantedTrial,
      user: formatUserPublic(user),
    });
  });

  // ---------- 3. Google OAuth 2.0 One-Click Login (Desktop Browser Flow) ----------
  app.post("/api/auth/google/start", (req, res) => {
    if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
      return res.status(503).json({ error: "Google 一键登录尚未配置（请使用下方邮箱验证码登录）" });
    }
    const deviceId = String(req.body?.deviceId || "").trim();
    const platform = String(req.body?.platform || "").trim();
    const sessionId = crypto.randomBytes(20).toString("hex");
    googleSessions.set(sessionId, {
      status: "pending",
      deviceId,
      platform,
      token: null,
      user: null,
      grantedTrial: false,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });

    const redirectUri = `${PUBLIC_BASE_URL}/api/auth/google/callback`;
    const params = new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      redirect_uri: redirectUri,
      response_type: "code",
      scope: "openid email profile",
      state: sessionId,
      prompt: "select_account",
    });
    res.json({
      ok: true,
      sessionId,
      authUrl: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
    });
  });

  app.get("/api/auth/google/callback", async (req, res) => {
    const code = String(req.query.code || "");
    const state = String(req.query.state || "");
    const sess = googleSessions.get(state);
    if (!code || !sess || sess.expiresAt < Date.now()) {
      return res.status(400).send("登录会话已过期，请返回 TypeZero 客户端重新点击 Google 登录。");
    }

    try {
      const redirectUri = `${PUBLIC_BASE_URL}/api/auth/google/callback`;
      const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          code,
          client_id: GOOGLE_CLIENT_ID,
          client_secret: GOOGLE_CLIENT_SECRET,
          redirect_uri: redirectUri,
          grant_type: "authorization_code",
        }),
      });
      const tokenJson = await tokenResp.json();
      if (!tokenResp.ok || !tokenJson.access_token) {
        throw new Error(tokenJson.error_description || "Google 令牌交换失败");
      }

      const infoResp = await fetch("https://openidconnect.googleapis.com/v1/userinfo", {
        headers: { Authorization: `Bearer ${tokenJson.access_token}` },
      });
      const info = await infoResp.json();
      if (!info.email || !info.email_verified) {
        throw new Error("未获取到已验证的 Google 邮箱");
      }

      const { user, grantedTrial } = db.upsertUserAndMaybeGrantTrial({
        id: crypto.randomUUID(),
        email: info.email,
        googleSub: info.sub || null,
        deviceId: sess.deviceId,
        platform: sess.platform,
      });
      if (user.is_banned) {
        throw new Error("该账号已被暂停使用");
      }

      const token = signJwt({ uid: user.id, email: user.email });
      sess.status = "completed";
      sess.token = token;
      sess.user = formatUserPublic(user);
      sess.grantedTrial = grantedTrial;

      res.send(`<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>TypeZero 登录成功</title>
        <style>body{font-family:-apple-system,"Segoe UI",sans-serif;background:#F6F5F0;color:#17161B;display:grid;place-items:center;height:100vh;margin:0}
        .card{background:#FDFCF9;border:1px solid rgba(23,22,27,.1);border-radius:16px;padding:32px 36px;text-align:center;max-width:420px;box-shadow:0 12px 32px rgba(0,0,0,.06)}
        h1{margin:0 0 8px;font-size:22px;color:#14804A}p{margin:0;color:#66646D;font-size:14px;line-height:1.6}</style></head>
        <body><div class="card"><h1>✅ Google 登录成功</h1><p>账号 <strong>${info.email}</strong> 已连接 TypeZero。<br>${
          grantedTrial ? "🎁 已为您自动发放免费体验额度！" : ""
        }<br>请直接切回 TypeZero 客户端，可安全关闭此页面。</p></div></body></html>`);
    } catch (err) {
      sess.status = "error";
      sess.error = err.message;
      res.status(400).send(`Google 登录失败：${err.message}`);
    }
  });

  app.get("/api/auth/google/poll", (req, res) => {
    const sessionId = String(req.query.session || "");
    const sess = googleSessions.get(sessionId);
    if (!sess) return res.status(404).json({ status: "expired" });
    if (sess.status === "completed") {
      const payload = {
        status: "completed",
        token: sess.token,
        user: sess.user,
        grantedTrial: sess.grantedTrial,
      };
      googleSessions.delete(sessionId);
      return res.json(payload);
    }
    if (sess.status === "error") {
      const err = sess.error || "登录失败";
      googleSessions.delete(sessionId);
      return res.status(400).json({ status: "error", error: err });
    }
    res.json({ status: "pending" });
  });

  // ---------- Auth Middleware ----------
  function requireUser(req, res, next) {
    const auth = String(req.headers.authorization || "");
    const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
    const claims = verifyJwt(token);
    if (!claims || !claims.uid) {
      return res.status(401).json({ error: "登录凭证无效或已过期，请重新登录 TypeZero 账号" });
    }
    const user = db.findUserById(claims.uid);
    if (!user) return res.status(401).json({ error: "账号不存在" });
    if (user.is_banned) return res.status(403).json({ error: "账号已被暂停使用" });
    req.user = user;
    next();
  }

  function requireAdmin(req, res, next) {
    if (!ADMIN_TOKEN) {
      return res.status(503).json({ error: "ADMIN_TOKEN 未配置" });
    }
    const headerTok = String(req.headers["x-admin-token"] || "").trim();
    if (
      headerTok.length !== ADMIN_TOKEN.length ||
      !crypto.timingSafeEqual(Buffer.from(headerTok), Buffer.from(ADMIN_TOKEN))
    ) {
      return res.status(401).json({ error: "管理员密钥无效" });
    }
    next();
  }

  // ---------- 4. Account & Balance ----------
  app.get("/api/me", requireUser, (req, res) => {
    const budget = db.getBudgetSnapshot();
    res.json({
      ok: true,
      user: formatUserPublic(req.user),
      cloudAvailable: budget.withinBudget && Boolean(VOLC_SPEECH_API_KEY) && Boolean(DEEPSEEK_API_KEY),
    });
  });

  // ---------- 4b. Doubao ASR Voucher Status (Public, Token-Gated) ----------
  app.get("/api/voucher/status", (req, res) => {
    const ip = getClientIp(req);
    if (!checkRateLimit(`voucher_status:${ip}`, 90, 60_000)) {
      return res.status(429).json({ error: "查询过于频繁，请稍后再试" });
    }
    const auth = String(req.headers.authorization || "");
    const headerCode = String(req.headers["x-voucher-code"] || "");
    const rawCode =
      (auth.startsWith("Bearer ") ? auth.slice(7).trim() : "") ||
      headerCode.trim() ||
      String(req.query.code || "").trim();
    const cleanCode = CloudDB.normalizeVoucherCode(rawCode);
    if (!isVoucherCodeFormat(cleanCode)) {
      return res.status(400).json({ error: "兑换码格式无效（应类似 TZ-XXXX-XXXX）" });
    }
    const row = db.findVoucherByCode(cleanCode);
    if (!row) {
      return res.status(404).json({ error: "兑换码不存在，请核对是否粘贴完整" });
    }
    const activatedRow = db.markVoucherActivated(row.code) || row;
    res.json({
      ok: true,
      asrReady: Boolean(VOLC_SPEECH_API_KEY),
      voucher: formatVoucherPublic(activatedRow),
    });
  });

  // ---------- 5. LLM Polishing SSE Relay (TypeZero Cloud Engine — Desensitized) ----------
  app.get("/api/llm/v1/models", requireUser, (_req, res) => {
    res.json({ object: "list", data: [{ id: "typezero-engine", object: "model" }] });
  });

  app.post("/api/llm/v1/chat/completions", requireUser, async (req, res) => {
    const budget = db.getBudgetSnapshot();
    if (!budget.withinBudget) {
      return res.status(503).json({
        error: {
          code: "GLOBAL_BUDGET_CAP",
          message: "TypeZero 云端引擎今日配额已达上限，请在「设置 → 语音与引擎」切换为自定义引擎继续无限使用",
        },
      });
    }

    const trial = evaluateUserTrial(req.user);
    const graceExp = recentAsrFinishGrace.get(req.user.id) || 0;
    const hasGracePass = graceExp > Date.now() && !req.user.is_banned;

    if (!trial.canUseLlm && !hasGracePass) {
      const isExpired = trial.status === "expired";
      return res.status(402).json({
        error: {
          code: isExpired ? "TRIAL_EXPIRED" : "TRIAL_EXHAUSTED",
          message: isExpired
            ? "你的 1 个月 TypeZero 自研云端引擎体验已到期，绑定个人 API Key 即可继续无限使用"
            : "你的 TypeZero 自研云端引擎体验额度已用完，绑定个人 API Key 即可继续无限使用",
        },
      });
    }
    if (!trial.canUseLlm && hasGracePass) {
      // Consume one-shot grace finish so final sentence completes cleanly without abrupt 402
      recentAsrFinishGrace.delete(req.user.id);
      res.setHeader("X-TypeZero-Trial-Status", trial.status);
    }

    if (!checkRateLimit(`llm_u:${req.user.id}`, 18, 60_000)) {
      return res.status(429).json({ error: { code: "RATE_LIMITED", message: "请求过于频繁，请稍候再试" } });
    }

    const curConc = activeLlmConcurrency.get(req.user.id) || 0;
    if (curConc >= 2) {
      return res.status(429).json({ error: { code: "CONCURRENCY_LIMIT", message: "并发请求过多，请稍候再试" } });
    }
    activeLlmConcurrency.set(req.user.id, curConc + 1);

    try {
      const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
      const totalChars = messages.reduce((acc, m) => acc + String(m?.content || "").length, 0);
      if (messages.length === 0 || messages.length > 4 || totalChars > 14_000) {
        return res.status(400).json({ error: { code: "INVALID_SCOPE", message: "仅限 TypeZero 语音成文场景使用" } });
      }
      // Purpose lock: ensure user message contains TypeZero speech/rewrite tags
      const userText = messages.map((m) => String(m?.content || "")).join("\n");
      const isTypeZeroPrompt =
        userText.includes("<raw_speech>") ||
        userText.includes("<voice_instruction>") ||
        userText.includes("个人词库");
      if (!isTypeZeroPrompt) {
        return res.status(403).json({
          error: { code: "PURPOSE_LOCKED", message: "TypeZero 云端引擎仅限语音成文调用，不支持通用对话" },
        });
      }
      if (!DEEPSEEK_API_KEY) {
        return res.status(503).json({ error: { code: "ENGINE_UNAVAILABLE", message: "TypeZero 云端成文引擎暂不可用，请稍后重试或切换自定义引擎" } });
      }

      const wantStream = req.body?.stream !== false;
      const upstreamPayload = {
        model: "deepseek-flash",
        stream: wantStream,
        max_tokens: Math.min(Number(req.body?.max_tokens || 600), 800),
        thinking: { type: "disabled" },
        messages,
      };
      if (wantStream) {
        upstreamPayload.stream_options = { include_usage: true };
      }

      const upstreamResp = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
          ...(wantStream ? { Accept: "text/event-stream" } : {}),
        },
        body: JSON.stringify(upstreamPayload),
      });

      if (!upstreamResp.ok) {
        return res.status(502).json({
          error: { code: "UPSTREAM_ERROR", message: "TypeZero 云端成文引擎响应异常，请稍候重试" },
        });
      }

      if (!wantStream) {
        const json = await upstreamResp.json();
        const promptToks = Number(json?.usage?.prompt_tokens || Math.ceil(totalChars * 0.7));
        const compToks = Number(json?.usage?.completion_tokens || 120);
        const costMicro = Math.max(
          LLM_MIN_MICRO_CNY_PER_REQ,
          Math.round((promptToks * 0.025 + compToks * 0.25)),
        );
        db.deductUsage({
          userId: req.user.id,
          email: req.user.email,
          service: "llm",
          model: "deepseek-flash",
          units: promptToks + compToks,
          costMicroCny: costMicro,
        });
        checkAndDispatchBudgetAlerts();
        if (json && typeof json === "object") json.model = "typezero-engine";
        return res.json(json);
      }

      res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("X-Accel-Buffering", "no");

      let outputChars = 0;
      let usageTokens = null;
      const reader = upstreamResp.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(Buffer.from(value));
        const chunkStr = decoder.decode(value, { stream: true });
        outputChars += chunkStr.length;
        const usageMatch = chunkStr.match(/"total_tokens"\s*:\s*(\d+)/);
        if (usageMatch) usageTokens = Number(usageMatch[1]);
      }
      res.end();

      const estTokens = usageTokens || Math.ceil((totalChars + outputChars * 0.25) * 0.7);
      const costMicro = Math.max(LLM_MIN_MICRO_CNY_PER_REQ, Math.round(estTokens * 0.05));
      db.deductUsage({
        userId: req.user.id,
        email: req.user.email,
        service: "llm",
        model: "deepseek-flash",
        units: estTokens,
        costMicroCny: costMicro,
      });
      checkAndDispatchBudgetAlerts();
    } catch (err) {
      if (!res.headersSent) {
        res.status(502).json({ error: { code: "RELAY_ERROR", message: "TypeZero 云端连接异常，请稍候重试" } });
      } else {
        res.end();
      }
    } finally {
      const cur = activeLlmConcurrency.get(req.user.id) || 1;
      if (cur <= 1) activeLlmConcurrency.delete(req.user.id);
      else activeLlmConcurrency.set(req.user.id, cur - 1);
    }
  });

  // ---------- 5b. Custom Pet Photo Vision DNA Extraction (`/api/pet/analyze-photo`) ----------
  const PET_PHOTO_SYSTEM_PROMPT = [
    "你是顶级猫咪品种、毛色遗传学与写实插画美术总监。请极其仔细地观察照片里猫咪的真实细节，仅输出一个纯 JSON 对象：",
    '{"breedBadge":"如 黑狸花白领巾/海双布偶/三花小猫/奶牛警长/金渐层英短","patternFamily":"solid|tuxedo_bicolor|tabby|tabby_bicolor|calico|tortoiseshell|colorpoint|ragdoll_bicolor|shaded|van","faceBlaze":"none|nose_bridge_blaze|inverted_v|skew_left|skew_right|helmet_cap|split_half|eye_patch_left|eye_patch_right|white_muzzle|seal_mask","blazeWidth":0.45,"foreheadM":false,"cheekStripes":false,"chinSpot":false,"chestBib":"none|locket|triangle_collar|full_bib","frontLeftSock":"none|mitten|high_sock","frontRightSock":"none|mitten|high_sock","hindSocks":false,"tailRings":false,"tailTipDip":false,"heterochromia":false,"primaryFurHex":"#RRGGBB","secondaryFurHex":"#RRGGBB","tertiaryFurHex":"#RRGGBB","irisLeftHex":"#RRGGBB","irisRightHex":"#RRGGBB","noseHex":"#RRGGBB","earInnerHex":"#RRGGBB","isSleekBuild":false,"cheekFullness":1.06,"earSize":1.0}',
    "关键铁律：1.只要额头有M纹或身上/腿上有条纹，哪怕带白胸也必须选 tabby 或 tabby_bicolor(foreheadM=true,cheekStripes=true,tailRings=true,tailTipDip=false)，严禁选成无条纹的 tuxedo_bicolor；2.偏黑的深色狸花猫 primaryFurHex 必须填深炭黑褐色(#38312B~#443B33)，tertiaryFurHex 填纯墨黑(#141314)，绝不能填成浅灰；3.两眼四周都是深色虎斑、白色仅顺鼻梁中间窄窄向下包住嘴套时必须选 nose_bridge_blaze；4.白毛只到脖子下方倒三角白领巾、往下胸膛仍是虎斑横纹时必须选 triangle_collar；5.前腿虎斑纹一直延伸到深色脚掌无白袜时 frontLeftSock/frontRightSock 必须填 none。"
  ].join("\n");

  app.post("/api/pet/analyze-photo", requireUser, async (req, res) => {
    const budget = db.getBudgetSnapshot();
    if (!budget.withinBudget) {
      return res.status(503).json({ error: { code: "GLOBAL_BUDGET_CAP", message: "云端配额已满，客户端将自动使用本机 Vision 提取" } });
    }
    const trial = evaluateUserTrial(req.user);
    if (!trial.canUseLlm) {
      return res.status(402).json({ error: { code: "TRIAL_ENDED", message: "云端体验已结束，客户端将自动使用本机 Vision 提取" } });
    }
    if (!checkRateLimit(`pet_photo:${req.user.id}`, 6, 60_000)) {
      return res.status(429).json({ error: { code: "RATE_LIMITED", message: "猫咪照片分析过于频繁，请稍候再试" } });
    }

    const rawList = Array.isArray(req.body?.imageDataUrls) && req.body.imageDataUrls.length > 0
      ? req.body.imageDataUrls.slice(0, 4)
      : [req.body?.imageDataUrl];
    const imageDataUrls = rawList
      .map((item) => String(item || "").trim())
      .filter((u) => u.startsWith("data:image/") && u.includes(";base64,") && u.length >= 64 && u.length <= 1_400_000);
    if (imageDataUrls.length === 0) {
      return res.status(400).json({ error: { code: "INVALID_IMAGE", message: "请上传有效的 base64 压缩猫咪图片" } });
    }

    if (typeof options.mockPetVisionHandler === "function") {
      const mockDna = await options.mockPetVisionHandler(imageDataUrls[0], req.user, imageDataUrls);
      db.deductUsage({
        userId: req.user.id,
        email: req.user.email,
        service: "llm",
        model: "deepseek-flash",
        units: 550 + imageDataUrls.length * 150,
        costMicroCny: 60,
      });
      return res.json({ ok: true, dna: mockDna, photoCount: imageDataUrls.length });
    }

    if (!DEEPSEEK_API_KEY) {
      return res.status(503).json({ error: { code: "ENGINE_UNAVAILABLE", message: "云端视觉模型未就绪" } });
    }

    const userBlocks = [
      {
        type: "text",
        text: imageDataUrls.length > 1
          ? `以上 ${imageDataUrls.length} 张照片是同一只猫咪的不同角度，请综合所有照片互补观察，输出最完整准确的唯一 JSON。`
          : "请分析这张猫咪照片的花色、开脸、五官与毛色 JSON。",
      },
      ...imageDataUrls.map((url) => ({ type: "image_url", image_url: { url } })),
    ];

    try {
      const upstreamResp = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
        },
        body: JSON.stringify({
          model: "deepseek-flash",
          stream: false,
          max_tokens: 520,
          thinking: { type: "disabled" },
          messages: [
            { role: "system", content: PET_PHOTO_SYSTEM_PROMPT },
            { role: "user", content: userBlocks },
          ],
        }),
      });
      if (!upstreamResp.ok) {
        return res.status(502).json({ error: { code: "UPSTREAM_ERROR", message: "云端视觉识别响应异常" } });
      }
      const json = await upstreamResp.json();
      const content = String(json?.choices?.[0]?.message?.content || "").trim();
      const firstBrace = content.indexOf("{");
      const lastBrace = content.lastIndexOf("}");
      if (firstBrace < 0 || lastBrace <= firstBrace) {
        return res.status(502).json({ error: { code: "PARSE_ERROR", message: "视觉特征解析失败" } });
      }
      const dna = JSON.parse(content.slice(firstBrace, lastBrace + 1));
      const totalToks = Number(json?.usage?.total_tokens || 850);
      const costMicro = Math.max(LLM_MIN_MICRO_CNY_PER_REQ, Math.round(totalToks * 0.06));
      db.deductUsage({
        userId: req.user.id,
        email: req.user.email,
        service: "llm",
        model: "deepseek-flash",
        units: totalToks,
        costMicroCny: costMicro,
      });
      checkAndDispatchBudgetAlerts();
      return res.json({ ok: true, dna });
    } catch (_err) {
      return res.status(502).json({ error: { code: "RELAY_ERROR", message: "云端视觉连接异常" } });
    }
  });

  // ---------- 6. Admin API ----------
  app.get("/api/admin/overview", requireAdmin, (_req, res) => {
    const budget = db.getBudgetSnapshot();
    const feishuCfg = resolveFeishuConfig();
    const userStats = db.queryOne(
      "SELECT COUNT(*) AS total_users, SUM(trial_granted) AS trial_users FROM users",
    );
    const users = db.queryAll(
      "SELECT * FROM users ORDER BY created_at DESC LIMIT 200",
    );
    const vouchers = db.listVouchers(200).map(formatVoucherPublic);
    const recentLogs = db.queryAll(
      "SELECT * FROM usage_logs ORDER BY id DESC LIMIT 60",
    );
    res.json({
      ok: true,
      envStatus: {
        volcAsrKeyConfigured: Boolean(VOLC_SPEECH_API_KEY),
        deepseekKeyConfigured: Boolean(DEEPSEEK_API_KEY),
        smtpConfigured: Boolean(mailer),
        googleOAuthConfigured: Boolean(GOOGLE_CLIENT_ID && GOOGLE_CLIENT_SECRET),
        feishuWebhookConfigured: feishuCfg.anyReady,
      },
      feishuWebhookMasked: feishuCfg.channelLabel,
      budget: {
        ...budget,
        trialBonusCny: Number((budget.trialBonusMicroCny / MICRO_PER_CNY).toFixed(2)),
        trialAsrMinutes: Math.round(budget.trialAsrQuotaSec / 60),
        dailyBudgetCny: Number((budget.dailyBudgetMicroCny / MICRO_PER_CNY).toFixed(2)),
        totalBudgetCny: Number((budget.totalBudgetMicroCny / MICRO_PER_CNY).toFixed(2)),
        todaySpentCny: Number((budget.todaySpentMicroCny / MICRO_PER_CNY).toFixed(4)),
        totalSpentCny: Number((budget.totalSpentMicroCny / MICRO_PER_CNY).toFixed(4)),
      },
      totalUsers: Number(userStats?.total_users || 0),
      trialUsers: Number(userStats?.trial_users || 0),
      users: users.map(formatUserPublic),
      vouchers,
      recentLogs: recentLogs.map((l) => ({
        ...l,
        costCny: Number((l.cost_micro_cny / MICRO_PER_CNY).toFixed(5)),
      })),
    });
  });

  app.post("/api/admin/feishu/config", requireAdmin, (req, res) => {
    const patch = {};
    if (typeof req.body?.webhookUrl === "string") {
      patch.feishuWebhookUrl = req.body.webhookUrl.trim();
    }
    if (typeof req.body?.secret === "string") {
      patch.feishuWebhookSecret = req.body.secret.trim();
    }
    db.updateSettings(patch);
    const cfg = resolveFeishuConfig();
    res.json({
      ok: true,
      feishuWebhookConfigured: Boolean(cfg.webhookUrl),
      feishuWebhookMasked: maskWebhookUrl(cfg.webhookUrl),
    });
  });

  app.post("/api/admin/feishu/test", requireAdmin, async (_req, res) => {
    const cfg = resolveFeishuConfig();
    if (!cfg.anyReady) {
      return res.status(400).json({ error: "请先配置飞书应用或自定义机器人 Webhook 地址" });
    }
    try {
      const result = await sendFeishuNotification({
        title: "✅ TypeZero 飞书提醒通道已连通",
        template: "green",
        markdown: [
          "TypeZero 预算水位与兑换码到期提醒已成功接入飞书！",
          "当日预算/总预算达到 80%/100% 或兑换码用完时，系统会自动推送卡片通知。",
          `[打开 TypeZero 管理后台](${PUBLIC_BASE_URL}/admin)`,
        ].join("\n"),
      });
      res.json({ ok: true, channel: result.channel || "webhook", message: "测试消息已成功发送到飞书！" });
    } catch (err) {
      res.status(502).json({ error: `飞书发送失败：${err.message}` });
    }
  });

  app.post("/api/admin/vouchers", requireAdmin, (req, res) => {
    const count = Math.min(50, Math.max(1, Math.round(Number(req.body?.count || 1))));
    const quotaMinutes = Number(req.body?.quotaMinutes ?? 500);
    if (!Number.isFinite(quotaMinutes) || quotaMinutes < 1 || quotaMinutes > 100_000) {
      return res.status(400).json({ error: "请输入有效的额度分钟数（1 ~ 100000 分钟）" });
    }
    const note = String(req.body?.note || "").trim();
    const created = db.createVouchers({ count, quotaMinutes, note }).map(formatVoucherPublic);
    res.json({ ok: true, vouchers: created });
  });

  app.post("/api/admin/vouchers/:code/update", requireAdmin, (req, res) => {
    const updated = db.updateVoucher(req.params.code, {
      note: req.body?.note,
      quotaMinutes: req.body?.quotaMinutes,
      addMinutes: req.body?.addMinutes,
      status: req.body?.status,
    });
    if (!updated) return res.status(404).json({ error: "兑换码不存在" });
    res.json({ ok: true, voucher: formatVoucherPublic(updated) });
  });

  app.post("/api/admin/settings", requireAdmin, (req, res) => {
    const patch = {};
    if (req.body?.trialBonusCny !== undefined) {
      patch.trialBonusMicroCny = Math.max(0, Math.round(Number(req.body.trialBonusCny) * MICRO_PER_CNY));
    }
    if (req.body?.trialDurationDays !== undefined) {
      patch.trialDurationDays = Math.max(1, Math.round(Number(req.body.trialDurationDays)));
    }
    if (req.body?.trialAsrMinutes !== undefined) {
      patch.trialAsrQuotaSec = Math.max(60, Math.round(Number(req.body.trialAsrMinutes) * 60));
    }
    if (req.body?.trialLlmCount !== undefined) {
      patch.trialLlmQuotaCount = Math.max(10, Math.round(Number(req.body.trialLlmCount)));
    }
    if (req.body?.dailyBudgetCny !== undefined) {
      patch.dailyBudgetMicroCny = Math.max(0, Math.round(Number(req.body.dailyBudgetCny) * MICRO_PER_CNY));
    }
    if (req.body?.totalBudgetCny !== undefined) {
      patch.totalBudgetMicroCny = Math.max(0, Math.round(Number(req.body.totalBudgetCny) * MICRO_PER_CNY));
    }
    if (typeof req.body?.trialSignupEnabled === "boolean") {
      patch.trialSignupEnabled = req.body.trialSignupEnabled;
    }
    if (typeof req.body?.relayEnabled === "boolean") {
      patch.relayEnabled = req.body.relayEnabled;
    }
    const updated = db.updateSettings(patch);
    res.json({ ok: true, settings: updated });
  });

  app.post("/api/admin/users/:id/grant", requireAdmin, (req, res) => {
    const user = db.findUserById(req.params.id);
    if (!user) return res.status(404).json({ error: "用户不存在" });
    const addCny = Number(req.body?.amountCny || 0);
    const addDays = Number(req.body?.addDays || 0);
    const addAsrMinutes = Number(req.body?.addAsrMinutes || 0);
    const addLlmCount = Number(req.body?.addLlmCount || 0);
    if (!Number.isFinite(addCny) || (addCny === 0 && addDays === 0 && addAsrMinutes === 0 && addLlmCount === 0)) {
      return res.status(400).json({ error: "请输入有效的增减额度" });
    }
    const updated = db.grantUserExtra({
      userId: user.id,
      amountCny: addCny,
      addDays,
      addAsrMinutes,
      addLlmCount,
    });
    res.json({ ok: true, user: formatUserPublic(updated) });
  });

  app.post("/api/admin/users/:id/ban", requireAdmin, (req, res) => {
    const user = db.findUserById(req.params.id);
    if (!user) return res.status(404).json({ error: "用户不存在" });
    const banned = req.body?.banned ? 1 : 0;
    db.exec("UPDATE users SET is_banned = ? WHERE id = ?", [banned, user.id]);
    db.flushSync();
    res.json({ ok: true, user: formatUserPublic(db.findUserById(user.id)) });
  });

  // ---------- 7. Volcengine Seed-ASR 2.0 Binary WebSocket Relay ----------
  const server = http.createServer(app);
  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (req, socket, head) => {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname !== "/api/asr/ws") {
      socket.destroy();
      return;
    }

    const authHeader = String(req.headers.authorization || "");
    const headerApiKey = String(req.headers["x-api-key"] || "");
    const headerVoucher = String(req.headers["x-voucher-code"] || "");
    const rawToken =
      url.searchParams.get("token") ||
      (authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "") ||
      headerVoucher.trim() ||
      headerApiKey.trim();

    let sessionPrincipal = null; // { kind: 'voucher', voucher } | { kind: 'user', user }
    let concurrencyKey = "";
    let maxSessionMs = 180_000;

    if (isVoucherCodeFormat(rawToken)) {
      const voucher = db.findVoucherByCode(rawToken);
      if (!voucher) {
        socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
        socket.destroy();
        return;
      }
      if ((voucher.status || "active") !== "active") {
        socket.write("HTTP/1.1 403 Forbidden\r\n\r\n");
        socket.destroy();
        return;
      }
      const settings = db.getSettings();
      const remSec = Number(voucher.quota_seconds || 0) - Number(voucher.used_seconds || 0);
      if (remSec <= 0 || !settings.relayEnabled || !VOLC_SPEECH_API_KEY) {
        socket.write("HTTP/1.1 402 Payment Required\r\n\r\n");
        socket.destroy();
        return;
      }
      concurrencyKey = `voucher:${voucher.code}`;
      const curAsr = activeAsrConcurrency.get(concurrencyKey) || 0;
      if (curAsr >= 2) {
        socket.write("HTTP/1.1 429 Too Many Requests\r\n\r\n");
        socket.destroy();
        return;
      }
      maxSessionMs = Math.min(180_000, Math.max(5_000, Math.ceil(remSec * 1000) + 3_000));
      sessionPrincipal = { kind: "voucher", voucher };
    } else {
      const claims = verifyJwt(rawToken);
      if (!claims || !claims.uid) {
        socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
        socket.destroy();
        return;
      }
      const user = db.findUserById(claims.uid);
      const budget = db.getBudgetSnapshot();
      const trial = user ? evaluateUserTrial(user) : null;
      if (!user || user.is_banned || !trial?.canUseAsr || !budget.withinBudget || !VOLC_SPEECH_API_KEY) {
        socket.write("HTTP/1.1 402 Payment Required\r\n\r\n");
        socket.destroy();
        return;
      }
      concurrencyKey = `user:${user.id}`;
      const curAsr = activeAsrConcurrency.get(concurrencyKey) || 0;
      if (curAsr >= 2) {
        socket.write("HTTP/1.1 429 Too Many Requests\r\n\r\n");
        socket.destroy();
        return;
      }
      sessionPrincipal = { kind: "user", user };
    }

    wss.handleUpgrade(req, socket, head, (clientWs) => {
      const curAsrNow = activeAsrConcurrency.get(concurrencyKey) || 0;
      activeAsrConcurrency.set(concurrencyKey, curAsrNow + 1);
      const startedAt = Date.now();
      let billed = false;
      let clientFrameCount = 0;
      const pendingFrames = [];

      const upstreamWs = new WebSocket("wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async", {
        headers: {
          "X-Api-Key": VOLC_SPEECH_API_KEY,
          "X-Api-Resource-Id": VOLC_RESOURCE_ID,
          "X-Api-Connect-Id": crypto.randomUUID(),
          "X-Api-Request-Id": crypto.randomUUID(),
        },
      });

      // Hard max session duration (180s or remaining voucher duration)
      const maxTimer = setTimeout(() => {
        try {
          clientWs.close(1000, "Max session duration reached");
          upstreamWs.close();
        } catch {}
      }, maxSessionMs);

      const finalizeBilling = () => {
        if (billed) return;
        billed = true;
        clearTimeout(maxTimer);
        const cur = activeAsrConcurrency.get(concurrencyKey) || 1;
        if (cur <= 1) activeAsrConcurrency.delete(concurrencyKey);
        else activeAsrConcurrency.set(concurrencyKey, cur - 1);

        const rawDurSec = Math.max(0.1, (Date.now() - startedAt) / 1000);
        if (sessionPrincipal.kind === "voucher") {
          // Ignore tiny handshake probe (2 frames: init + 100ms silent frame) from session count / heavy billing
          const isQuickProbe = clientFrameCount <= 2 && rawDurSec < 0.8;
          if (isQuickProbe) return;
          const durSec = Math.max(0.5, rawDurSec);
          const costMicro = Math.max(10, Math.round(durSec * ASR_MICRO_CNY_PER_SEC));
          const { voucher: updatedVoucher, justExhausted } = db.recordVoucherUsage({
            code: sessionPrincipal.voucher.code,
            durationSeconds: durSec,
            model: VOLC_RESOURCE_ID,
            costMicroCny: costMicro,
            countSession: true,
          });
          if (justExhausted && updatedVoucher) {
            void notifyFeishuVoucherExhausted(updatedVoucher);
          }
          checkAndDispatchBudgetAlerts();
        } else {
          const user = sessionPrincipal.user;
          const durSec = Math.max(0.5, rawDurSec);
          const costMicro = Math.max(10, Math.round(durSec * ASR_MICRO_CNY_PER_SEC));
          db.deductUsage({
            userId: user.id,
            email: user.email,
            service: "asr",
            model: VOLC_RESOURCE_ID,
            units: Number(durSec.toFixed(2)),
            costMicroCny: costMicro,
          });
          // Grant a 20s one-shot grace window so the trailing LLM polish for this final sentence never fails mid-flight
          recentAsrFinishGrace.set(user.id, Date.now() + 20_000);
          checkAndDispatchBudgetAlerts();
        }
      };

      upstreamWs.on("open", () => {
        for (const frame of pendingFrames) {
          upstreamWs.send(frame, { binary: true });
        }
        pendingFrames.length = 0;
      });

      upstreamWs.on("message", (data, isBinary) => {
        if (clientWs.readyState === WebSocket.OPEN) {
          clientWs.send(data, { binary: isBinary });
        }
      });

      upstreamWs.on("close", () => {
        finalizeBilling();
        if (clientWs.readyState === WebSocket.OPEN) clientWs.close();
      });

      upstreamWs.on("error", () => {
        finalizeBilling();
        if (clientWs.readyState === WebSocket.OPEN) clientWs.close(1011, "Upstream ASR error");
      });

      clientWs.on("message", (data) => {
        clientFrameCount += 1;
        if (upstreamWs.readyState === WebSocket.OPEN) {
          upstreamWs.send(data, { binary: true });
        } else if (upstreamWs.readyState === WebSocket.CONNECTING && pendingFrames.length < 32) {
          pendingFrames.push(data);
        }
      });

      clientWs.on("close", () => {
        finalizeBilling();
        if (upstreamWs.readyState === WebSocket.OPEN || upstreamWs.readyState === WebSocket.CONNECTING) {
          upstreamWs.close();
        }
      });

      clientWs.on("error", () => {
        finalizeBilling();
        upstreamWs.terminate();
      });
    });
  });

  return { app, server, db, signJwt, hashOtp, notifyFeishuVoucherExhausted, evaluateUserTrial, checkAndDispatchBudgetAlerts };
}

if (require.main === module) {
  createApp()
    .then(({ server, db }) => {
      server.listen(PORT, "127.0.0.1", () => {
        console.log(`TypeZero Cloud Gateway listening on http://127.0.0.1:${PORT}`);
        // Warm release manifest immediately & keep fresh every 10 min in background
        getLatestReleaseManifest(db, { forceRefresh: true }).catch(() => {});
        setInterval(() => {
          refreshReleaseManifestFromGitHub(db).catch(() => {});
        }, 10 * 60 * 1000).unref();
      });
      const shutdown = () => {
        db.flushSync();
        process.exit(0);
      };
      process.on("SIGINT", shutdown);
      process.on("SIGTERM", shutdown);
    })
    .catch((err) => {
      console.error("Failed to start TypeZero Cloud Gateway:", err);
      process.exit(1);
    });
}

module.exports = { createApp, MICRO_PER_CNY };
