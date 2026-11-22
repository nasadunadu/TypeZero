"use strict";

const crypto = require("node:crypto");
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

// Pricing constants (micro-CNY; 100,000 = ¥1.00)
// Seed-ASR 2.0: ~¥0.008/min = 800 micro-CNY/min ≈ 13.4 micro-CNY/sec -> bill 16 micro-CNY/sec (~¥0.0096/min, 60 min ≈ ¥0.58)
const ASR_MICRO_CNY_PER_SEC = 16;
// DeepSeek 4 Flash: ~¥0.0004/req average with KV cache -> bill by tokens (min 35 micro-CNY = ¥0.00035/req)
const LLM_MIN_MICRO_CNY_PER_REQ = 35;

// Known disposable temp-mail domains blocked from free trial abuse
const DISPOSABLE_DOMAINS = new Set([
  "tempmail.com",
  "temp-mail.org",
  "guerrillamail.com",
  "10minutemail.com",
  "mailinator.com",
  "yopmail.com",
  "trashmail.com",
  "sharklasers.com",
  "dispostable.com",
  "maildrop.cc",
  "mohmal.com",
  "getnada.com",
  "linshi-email.com",
  "bccto.me",
  "chacuo.net",
  "027168.com",
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

function formatUserPublic(row) {
  if (!row) return null;
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
const googleSessions = new Map(); // sessionId -> { status, deviceId, platform, token, user, expiresAt }

setInterval(() => {
  const now = Date.now();
  for (const [k, s] of googleSessions.entries()) {
    if (s.expiresAt < now) googleSessions.delete(k);
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

async function createApp(customDbPath) {
  const db = await new CloudDB(customDbPath || DB_PATH).init();
  const mailer = buildMailer();
  const app = express();
  app.set("trust proxy", 1);
  app.use(express.json({ limit: "256kb" }));

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
      version: "1.0.0",
      googleOAuthEnabled: Boolean(GOOGLE_CLIENT_ID && GOOGLE_CLIENT_SECRET),
      smtpEnabled: Boolean(mailer),
      volcAsrReady: Boolean(VOLC_SPEECH_API_KEY),
      deepseekReady: Boolean(DEEPSEEK_API_KEY),
      trialSignupEnabled: budget.trialSignupEnabled && budget.withinBudget,
      trialBonusCny: Number((budget.trialBonusMicroCny / MICRO_PER_CNY).toFixed(2)),
    });
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
            <p style="margin: 0 0 18px; color: #66646D; font-size: 14px;">欢迎使用 TypeZero！新用户首次登录即可领取免费语音 + 排版体验额度。</p>
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

  // ---------- 5. LLM Polishing SSE Relay (Purpose-Locked to DeepSeek 4 Flash) ----------
  app.get("/api/llm/v1/models", requireUser, (_req, res) => {
    res.json({ object: "list", data: [{ id: "deepseek-flash", object: "model" }] });
  });

  app.post("/api/llm/v1/chat/completions", requireUser, async (req, res) => {
    const budget = db.getBudgetSnapshot();
    if (!budget.withinBudget) {
      return res.status(503).json({
        error: { message: "今日官方免费体验预算已达上限，请配置您自己的 API Key 继续免费无限使用" },
      });
    }
    if (Number(req.user.balance_micro_cny) <= 0) {
      return res.status(402).json({
        error: { message: "免费体验额度已用完，请在「引擎与快捷键」填入您自己的 API Key 继续无限使用" },
      });
    }
    if (!checkRateLimit(`llm_u:${req.user.id}`, 18, 60_000)) {
      return res.status(429).json({ error: { message: "请求过于频繁，请稍候再试" } });
    }

    const curConc = activeLlmConcurrency.get(req.user.id) || 0;
    if (curConc >= 2) {
      return res.status(429).json({ error: { message: "并发请求过多" } });
    }
    activeLlmConcurrency.set(req.user.id, curConc + 1);

    try {
      const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
      const totalChars = messages.reduce((acc, m) => acc + String(m?.content || "").length, 0);
      if (messages.length === 0 || messages.length > 4 || totalChars > 14_000) {
        return res.status(400).json({ error: { message: "仅限 TypeZero 语音排版场景使用" } });
      }
      // Purpose lock: ensure user message contains TypeZero speech/rewrite tags
      const userText = messages.map((m) => String(m?.content || "")).join("\n");
      const isTypeZeroPrompt =
        userText.includes("<raw_speech>") ||
        userText.includes("<voice_instruction>") ||
        userText.includes("个人词库");
      if (!isTypeZeroPrompt) {
        return res.status(403).json({
          error: { message: "官方体验通道仅限 TypeZero 语音排版调用，不支持通用对话" },
        });
      }
      if (!DEEPSEEK_API_KEY) {
        return res.status(503).json({ error: { message: "服务端 DeepSeek Key 未配置" } });
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
        const errText = await upstreamResp.text();
        return res.status(upstreamResp.status).send(errText);
      }

      if (!wantStream) {
        const json = await upstreamResp.json();
        const promptToks = Number(json?.usage?.prompt_tokens || Math.ceil(totalChars * 0.7));
        const compToks = Number(json?.usage?.completion_tokens || 120);
        const costMicro = Math.max(
          LLM_MIN_MICRO_CNY_PER_REQ,
          Math.round((promptToks * 0.03 + compToks * 0.3)),
        );
        db.deductUsage({
          userId: req.user.id,
          email: req.user.email,
          service: "llm",
          model: "deepseek-flash",
          units: promptToks + compToks,
          costMicroCny: costMicro,
        });
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
      const costMicro = Math.max(LLM_MIN_MICRO_CNY_PER_REQ, Math.round(estTokens * 0.06));
      db.deductUsage({
        userId: req.user.id,
        email: req.user.email,
        service: "llm",
        model: "deepseek-flash",
        units: estTokens,
        costMicroCny: costMicro,
      });
    } catch (err) {
      if (!res.headersSent) {
        res.status(502).json({ error: { message: `中转上游异常：${err.message}` } });
      } else {
        res.end();
      }
    } finally {
      const cur = activeLlmConcurrency.get(req.user.id) || 1;
      if (cur <= 1) activeLlmConcurrency.delete(req.user.id);
      else activeLlmConcurrency.set(req.user.id, cur - 1);
    }
  });

  // ---------- 6. Admin API ----------
  app.get("/api/admin/overview", requireAdmin, (_req, res) => {
    const budget = db.getBudgetSnapshot();
    const userStats = db.queryOne(
      "SELECT COUNT(*) AS total_users, SUM(trial_granted) AS trial_users FROM users",
    );
    const users = db.queryAll(
      "SELECT * FROM users ORDER BY created_at DESC LIMIT 200",
    );
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
      },
      budget: {
        ...budget,
        trialBonusCny: Number((budget.trialBonusMicroCny / MICRO_PER_CNY).toFixed(2)),
        dailyBudgetCny: Number((budget.dailyBudgetMicroCny / MICRO_PER_CNY).toFixed(2)),
        totalBudgetCny: Number((budget.totalBudgetMicroCny / MICRO_PER_CNY).toFixed(2)),
        todaySpentCny: Number((budget.todaySpentMicroCny / MICRO_PER_CNY).toFixed(4)),
        totalSpentCny: Number((budget.totalSpentMicroCny / MICRO_PER_CNY).toFixed(4)),
      },
      totalUsers: Number(userStats?.total_users || 0),
      trialUsers: Number(userStats?.trial_users || 0),
      users: users.map(formatUserPublic),
      recentLogs: recentLogs.map((l) => ({
        ...l,
        costCny: Number((l.cost_micro_cny / MICRO_PER_CNY).toFixed(5)),
      })),
    });
  });

  app.post("/api/admin/settings", requireAdmin, (req, res) => {
    const patch = {};
    if (req.body?.trialBonusCny !== undefined) {
      patch.trialBonusMicroCny = Math.max(0, Math.round(Number(req.body.trialBonusCny) * MICRO_PER_CNY));
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
    const addMicro = Math.round(addCny * MICRO_PER_CNY);
    if (!Number.isFinite(addMicro) || addMicro === 0) {
      return res.status(400).json({ error: "请输入有效的增减金额" });
    }
    db.exec(
      "UPDATE users SET balance_micro_cny = MAX(0, balance_micro_cny + ?) WHERE id = ?",
      [addMicro, user.id],
    );
    db.flushSync();
    res.json({ ok: true, user: formatUserPublic(db.findUserById(user.id)) });
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
    const rawToken =
      url.searchParams.get("token") ||
      (authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "") ||
      headerApiKey.trim();

    const claims = verifyJwt(rawToken);
    if (!claims || !claims.uid) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
      return;
    }
    const user = db.findUserById(claims.uid);
    const budget = db.getBudgetSnapshot();
    if (!user || user.is_banned || Number(user.balance_micro_cny) <= 0 || !budget.withinBudget || !VOLC_SPEECH_API_KEY) {
      socket.write("HTTP/1.1 402 Payment Required\r\n\r\n");
      socket.destroy();
      return;
    }
    const curAsr = activeAsrConcurrency.get(user.id) || 0;
    if (curAsr >= 2) {
      socket.write("HTTP/1.1 429 Too Many Requests\r\n\r\n");
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (clientWs) => {
      activeAsrConcurrency.set(user.id, curAsr + 1);
      const startedAt = Date.now();
      let billed = false;
      const pendingFrames = [];

      const upstreamWs = new WebSocket("wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async", {
        headers: {
          "X-Api-Key": VOLC_SPEECH_API_KEY,
          "X-Api-Resource-Id": VOLC_RESOURCE_ID,
          "X-Api-Connect-Id": crypto.randomUUID(),
          "X-Api-Request-Id": crypto.randomUUID(),
        },
      });

      // Hard max session duration: 180s to prevent orphaned connections draining quota
      const maxTimer = setTimeout(() => {
        try {
          clientWs.close(1000, "Max session duration reached");
          upstreamWs.close();
        } catch {}
      }, 180_000);

      const finalizeBilling = () => {
        if (billed) return;
        billed = true;
        clearTimeout(maxTimer);
        const cur = activeAsrConcurrency.get(user.id) || 1;
        if (cur <= 1) activeAsrConcurrency.delete(user.id);
        else activeAsrConcurrency.set(user.id, cur - 1);

        const durSec = Math.max(0.5, (Date.now() - startedAt) / 1000);
        const costMicro = Math.max(10, Math.round(durSec * ASR_MICRO_CNY_PER_SEC));
        db.deductUsage({
          userId: user.id,
          email: user.email,
          service: "asr",
          model: VOLC_RESOURCE_ID,
          units: Number(durSec.toFixed(2)),
          costMicroCny: costMicro,
        });
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

  return { app, server, db, signJwt, hashOtp };
}

if (require.main === module) {
  createApp()
    .then(({ server, db }) => {
      server.listen(PORT, "127.0.0.1", () => {
        console.log(`TypeZero Cloud Gateway listening on http://127.0.0.1:${PORT}`);
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
