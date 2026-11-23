"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const initSqlJs = require("sql.js");

// Currency unit: micro-CNY (100,000 micro-CNY = ¥1.00)
const MICRO_PER_CNY = 100_000;
const VOUCHER_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

class CloudDB {
  constructor(dbFilePath) {
    this.dbFilePath = dbFilePath;
    this.db = null;
    this.saveTimer = null;
  }

  async init() {
    const SQL = await initSqlJs();
    const dir = path.dirname(this.dbFilePath);
    fs.mkdirSync(dir, { recursive: true });

    if (fs.existsSync(this.dbFilePath)) {
      const buf = fs.readFileSync(this.dbFilePath);
      this.db = new SQL.Database(buf);
    } else {
      this.db = new SQL.Database();
    }

    this.db.run(`
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        google_sub TEXT,
        platform TEXT DEFAULT '',
        device_id TEXT DEFAULT '',
        balance_micro_cny INTEGER NOT NULL DEFAULT 0,
        total_used_micro_cny INTEGER NOT NULL DEFAULT 0,
        asr_seconds_used REAL NOT NULL DEFAULT 0,
        llm_requests_used INTEGER NOT NULL DEFAULT 0,
        trial_granted INTEGER NOT NULL DEFAULT 0,
        is_banned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS device_claims (
        device_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        claimed_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS email_otps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        code_hash TEXT NOT NULL,
        ip TEXT NOT NULL,
        expires_at INTEGER NOT NULL,
        used INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS usage_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        service TEXT NOT NULL,
        model TEXT NOT NULL,
        units REAL NOT NULL,
        cost_micro_cny INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        day_key TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS voucher_codes (
        code TEXT PRIMARY KEY,
        note TEXT NOT NULL DEFAULT '',
        quota_seconds REAL NOT NULL DEFAULT 30000,
        used_seconds REAL NOT NULL DEFAULT 0,
        session_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        notified_exhausted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        activated_at TEXT,
        last_used_at TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_usage_day ON usage_logs(day_key);
      CREATE INDEX IF NOT EXISTS idx_usage_user ON usage_logs(user_id);
      CREATE INDEX IF NOT EXISTS idx_otp_email ON email_otps(email);
      CREATE INDEX IF NOT EXISTS idx_voucher_created ON voucher_codes(created_at);
    `);

    // Safe forward migration for existing DBs created before activated_at existed
    try {
      this.db.run("ALTER TABLE voucher_codes ADD COLUMN activated_at TEXT");
    } catch (_) {
      // Column already exists
    }

    const defaults = {
      trial_bonus_micro_cny: String(100_000), // ¥1.00
      daily_budget_micro_cny: String(3_000_000), // ¥30.00 / day
      total_budget_micro_cny: String(50_000_000), // ¥500.00 total
      trial_signup_enabled: "1",
      relay_enabled: "1",
      feishu_webhook_url: "",
      feishu_webhook_secret: "",
    };
    for (const [k, v] of Object.entries(defaults)) {
      this.db.run("INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)", [k, v]);
    }

    this.flushSync();
    return this;
  }

