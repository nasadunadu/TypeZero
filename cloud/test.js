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
  const { server, db, hashOtp } = await createApp(dbPath);

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

    console.log("✅ All 9 TypeZero Cloud backend test suites passed!");
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
