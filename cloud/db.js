"use strict";

const fs = require("node:fs");
const path = require("node:path");
const initSqlJs = require("sql.js");

// Currency unit: micro-CNY (100,000 micro-CNY = ¥1.00)
const MICRO_PER_CNY = 100_000;

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

      CREATE INDEX IF NOT EXISTS idx_usage_day ON usage_logs(day_key);
      CREATE INDEX IF NOT EXISTS idx_usage_user ON usage_logs(user_id);
      CREATE INDEX IF NOT EXISTS idx_otp_email ON email_otps(email);
    `);

    const defaults = {
      trial_bonus_micro_cny: String(100_000), // ¥1.00
      daily_budget_micro_cny: String(3_000_000), // ¥30.00 / day
      total_budget_micro_cny: String(50_000_000), // ¥500.00 total
      trial_signup_enabled: "1",
      relay_enabled: "1",
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
    };
  }

  updateSettings(patch) {
    const mapping = {
      trialBonusMicroCny: "trial_bonus_micro_cny",
      dailyBudgetMicroCny: "daily_budget_micro_cny",
      totalBudgetMicroCny: "total_budget_micro_cny",
      trialSignupEnabled: "trial_signup_enabled",
      relayEnabled: "relay_enabled",
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
}

module.exports = { CloudDB, MICRO_PER_CNY };