  scheduleSave() {
    if (this.saveTimer) return;
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      this.flushSync();
    }, 800);
    if (typeof this.saveTimer.unref === "function") this.saveTimer.unref();
  }

  flushSync() {
    if (this.saveTimer) {
      clearTimeout(this.saveTimer);
      this.saveTimer = null;
    }
    if (!this.db) return;
    const data = this.db.export();
    const tmp = `${this.dbFilePath}.tmp`;
    fs.writeFileSync(tmp, Buffer.from(data));
    fs.renameSync(tmp, this.dbFilePath);
  }

  queryOne(sql, params = []) {
    const stmt = this.db.prepare(sql);
    try {
      stmt.bind(params);
      if (stmt.step()) {
        return stmt.getAsObject();
      }
      return null;
    } finally {
      stmt.free();
    }
  }

  queryAll(sql, params = []) {
    const stmt = this.db.prepare(sql);
    const rows = [];
    try {
      stmt.bind(params);
      while (stmt.step()) {
        rows.push(stmt.getAsObject());
      }
      return rows;
    } finally {
      stmt.free();
    }
  }

  exec(sql, params = []) {
    this.db.run(sql, params);
    this.scheduleSave();
  }

  getSettings() {
    const rows = this.queryAll("SELECT key, value FROM settings");
    const map = {};
    for (const r of rows) map[r.key] = r.value;
    return {
      trialBonusMicroCny: Number(map.trial_bonus_micro_cny || 100_000),
      dailyBudgetMicroCny: Number(map.daily_budget_micro_cny || 3_000_000),
      totalBudgetMicroCny: Number(map.total_budget_micro_cny || 50_000_000),
      trialSignupEnabled: map.trial_signup_enabled !== "0",
      relayEnabled: map.relay_enabled !== "0",
      feishuWebhookUrl: String(map.feishu_webhook_url || "").trim(),
      feishuWebhookSecret: String(map.feishu_webhook_secret || "").trim(),
    };
  }

  updateSettings(patch) {
    const mapping = {
      trialBonusMicroCny: "trial_bonus_micro_cny",
      dailyBudgetMicroCny: "daily_budget_micro_cny",
      totalBudgetMicroCny: "total_budget_micro_cny",
      trialSignupEnabled: "trial_signup_enabled",
      relayEnabled: "relay_enabled",
      feishuWebhookUrl: "feishu_webhook_url",
      feishuWebhookSecret: "feishu_webhook_secret",
    };
    for (const [k, dbKey] of Object.entries(mapping)) {
      if (patch[k] !== undefined) {
        const val = typeof patch[k] === "boolean" ? (patch[k] ? "1" : "0") : String(patch[k]);
        this.exec("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [dbKey, val]);
      }
    }
    this.flushSync();
    return this.getSettings();
  }

  todayKey() {
    // Asia/Shanghai day key (UTC+8)
    const now = new Date(Date.now() + 8 * 3600 * 1000);
    return now.toISOString().slice(0, 10);
  }

  getBudgetSnapshot() {
    const cfg = this.getSettings();
    const today = this.todayKey();
    const todayRow = this.queryOne(
      "SELECT COALESCE(SUM(cost_micro_cny), 0) AS total FROM usage_logs WHERE day_key = ?",
      [today],
    );
    const allRow = this.queryOne(
      "SELECT COALESCE(SUM(cost_micro_cny), 0) AS total FROM usage_logs",
    );
    const todaySpent = Number(todayRow?.total || 0);
    const totalSpent = Number(allRow?.total || 0);
    const withinDaily = todaySpent < cfg.dailyBudgetMicroCny;
    const withinTotal = totalSpent < cfg.totalBudgetMicroCny;

    return {
      ...cfg,
      todayKey: today,
      todaySpentMicroCny: todaySpent,
      totalSpentMicroCny: totalSpent,
      withinBudget: cfg.relayEnabled && withinDaily && withinTotal,
      remainingDailyMicroCny: Math.max(0, cfg.dailyBudgetMicroCny - todaySpent),
      remainingTotalMicroCny: Math.max(0, cfg.totalBudgetMicroCny - totalSpent),
    };
  }

  findUserByEmail(email) {
    return this.queryOne("SELECT * FROM users WHERE LOWER(email) = LOWER(?)", [email.trim()]);
  }

  findUserById(id) {
    return this.queryOne("SELECT * FROM users WHERE id = ?", [id]);
  }

  upsertUserAndMaybeGrantTrial({ id, email, googleSub = null, deviceId = "", platform = "" }) {
    const cleanEmail = email.trim().toLowerCase();
    const now = new Date().toISOString();
    let user = this.findUserByEmail(cleanEmail);

    if (user) {
      this.exec(
        "UPDATE users SET last_seen_at = ?, google_sub = COALESCE(?, google_sub), platform = CASE WHEN ? != '' THEN ? ELSE platform END WHERE id = ?",
        [now, googleSub, platform, platform, user.id],
      );
      return { user: this.findUserById(user.id), isNew: false, grantedTrial: false };
    }

    const budget = this.getBudgetSnapshot();
    const cleanDevice = (deviceId || "").trim().slice(0, 128);
    let canGrant = budget.trialSignupEnabled && budget.withinBudget;

    if (canGrant && cleanDevice) {
      const existingClaim = this.queryOne("SELECT device_id FROM device_claims WHERE device_id = ?", [
        cleanDevice,
      ]);
      if (existingClaim) {
        canGrant = false;
      }
    }

    const initialBalance = canGrant ? budget.trialBonusMicroCny : 0;
    this.exec(
      `INSERT INTO users (id, email, google_sub, platform, device_id, balance_micro_cny, trial_granted, created_at, last_seen_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, cleanEmail, googleSub, platform, cleanDevice, initialBalance, canGrant ? 1 : 0, now, now],
    );

    if (canGrant && cleanDevice) {
      this.exec(
        "INSERT OR IGNORE INTO device_claims (device_id, user_id, claimed_at) VALUES (?, ?, ?)",
        [cleanDevice, id, now],
      );
    }
    this.flushSync();
    return { user: this.findUserById(id), isNew: true, grantedTrial: canGrant };
  }

  deductUsage({ userId, email, service, model, units, costMicroCny }) {
    const cost = Math.max(1, Math.round(costMicroCny));
    const now = new Date().toISOString();
    const dayKey = this.todayKey();

    if (service === "asr") {
      this.exec(
        `UPDATE users
         SET balance_micro_cny = MAX(0, balance_micro_cny - ?),
             total_used_micro_cny = total_used_micro_cny + ?,
             asr_seconds_used = asr_seconds_used + ?,
             last_seen_at = ?
         WHERE id = ?`,
        [cost, cost, units, now, userId],
      );
    } else {
      this.exec(
        `UPDATE users
         SET balance_micro_cny = MAX(0, balance_micro_cny - ?),
             total_used_micro_cny = total_used_micro_cny + ?,
             llm_requests_used = llm_requests_used + 1,
             last_seen_at = ?
         WHERE id = ?`,
        [cost, cost, now, userId],
      );
    }

    this.exec(
      `INSERT INTO usage_logs (user_id, email, service, model, units, cost_micro_cny, created_at, day_key)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, email, service, model, units, cost, now, dayKey],
    );
  }

  // ---------- Doubao ASR Voucher Codes ----------

  static normalizeVoucherCode(raw) {
    return String(raw || "").trim().toUpperCase();
  }

  static generateVoucherCode() {
    const pick = (n) => {
      const bytes = crypto.randomBytes(n);
      let s = "";
      for (let i = 0; i < n; i++) {
        s += VOUCHER_ALPHABET[bytes[i] % VOUCHER_ALPHABET.length];
      }
      return s;
    };
    return `TZ-${pick(4)}-${pick(4)}`;
  }

  findVoucherByCode(code) {
    const clean = CloudDB.normalizeVoucherCode(code);
    if (!clean) return null;
    return this.queryOne("SELECT * FROM voucher_codes WHERE UPPER(code) = ?", [clean]);
  }

  listVouchers(limit = 200) {
    return this.queryAll("SELECT * FROM voucher_codes ORDER BY created_at DESC LIMIT ?", [limit]);
  }

  createVouchers({ count = 1, quotaMinutes = 500, note = "" }) {
    const n = Math.min(50, Math.max(1, Math.round(Number(count) || 1)));
    const mins = Math.max(1, Number(quotaMinutes) || 500);
    const quotaSec = Math.round(mins * 60);
    const cleanNote = String(note || "").trim().slice(0, 80);
    const now = new Date().toISOString();
    const created = [];

    for (let i = 0; i < n; i++) {
      let code = CloudDB.generateVoucherCode();
      while (this.findVoucherByCode(code)) {
        code = CloudDB.generateVoucherCode();
      }
      const itemNote = n > 1 && cleanNote ? `${cleanNote} #${i + 1}` : cleanNote;
      this.exec(
        `INSERT INTO voucher_codes (code, note, quota_seconds, used_seconds, session_count, status, notified_exhausted, created_at, activated_at, last_used_at)
         VALUES (?, ?, ?, 0, 0, 'active', 0, ?, NULL, NULL)`,
        [code, itemNote, quotaSec, now],
      );
      created.push(this.findVoucherByCode(code));
    }
    this.flushSync();
    return created;
  }

  updateVoucher(code, { note, quotaMinutes, addMinutes, status } = {}) {
    const row = this.findVoucherByCode(code);
    if (!row) return null;

    let nextNote = row.note || "";
    if (note !== undefined) {
      nextNote = String(note || "").trim().slice(0, 80);
    }

    let nextQuotaSec = Number(row.quota_seconds || 0);
    if (quotaMinutes !== undefined && Number.isFinite(Number(quotaMinutes)) && Number(quotaMinutes) >= 0) {
      nextQuotaSec = Math.round(Number(quotaMinutes) * 60);
    } else if (addMinutes !== undefined && Number.isFinite(Number(addMinutes)) && Number(addMinutes) !== 0) {
      nextQuotaSec = Math.max(0, Math.round(nextQuotaSec + Number(addMinutes) * 60));
    }

    let nextStatus = row.status || "active";
    if (status === "active" || status === "revoked") {
      nextStatus = status;
    }

    const usedSec = Number(row.used_seconds || 0);
    const nextNotified = nextQuotaSec > usedSec ? 0 : Number(row.notified_exhausted || 0);

    this.exec(
      `UPDATE voucher_codes
       SET note = ?, quota_seconds = ?, status = ?, notified_exhausted = ?
       WHERE code = ?`,
      [nextNote, nextQuotaSec, nextStatus, nextNotified, row.code],
    );
    this.flushSync();
    return this.findVoucherByCode(row.code);
  }

  markVoucherActivated(code) {
    const row = this.findVoucherByCode(code);
    if (!row) return null;
    if (row.activated_at) return row;
    const now = new Date().toISOString();
    this.exec(
      `UPDATE voucher_codes SET activated_at = COALESCE(activated_at, ?) WHERE code = ?`,
      [now, row.code],
    );
    this.flushSync();
    return this.findVoucherByCode(row.code);
  }

  recordVoucherUsage({ code, durationSeconds, model, costMicroCny, countSession = true }) {
    const row = this.findVoucherByCode(code);
    if (!row) return { voucher: null, justExhausted: false };

    const dur = Math.max(0.1, Number(durationSeconds) || 0);
    const cost = Math.max(1, Math.round(costMicroCny || dur * 16));
    const now = new Date().toISOString();
    const dayKey = this.todayKey();

    const prevUsed = Number(row.used_seconds || 0);
    const quotaSec = Number(row.quota_seconds || 0);
    const nextUsed = Number((prevUsed + dur).toFixed(2));
    const wasNotified = Number(row.notified_exhausted || 0) === 1;
    const isNowExhausted = nextUsed >= quotaSec;
    const justExhausted = isNowExhausted && !wasNotified;
    const nextNotified = justExhausted || wasNotified ? 1 : 0;

    this.exec(
      `UPDATE voucher_codes
       SET used_seconds = ?,
           session_count = session_count + ?,
           notified_exhausted = ?,
           activated_at = COALESCE(activated_at, ?),
           last_used_at = ?
       WHERE code = ?`,
      [nextUsed, countSession ? 1 : 0, nextNotified, now, now, row.code],
    );

    const displayLabel = row.note ? `[兑换码] ${row.note} (${row.code})` : `[兑换码] ${row.code}`;
    this.exec(
      `INSERT INTO usage_logs (user_id, email, service, model, units, cost_micro_cny, created_at, day_key)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [`voucher:${row.code}`, displayLabel, "asr_voucher", model, Number(dur.toFixed(2)), cost, now, dayKey],
    );
    this.flushSync();
    return { voucher: this.findVoucherByCode(row.code), justExhausted };
  }
}

module.exports = { CloudDB, MICRO_PER_CNY };
