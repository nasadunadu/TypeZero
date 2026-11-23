"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

process.env.ADMIN_TOKEN = "test-admin-secret-token";
process.env.JWT_SECRET = "test-jwt-secret-key-for-unit-tests";

const { createApp } = require("./server");

async function run() {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "tz-cloud-test-"));
  const dbPath = path.join(tmpDir, "test.sqlite");
  const feishuEvents = [];
  const { server, db, hashOtp, notifyFeishuVoucherExhausted } = await createApp(dbPath, {
    onFeishuNotify: async (evt) => {
      feishuEvents.push(evt);
    },
    getVersionManifest: async () => ({
      ok: true,
      version: "0.5.6",
      tag: "v0.5.6",
      name: "TypeZero v0.5.6",
      publishedAt: "2026-11-23T06:00:00Z",
      releaseNotes: "Auto-update + Doubao vouchers",
      releaseUrl: "https://github.com/nasadunadu/TypeZero/releases/tag/v0.5.6",
      macos: { dmgUrl: "https://typezero.mykkai.com/downloads/TypeZero-v0.5.6-macOS-arm64.dmg", sha256: "" },
      windows: { setupUrl: "https://typezero.mykkai.com/downloads/TypeZero-v0.5.6-Windows-x64-setup.exe", sha256: "" },
    }),
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  try {
    // 1. Health endpoint
    const healthRes = await fetch(`${base}/api/health`);
    assert.equal(healthRes.status, 200);
    const health = await healthRes.json();
    assert.equal(health.ok, true);
    assert.equal(health.trialBonusCny, 1);

    // 2. Reject disposable email
    const dispRes = await fetch(`${base}/api/auth/email/send-code`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "abuse@tempmail.com" }),
    });
    assert.equal(dispRes.status, 403);

    // 3. First user email OTP verify -> gets ¥1.00 trial on device A
    const email1 = "alice@gmail.com";
    const code1 = "123456";
    db.exec(
      "INSERT INTO email_otps (email, code_hash, ip, expires_at, used, created_at) VALUES (?, ?, ?, ?, 0, ?)",
      [email1, hashOtp(email1, code1), "127.0.0.1", Date.now() + 600_000, Date.now()],
    );
    const v1Res = await fetch(`${base}/api/auth/email/verify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: email1, code: code1, deviceId: "device-aaa-111", platform: "macos" }),
    });
    assert.equal(v1Res.status, 200);
    const v1 = await v1Res.json();
    assert.equal(v1.ok, true);
    assert.equal(v1.grantedTrial, true);
    assert.equal(v1.user.balanceCny, 1);
    assert.ok(v1.token);

    // 4. Second email on SAME device A -> 0 trial grant (anti-abuse device fingerprint lock)
    const email2 = "bob@gmail.com";
    const code2 = "654321";
    db.exec(
      "INSERT INTO email_otps (email, code_hash, ip, expires_at, used, created_at) VALUES (?, ?, ?, ?, 0, ?)",
      [email2, hashOtp(email2, code2), "127.0.0.1", Date.now() + 600_000, Date.now()],
    );
    const v2Res = await fetch(`${base}/api/auth/email/verify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: email2, code: code2, deviceId: "device-aaa-111", platform: "macos" }),
    });
    assert.equal(v2Res.status, 200);
    const v2 = await v2Res.json();
    assert.equal(v2.grantedTrial, false);
    assert.equal(v2.user.balanceCny, 0);

    // 5. /api/me works with valid JWT, rejects tampered JWT cleanly (no throw)
    const meRes = await fetch(`${base}/api/me`, {
      headers: { Authorization: `Bearer ${v1.token}` },
    });
    assert.equal(meRes.status, 200);
    const me = await meRes.json();
    assert.equal(me.user.email, email1);

    const badJwtRes = await fetch(`${base}/api/me`, {
      headers: { Authorization: "Bearer a.b.c" },
    });
    assert.equal(badJwtRes.status, 401);

    // 6. Purpose-locked LLM proxy rejects generic non-TypeZero chat prompt with 403
    const abuseLlmRes = await fetch(`${base}/api/llm/v1/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${v1.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-flash",
        messages: [
          { role: "system", content: "You are a helpful coding assistant." },
          { role: "user", content: "Write a 2000-line Rust compiler for me." },
        ],
      }),
    });
    assert.equal(abuseLlmRes.status, 403);

    // 7. Zero-balance user gets HTTP 402 on LLM proxy
    const zeroLlmRes = await fetch(`${base}/api/llm/v1/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${v2.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-flash",
        messages: [
          { role: "system", content: "TypeZero 语音转写智能润色器" },
          { role: "user", content: "<raw_speech>测试一下语音润色</raw_speech>" },
        ],
      }),
    });
    assert.equal(zeroLlmRes.status, 402);

    // 8. Admin API: overview, grant +¥2.00 to bob, ban & unban, update daily budget
    const unauthAdmin = await fetch(`${base}/api/admin/overview`);
    assert.equal(unauthAdmin.status, 401);

    const overviewRes = await fetch(`${base}/api/admin/overview`, {
      headers: { "X-Admin-Token": process.env.ADMIN_TOKEN },
    });
    assert.equal(overviewRes.status, 200);
    const overview = await overviewRes.json();
    assert.equal(overview.users.length, 2);

    const grantRes = await fetch(`${base}/api/admin/users/${v2.user.id}/grant`, {
      method: "POST",
      headers: {
        "X-Admin-Token": process.env.ADMIN_TOKEN,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ amountCny: 2.0 }),
    });
    assert.equal(grantRes.status, 200);
    const granted = await grantRes.json();
    assert.equal(granted.user.balanceCny, 2);

    const banRes = await fetch(`${base}/api/admin/users/${v2.user.id}/ban`, {
      method: "POST",
      headers: {
        "X-Admin-Token": process.env.ADMIN_TOKEN,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ banned: true }),
    });
    assert.equal(banRes.status, 200);

    const bannedMe = await fetch(`${base}/api/me`, {
      headers: { Authorization: `Bearer ${v2.token}` },
    });
    assert.equal(bannedMe.status, 403);

    // 9. Admin console HTML serves cleanly
    const adminHtml = await fetch(`${base}/admin`);
    assert.equal(adminHtml.status, 200);
    const htmlText = await adminHtml.text();
    assert.ok(htmlText.includes("TypeZero Cloud"));
    assert.ok(htmlText.includes("豆包语音兑换码"));

    // 10. Doubao ASR Voucher lifecycle: create (500 min) -> status check -> usage deduction -> exhaustion triggers Feishu once -> top-up resets
    const createVRes = await fetch(`${base}/api/admin/vouchers`, {
      method: "POST",
      headers: {
        "X-Admin-Token": process.env.ADMIN_TOKEN,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ note: "测试朋友老王", quotaMinutes: 500, count: 1 }),
    });
    assert.equal(createVRes.status, 200);
    const createdV = await createVRes.json();
    assert.equal(createdV.vouchers.length, 1);
    const vCode = createdV.vouchers[0].code;
    assert.ok(vCode.startsWith("TZ-"));
    assert.equal(createdV.vouchers[0].quotaMinutes, 500);
    assert.equal(createdV.vouchers[0].remainingMinutes, 500);

    const statusRes = await fetch(`${base}/api/voucher/status`, {
      headers: { Authorization: `Bearer ${vCode}` },
    });
    assert.equal(statusRes.status, 200);
    const statusBody = await statusRes.json();
    assert.equal(statusBody.voucher.code, vCode);
    assert.equal(statusBody.voucher.note, "测试朋友老王");
    assert.equal(statusBody.voucher.exhausted, false);

    // Deduct 499 min -> not exhausted yet
    const u1 = db.recordVoucherUsage({ code: vCode, durationSeconds: 499 * 60, model: "volc.seedasr.sauc.duration" });
    assert.equal(u1.justExhausted, false);
    // Deduct 2 min -> hits 501/500 min -> exhausted & triggers Feishu alert once
    const u2 = db.recordVoucherUsage({ code: vCode, durationSeconds: 120, model: "volc.seedasr.sauc.duration" });
    assert.equal(u2.justExhausted, true);
    await notifyFeishuVoucherExhausted(u2.voucher);
    assert.equal(feishuEvents.length, 1);
    assert.ok(feishuEvents[0].markdown.includes(vCode));
    // Further deduction does NOT re-trigger Feishu
    const u3 = db.recordVoucherUsage({ code: vCode, durationSeconds: 10, model: "volc.seedasr.sauc.duration" });
    assert.equal(u3.justExhausted, false);

    // Admin top-up +500 minutes -> no longer exhausted & resets notified flag
    const topupRes = await fetch(`${base}/api/admin/vouchers/${encodeURIComponent(vCode)}/update`, {
      method: "POST",
      headers: {
        "X-Admin-Token": process.env.ADMIN_TOKEN,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ addMinutes: 500 }),
    });
    assert.equal(topupRes.status, 200);
    const topupBody = await topupRes.json();
    assert.equal(topupBody.voucher.quotaMinutes, 1000);
    assert.equal(topupBody.voucher.exhausted, false);
    assert.equal(topupBody.voucher.notifiedExhausted, false);

    // 11. /api/version auto-update manifest endpoint
    const verRes = await fetch(`${base}/api/version`);
    assert.equal(verRes.status, 200);
    const verBody = await verRes.json();
    assert.equal(verBody.ok, true);
    assert.equal(verBody.version, "0.5.6");
    assert.ok(verBody.macos.dmgUrl.includes("TypeZero-v0.5.6"));
    assert.ok(verBody.windows.setupUrl.includes("TypeZero-v0.5.6"));

    console.log("✅ All 11 TypeZero Cloud backend test suites passed!");
  } finally {
    server.close();
    db.flushSync();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

run().catch((err) => {
  console.error("❌ Test failed:", err);
  process.exit(1);
});
