import React, { useState } from "react";
import {
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Download,
  Keyboard,
  TriangleAlert,
  Zap,
} from "lucide-react";
import { api } from "../ipc";
import {
  LLM_PROVIDERS,
  WINDOWS_HOTKEY_PRESETS,
  type AppSnapshot,
  type ASRProviderOption,
  type FormattingStyle,
  type LLMConfig,
  type LLMProviderOption,
  type TriggerBehavior,
  type TriggerKeyOption,
} from "../types";

interface Props {
  snapshot: AppSnapshot;
  onUpdateConfig: (next: LLMConfig) => Promise<void>;
  onRefresh: () => Promise<void>;
}

const ToggleSwitch: React.FC<{
  title: string;
  desc?: string;
  checked: boolean;
  onChange: (next: boolean) => void;
}> = ({ title, desc, checked, onChange }) => (
  <div className="switch-row">
    <div>
      <div style={{ fontSize: 12.5, fontWeight: 500, color: "var(--ink-primary)" }}>{title}</div>
      {desc && <div style={{ fontSize: 11.5, color: "var(--ink-muted)", marginTop: 2 }}>{desc}</div>}
    </div>
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      className={`toggle ${checked ? "on" : ""}`}
      onClick={() => onChange(!checked)}
    >
      <span className="toggle-thumb" />
    </button>
  </div>
);

export const SettingsSection: React.FC<Props> = ({ snapshot, onUpdateConfig, onRefresh }) => {
  const { config } = snapshot;

  const [expandedASR, setExpandedASR] = useState<ASRProviderOption | null>(null);
  const [expandedLLM, setExpandedLLM] = useState<LLMProviderOption | null>(null);

  // ASR drafts
  const [volcKey, setVolcKey] = useState("");
  const [voucherInput, setVoucherInput] = useState("");
  const [showVoucherDrawer, setShowVoucherDrawer] = useState(false);
  const [openaiAsrUrl, setOpenaiAsrUrl] = useState(config.openAIASRBaseURL);
  const [openaiAsrModel, setOpenaiAsrModel] = useState(config.openAIASRModel);
  const [openaiAsrKey, setOpenaiAsrKey] = useState("");
  const [asrBusy, setAsrBusy] = useState<string | null>(null);
  const [asrNotice, setAsrNotice] = useState<Record<string, { ok: boolean; msg: string }>>({});

  // LLM drafts per provider
  const [llmKeys, setLlmKeys] = useState<Record<string, string>>({});
  const [llmModels, setLlmModels] = useState<Record<string, string>>(() => {
    const map: Record<string, string> = {};
    for (const p of LLM_PROVIDERS) {
      map[p.id] = config.providerModels[p.id] || p.defaultModelName;
    }
    return map;
  });
  const [customUrl, setCustomUrl] = useState(config.customBaseURL);
  const [llmBusy, setLlmBusy] = useState<string | null>(null);
  const [llmNotice, setLlmNotice] = useState<Record<string, { ok: boolean; msg: string }>>({});

  // Cloud Trial Auth state
  const [cloudEmail, setCloudEmail] = useState("");
  const [cloudCode, setCloudCode] = useState("");
  const [cloudCodeSent, setCloudCodeSent] = useState(false);
  const [cloudBusy, setCloudBusy] = useState(false);
  const [cloudMsg, setCloudMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [cloudDismissed, setCloudDismissed] = useState(() => {
    try {
      return localStorage.getItem("tz_dismissed_cloud_promo") === "1";
    } catch {
      return false;
    }
  });
  const [cloudDetailsOpen, setCloudDetailsOpen] = useState(false);
  const [cloudJustClaimed, setCloudJustClaimed] = useState(false);

  const dismissCloudPromo = () => {
    setCloudDismissed(true);
    try {
      localStorage.setItem("tz_dismissed_cloud_promo", "1");
    } catch {
      // ignore storage errors
    }
  };

  const handleSendCloudCode = async () => {
    const email = cloudEmail.trim();
    if (!email) {
      setCloudMsg({ ok: false, text: "请输入邮箱地址（推荐使用 Gmail）" });
      return;
    }
    setCloudBusy(true);
    setCloudMsg(null);
    try {
      const msg = await api.cloudSendEmailCode(email);
      setCloudCodeSent(true);
      setCloudMsg({ ok: true, text: msg });
    } catch (e) {
      setCloudMsg({ ok: false, text: String(e) });
    } finally {
      setCloudBusy(false);
    }
  };

  const handleVerifyCloudCode = async () => {
    setCloudBusy(true);
    setCloudMsg(null);
    try {
      await api.cloudVerifyEmailCode(cloudEmail.trim(), cloudCode.trim());
      setCloudCode("");
      setCloudCodeSent(false);
      setCloudJustClaimed(true);
      await onRefresh();
      window.setTimeout(() => {
        setCloudJustClaimed(false);
        setCloudDetailsOpen(false);
      }, 2400);
    } catch (e) {
      setCloudMsg({ ok: false, text: String(e) });
    } finally {
      setCloudBusy(false);
    }
  };

  const isGroq = openaiAsrUrl.toLowerCase().includes("groq.com");
  const isOpenAILocalKeyless =
    openaiAsrUrl.toLowerCase().includes("localhost") ||
    openaiAsrUrl.toLowerCase().includes("127.0.0.1");

  const setTriggerKey = async (key: TriggerKeyOption) => {
    await api.setTriggerKey(key);
    await onRefresh();
  };

  const setBehavior = async (beh: TriggerBehavior) => {
    await api.setTriggerBehavior(beh);
    await onRefresh();
  };

  const setFormattingStyle = async (style: FormattingStyle) => {
    await api.setFormattingStyle(style);
    await onRefresh();
  };

  const toggleFlag = async (key: keyof LLMConfig, val: boolean) => {
    await onUpdateConfig({ ...config, [key]: val });
  };

  const handleProbeVolc = async () => {
    setAsrBusy("probe-volc");
    try {
      const msg = await api.probeSeedASR(volcKey);
      setAsrNotice((p) => ({ ...p, volcSeedASR: { ok: true, msg } }));
      await onRefresh();
    } catch (e) {
      setAsrNotice((p) => ({ ...p, volcSeedASR: { ok: false, msg: `❌ ${String(e)}` } }));
    } finally {
      setAsrBusy(null);
    }
  };

  const handleActivateASR = async (provider: ASRProviderOption) => {
    setAsrBusy(`act-${provider}`);
    try {
      const key = provider === "volcSeedASR" ? volcKey : openaiAsrKey;
      const msg = await api.activateASRProvider(provider, key, openaiAsrUrl, openaiAsrModel);
      setAsrNotice((p) => ({ ...p, [provider]: { ok: true, msg } }));
      await onRefresh();
    } catch (e) {
      setAsrNotice((p) => ({ ...p, [provider]: { ok: false, msg: `❌ ${String(e)}` } }));
    } finally {
      setAsrBusy(null);
    }
  };

  const handleProbeOpenAIASR = async () => {
    setAsrBusy("probe-oai");
    try {
      const msg = await api.probeOpenAIASR(openaiAsrUrl, openaiAsrModel, openaiAsrKey);
      setAsrNotice((p) => ({ ...p, openAIWhisper: { ok: true, msg } }));
      await onRefresh();
    } catch (e) {
      setAsrNotice((p) => ({ ...p, openAIWhisper: { ok: false, msg: `❌ ${String(e)}` } }));
    } finally {
      setAsrBusy(null);
    }
  };

  const handleLLMBench = async (provider: LLMProviderOption, defaultBase: string) => {
    setLlmBusy(`bench-${provider}`);
    try {
      const url = provider === "custom" ? customUrl : defaultBase;
      const msg = await api.benchmarkLLMProvider(
        provider,
        url,
        llmModels[provider] || "",
        llmKeys[provider] || "",
      );
      setLlmNotice((p) => ({ ...p, [provider]: { ok: true, msg } }));
      await onRefresh();
    } catch (e) {
      setLlmNotice((p) => ({ ...p, [provider]: { ok: false, msg: `❌ ${String(e)}` } }));
    } finally {
      setLlmBusy(null);
    }
  };

  const handleLLMActivate = async (provider: LLMProviderOption, defaultBase: string) => {
    setLlmBusy(`act-${provider}`);
    try {
      const url = provider === "custom" ? customUrl : defaultBase;
      const msg = await api.activateLLMProvider(
        provider,
        url,
        llmModels[provider] || "",
        llmKeys[provider] || "",
      );
      setLlmNotice((p) => ({ ...p, [provider]: { ok: true, msg } }));
      await onRefresh();
    } catch (e) {
      setLlmNotice((p) => ({ ...p, [provider]: { ok: false, msg: `❌ ${String(e)}` } }));
    } finally {
      setLlmBusy(null);
    }
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
      <header className="editorial-header">
        <div className="editorial-header-top">
          <h1 className="editorial-title">引擎与快捷键设置</h1>
          <span className="editorial-badge">WINDOWS PREFERENCES</span>
        </div>
        <div className="editorial-sub">
          <span className="editorial-sub-bar" />
          <span>Windows 左右修饰键与自定义组合键一键绑定 ｜ 引擎点开配置并校验通过后才切换唯一生效</span>
        </div>
        <div className="editorial-rule" />
      </header>

      {/* Standalone Collapsible Free Trial Module (distinct from numbered settings below) */}
      {cloudJustClaimed && snapshot.cloudUser ? (
        <section
          className="card"
          style={{
            background: "linear-gradient(90deg, rgba(20,128,74,0.09), var(--card-bg))",
            borderColor: "rgba(20,128,74,0.35)",
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: "16px 18px",
          }}
        >
          <CheckCircle2 size={24} style={{ color: "var(--emerald)", flexShrink: 0 }} />
          <div>
            <div style={{ fontSize: 14, fontWeight: 700 }}>🎉 体验额度已到账 · 官方通道已自动开启</div>
            <div style={{ fontSize: 12, color: "var(--ink-secondary)", marginTop: 2 }}>
              {snapshot.cloudUser.email} · 当前余额 ¥{snapshot.cloudUser.balanceCny.toFixed(2)}，现在即可按快捷键开说！
            </div>
          </div>
        </section>
      ) : snapshot.cloudUser ? (
        <section className="card" style={{ padding: 0, overflow: "hidden" }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 9,
              padding: "10px 14px",
              flexWrap: "wrap",
            }}
          >
            <span
              style={{
                width: 7,
                height: 7,
                borderRadius: "50%",
                background: snapshot.isOfficialCloudTrialActive ? "var(--emerald)" : "var(--ink-muted)",
              }}
            />
            <span
              style={{
                fontSize: 12,
                fontWeight: 600,
                color: snapshot.isOfficialCloudTrialActive ? "var(--emerald)" : "var(--ink-secondary)",
              }}
            >
              {snapshot.isOfficialCloudTrialActive ? "官方体验通道生效中" : "已登录云端账号（当前使用个人 Key）"}
            </span>
            <span style={{ color: "var(--ink-muted)" }}>·</span>
            <span style={{ fontSize: 12, color: "var(--ink-secondary)" }}>{snapshot.cloudUser.email}</span>
            <span className="pill-badge pill-lilac" style={{ fontFamily: "var(--font-mono)" }}>
              余额 ¥{snapshot.cloudUser.balanceCny.toFixed(4)}
            </span>
            <button
              type="button"
              className="btn btn-secondary btn-compact"
              style={{ marginLeft: "auto" }}
              onClick={() => setCloudDetailsOpen((v) => !v)}
            >
              {cloudDetailsOpen ? "收起 ▴" : "管理 ▾"}
            </button>
          </div>
          {cloudDetailsOpen && (
            <div
              style={{
                borderTop: "1px solid var(--hairline)",
                padding: "12px 14px",
                display: "flex",
                flexDirection: "column",
                gap: 10,
              }}
            >
              <ToggleSwitch
                title="使用官方免费体验通道（豆包 2.0 语音 + DeepSeek 4 Flash 润色）"
                desc={`已用语音 ${snapshot.cloudUser.asrSecondsUsed}s · 润色 ${snapshot.cloudUser.llmRequestsUsed} 次 · 随时可关闭切回下方个人 Key（日均仅约 5 分钱）`}
                checked={Boolean(config.useOfficialCloudTrial)}
                onChange={(next) => {
                  void api
                    .cloudSetUseTrial(next)
                    .then(onRefresh)
                    .catch((e) => setCloudMsg({ ok: false, text: String(e) }));
                }}
              />
              <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
                <button
                  type="button"
                  className="btn btn-secondary btn-compact"
                  onClick={() => void api.cloudRefreshProfile().then(onRefresh)}
                >
                  刷新余额
                </button>
                <button
                  type="button"
                  className="btn btn-secondary btn-compact"
                  onClick={() => {
                    setCloudDetailsOpen(false);
                    void api.cloudLogout().then(onRefresh);
                  }}
                >
                  退出登录
                </button>
              </div>
            </div>
          )}
        </section>
      ) : !cloudDismissed ? (
        <section
          className="card"
          style={{
            background: "linear-gradient(135deg, rgba(90,70,232,0.08), var(--card-bg) 62%)",
            borderColor: "rgba(90,70,232,0.28)",
            padding: "18px 20px",
            display: "flex",
            flexDirection: "column",
            gap: 14,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span className="pill-badge pill-lilac" style={{ fontFamily: "var(--font-mono)", fontWeight: 700 }}>
              ✨ FREE TRIAL · 新手免填 KEY 通道
            </span>
            <button
              type="button"
              style={{
                background: "transparent",
                border: "none",
                color: "var(--ink-muted)",
                fontSize: 11.5,
                cursor: "pointer",
              }}
              onClick={dismissCloudPromo}
            >
              已有个人 Key，隐藏 ×
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
            <div style={{ fontFamily: "var(--font-serif)", fontSize: 19, fontWeight: 700 }}>
              免费领取 ¥1.00 官方体验额度
            </div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              <span className="pill-badge" style={{ background: "rgba(255,255,255,0.85)", border: "1px solid var(--hairline)" }}>
                🎙️ 约 60 分钟豆包 2.0 语音
              </span>
              <span className="pill-badge" style={{ background: "rgba(255,255,255,0.85)", border: "1px solid var(--hairline)" }}>
                ✨ 300 次 DeepSeek 润色
              </span>
              <span className="pill-badge" style={{ background: "rgba(255,255,255,0.85)", border: "1px solid var(--hairline)" }}>
                💡 后续自备 Key 仅 5 分钱/天
              </span>
            </div>
          </div>

          {!cloudCodeSent ? (
            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <input
                className="input"
                style={{
                  flex: 1,
                  height: 42,
                  fontSize: 13.5,
                  background: "#fff",
                  border: "1.5px solid rgba(90,70,232,0.38)",
                  borderRadius: 10,
                  padding: "0 14px",
                }}
                placeholder="输入常用邮箱（Gmail / QQ / 163 / Outlook）"
                value={cloudEmail}
                onChange={(e) => setCloudEmail(e.target.value)}
              />
              <button
                type="button"
                className="btn btn-primary"
                style={{ height: 42, padding: "0 18px", borderRadius: 10, fontWeight: 600 }}
                disabled={cloudBusy}
                onClick={() => void handleSendCloudCode()}
              >
                {cloudBusy ? "发送中…" : "发送验证码 →"}
              </button>
            </div>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 12 }}>
                <span>6 位验证码已发送至 <strong>{cloudEmail}</strong></span>
                <button
                  type="button"
                  style={{ marginLeft: "auto", background: "none", border: "none", color: "var(--ink-muted)", cursor: "pointer", fontSize: 11.5 }}
                  onClick={() => {
                    setCloudCodeSent(false);
                    setCloudCode("");
                  }}
                >
                  换个邮箱
                </button>
                <button
                  type="button"
                  style={{ background: "none", border: "none", color: "var(--violet)", cursor: "pointer", fontSize: 11.5, fontWeight: 600 }}
                  disabled={cloudBusy}
                  onClick={() => void handleSendCloudCode()}
                >
                  重新发送
                </button>
              </div>
              <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                <input
                  className="input"
                  style={{
                    width: 220,
                    height: 42,
                    fontSize: 16,
                    fontWeight: 700,
                    fontFamily: "var(--font-mono)",
                    background: "#fff",
                    border: "1.5px solid rgba(90,70,232,0.45)",
                    borderRadius: 10,
                    padding: "0 14px",
                  }}
                  placeholder="输入 6 位数字验证码"
                  value={cloudCode}
                  onChange={(e) => setCloudCode(e.target.value)}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  style={{ height: 42, padding: "0 18px", borderRadius: 10, fontWeight: 600 }}
                  disabled={cloudBusy}
                  onClick={() => void handleVerifyCloudCode()}
                >
                  {cloudBusy ? "验证中…" : "验证并领取 ¥1.00 ✨"}
                </button>
              </div>
            </div>
          )}

          {cloudMsg && (
            <div style={{ fontSize: 11.5, fontWeight: 500, color: cloudMsg.ok ? "var(--violet)" : "#c9342d" }}>
              {cloudMsg.text}
            </div>
          )}
        </section>
      ) : null}

      {/* Card 1: Hotkeys & Input Behavior */}
      <section className="card card-titled">
        <div className="card-header-band">
          <span className="section-num-badge">01</span>
          <span style={{ fontSize: 13.5, fontWeight: 600 }}>全局快捷键与输入方式</span>
          <div style={{ marginLeft: "auto", display: "flex", gap: 7, alignItems: "center" }}>
            <span className={`pill-badge ${snapshot.micAvailable ? "pill-ok" : "pill-warn"}`}>
              {snapshot.micAvailable ? <CheckCircle2 size={11} /> : <TriangleAlert size={11} />}
              <span>{snapshot.micAvailable ? "麦克风已就绪" : "未检测到麦克风"}</span>
            </span>
            {!snapshot.micAvailable && (
              <button
                type="button"
                className="btn btn-secondary btn-compact"
                onClick={() => void api.openWindowsMicSettings()}
              >
                打开系统设置
              </button>
            )}
          </div>
        </div>

        <div className="card-body-pad">
        <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
          <span className="row-label-pill">全局快捷键</span>
          <span className="pill-badge pill-lilac">
            ● 当前生效：{snapshot.activeTriggerDisplayName}
          </span>

          <div style={{ marginLeft: "auto", display: "flex", gap: 7 }}>
            {snapshot.isRecordingShortcut ? (
              <>
                <span
                  className="pill-badge"
                  style={{ background: "var(--violet)", color: "#fff", padding: "5px 10px" }}
                >
                  ● 请按下左/右修饰键或组合键（Esc 取消）
                </span>
                <button
                  type="button"
                  className="btn btn-secondary btn-compact"
                  onClick={() => void api.cancelShortcutCapture()}
                >
                  取消
                </button>
              </>
            ) : (
              <button
                type="button"
                className="btn btn-secondary btn-compact"
                onClick={() => void api.startShortcutCapture()}
              >
                <Keyboard size={12} />
                <span>
                  {config.triggerKey === "custom"
                    ? `重录快捷键 (${config.customHotkey.label})`
                    : "点击录制自定义键"}
                </span>
              </button>
            )}
          </div>
        </div>

        <div className="hotkey-grid">
          {WINDOWS_HOTKEY_PRESETS.map((preset) => {
            const selected = config.triggerKey === preset.id;
            return (
              <button
                key={preset.id}
                type="button"
                className={`hotkey-tile ${selected ? "selected" : ""}`}
                onClick={() => void setTriggerKey(preset.id)}
              >
                <span>{preset.label}</span>
                {preset.hint && <span className="hotkey-hint">{preset.hint}</span>}
              </button>
            );
          })}
        </div>

        <div style={{ fontSize: 11.5, color: "var(--ink-muted)" }}>
          💡 已内置 Windows 菜单栏防误触屏蔽（点按右 Alt 绝不激活顶部菜单栏）与左侧键 140ms 组合键防误触保护（Ctrl+C / Alt+Tab 零干扰）；录音中按 Esc 可一键取消。
        </div>

        <div style={{ height: 1, background: "var(--hairline)" }} />

        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <span className="row-label-pill" style={{ width: 78 }}>
            触发方式
          </span>
          <div className="segment-bar">
            <button
              type="button"
              className={`segment-btn ${config.triggerBehavior === "tapToggle" ? "selected" : ""}`}
              onClick={() => void setBehavior("tapToggle")}
            >
              点按启停（免按住 · 推荐）
            </button>
            <button
              type="button"
              className={`segment-btn ${config.triggerBehavior === "holdToTalk" ? "selected" : ""}`}
              onClick={() => void setBehavior("holdToTalk")}
            >
              按住说话 · 松开上屏
            </button>
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <span style={{ width: 78, fontSize: 12.5, color: "var(--ink-secondary)", fontWeight: 500 }}>
            上屏模式
          </span>
          <div className="segment-bar">
            <button
              type="button"
              className={`segment-btn ${!config.enableLiveInlineTyping ? "selected" : ""}`}
              onClick={() => void toggleFlag("enableLiveInlineTyping", false)}
            >
              胶囊跳符 · 松手瞬贴（默认）
            </button>
            <button
              type="button"
              className={`segment-btn ${config.enableLiveInlineTyping ? "selected" : ""}`}
              onClick={() => void toggleFlag("enableLiveInlineTyping", true)}
            >
              开启前端输入框逐字跳出
            </button>
          </div>
        </div>
        </div>
      </section>

      {/* Card 2: ASR Triple Engine */}
      <section className="card card-titled">
        <div className="card-header-band">
          <span className="section-num-badge">02</span>
          <span style={{ fontSize: 13.5, fontWeight: 600 }}>语音识别引擎与密钥</span>
          <span style={{ marginLeft: "auto", fontSize: 11.5, color: "var(--ink-secondary)" }}>
            密钥加密存入 Windows 凭据管理器 · 唯一生效引擎
          </span>
        </div>
        <div className="card-body-pad">

        <div className="segment-bar">
          {(
            [
              ["auto", "自动识别（中/英/多语）"],
              ["zh-CN", "锁定中文"],
              ["en-US", "锁定英文"],
            ] as Array<[string, string]>
          ).map(([loc, label]) => (
            <button
              key={loc}
              type="button"
              className={`segment-btn ${(config.speechLocale || "auto") === loc ? "selected" : ""}`}
              onClick={() =>
                onUpdateConfig({
                  ...config,
                  speechLocale: loc,
                  speechLocaleExplicitlySet: true,
                })
              }
            >
              {label}
            </button>
          ))}
        </div>

        {/* ASR A: Volcengine Seed-ASR 2.0 */}
        {(() => {
          const active = config.asrProvider === "volcSeedASR";
          const expanded = expandedASR === "volcSeedASR";
          const notice = asrNotice.volcSeedASR;
          return (
            <div className={`engine-card ${active ? "active" : expanded ? "expanded" : ""}`}>
              <div
                className="engine-card-header"
                onClick={() => setExpandedASR(expanded ? null : "volcSeedASR")}
              >
                {expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ fontSize: 13, fontWeight: active ? 600 : 500 }}>
                      豆包流式语音大模型 2.0
                    </span>
                    <span
                      className="keycap-chip"
                      style={
                        active
                          ? { background: "var(--active-green-bg)", color: "var(--active-green)" }
                          : undefined
                      }
                    >
                      Seed-ASR 2.0
                    </span>
                  </div>
                  {(active || expanded) && (
                    <div style={{ fontSize: 11.5, color: "var(--ink-secondary)", marginTop: 2 }}>
                      字节双向流国内直连 · 挂载 Top-65 专属热词 · 断网自动无损切回本机 FP32 热备
                    </div>
                  )}
                </div>
                {snapshot.voucherProfile && snapshot.isUsingDoubaoVoucher && (
                  <span
                    className={`pill-badge ${
                      snapshot.voucherProfile.exhausted || snapshot.voucherProfile.revoked
                        ? "pill-warn"
                        : "pill-ok"
                    }`}
                  >
                    {snapshot.voucherProfile.revoked
                      ? "兑换码已停用"
                      : snapshot.voucherProfile.exhausted
                        ? "时长已用完"
                        : `🎟️ 剩 ${Math.round(snapshot.voucherProfile.remainingMinutes)} 分钟`}
                  </span>
                )}
                <span className={`pill-badge ${snapshot.hasVolcSpeechKey ? "pill-ok" : "pill-warn"}`}>
                  {snapshot.isUsingDoubaoVoucher
                    ? "兑换码已存"
                    : snapshot.hasVolcSpeechKey
                      ? "密钥已存"
                      : "待填密钥"}
                </span>
                <span className={`pill-badge ${active ? "pill-green" : "pill-muted"}`}>
                  {active ? "● 当前生效" : "未启用"}
                </span>
              </div>

              {expanded && (
                <div className="engine-drawer">
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span style={{ width: 58, fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--ink-secondary)" }}>
                      API Key
                    </span>
                    <input
                      type="password"
                      className="input input-compact"
                      placeholder={
                        snapshot.hasOwnVolcSpeechKey
                          ? "已保存自有 API Key（如需更换请粘贴新密钥）"
                          : "粘贴您自己的火山豆包语音 API Key（推荐）"
                      }
                      value={volcKey}
                      onChange={(e) => setVolcKey(e.target.value)}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary btn-compact"
                      onClick={async () => {
                        await api.saveVolcSpeechKey(volcKey);
                        setVolcKey("");
                        await api.refreshVoucherStatus().catch(() => {});
                        await onRefresh();
                      }}
                    >
                      保存
                    </button>
                    <button
                      type="button"
                      className="btn btn-secondary btn-compact"
                      disabled={asrBusy !== null}
                      onClick={() => void handleProbeVolc()}
                    >
                      <Zap size={11} />
                      <span>{asrBusy === "probe-volc" ? "测速中…" : "测速"}</span>
                    </button>
                    {!active && (
                      <button
                        type="button"
                        className="btn btn-primary btn-compact"
                        disabled={asrBusy !== null}
                        onClick={() => void handleActivateASR("volcSeedASR")}
                      >
                        {asrBusy === "act-volcSeedASR" ? "校验中…" : "校验并切换"}
                      </button>
                    )}
                  </div>

                  {/* Dedicated, understated friend voucher drawer (separate from own API Key; auto-switches to own key when exhausted) */}
                  {(() => {
                    const savedVoucher = (snapshot.doubaoVoucherCode || "").trim();
                    const hasVoucher = savedVoucher.length > 0;
                    const visible = showVoucherDrawer || hasVoucher;
                    if (!visible) {
                      return (
                        <div style={{ marginTop: 8, display: "flex", alignItems: "center", gap: 6, fontSize: 11.5, color: "var(--ink-muted)" }}>
                          <span>🎟️ 持有朋友赠送的豆包语音兑换码？</span>
                          <button
                            type="button"
                            style={{
                              background: "none",
                              border: "none",
                              padding: 0,
                              cursor: "pointer",
                              color: "var(--violet)",
                              fontWeight: 600,
                              fontSize: 11.5,
                            }}
                            onClick={() => setShowVoucherDrawer(true)}
                          >
                            去兑换 ▸
                          </button>
                        </div>
                      );
                    }
                    const vp = snapshot.voucherProfile;
                    const pct = vp && vp.quotaMinutes > 0 ? Math.min(100, (vp.usedMinutes / vp.quotaMinutes) * 100) : 100;
                    return (
                      <div
                        style={{
                          marginTop: 10,
                          padding: "9px 10px",
                          borderRadius: 8,
                          background: "rgba(90,70,232,0.06)",
                          border: "1px solid rgba(90,70,232,0.16)",
                          fontSize: 11.5,
                        }}
                      >
                        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, marginBottom: 7 }}>
                          <div>
                            <strong style={{ color: "var(--ink-primary)" }}>🎟️ 朋友兑换码</strong>
                            <span style={{ marginLeft: 6, fontSize: 10.5, color: "var(--ink-muted)" }}>
                              选填 · 若已填自有 Key，优先用完赠送时长后自动无缝切回自有 Key
                            </span>
                          </div>
                          {!hasVoucher && (
                            <button
                              type="button"
                              style={{ background: "none", border: "none", padding: 0, cursor: "pointer", color: "var(--ink-muted)", fontSize: 11 }}
                              onClick={() => setShowVoucherDrawer(false)}
                            >
                              收起
                            </button>
                          )}
                        </div>
                        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                          <input
                            type="text"
                            className="input input-compact mono"
                            placeholder={hasVoucher ? savedVoucher : "粘贴兑换码，如 TZ-XXXX-XXXX"}
                            value={voucherInput}
                            onChange={(e) => setVoucherInput(e.target.value)}
                          />
                          <button
                            type="button"
                            className="btn btn-primary btn-compact"
                            disabled={asrBusy !== null}
                            onClick={async () => {
                              setAsrBusy("voucher-save");
                              try {
                                await api.saveDoubaoVoucherCode(voucherInput || savedVoucher);
                                setVoucherInput("");
                                await onRefresh();
                              } catch (err) {
                                setAsrNotice((prev) => ({
                                  ...prev,
                                  volcSeedASR: { ok: false, msg: String(err) },
                                }));
                              } finally {
                                setAsrBusy(null);
                              }
                            }}
                          >
                            {asrBusy === "voucher-save" ? "校验中…" : "兑换并激活"}
                          </button>
                          {hasVoucher && (
                            <button
                              type="button"
                              className="btn btn-secondary btn-compact"
                              onClick={async () => {
                                await api.clearDoubaoVoucherCode();
                                setVoucherInput("");
                                setShowVoucherDrawer(false);
                                await onRefresh();
                              }}
                            >
                              移除
                            </button>
                          )}
                        </div>
                        {vp && hasVoucher && (
                          <div style={{ marginTop: 8 }}>
                            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8 }}>
                              <span>
                                {snapshot.isUsingDoubaoVoucher
                                  ? "● 优先消耗兑换码："
                                  : snapshot.hasOwnVolcSpeechKey
                                    ? "✓ 已自动切回自有 Key："
                                    : "⛔ 兑换码已用完："}
                                <strong className="mono">{vp.code}</strong>
                                {vp.note ? `（${vp.note}）` : ""} · 已用 {vp.usedMinutes.toFixed(1)} / {vp.quotaMinutes.toFixed(0)} 分钟 · 剩余{" "}
                                <strong>{vp.remainingMinutes.toFixed(1)} 分钟</strong>（{vp.sessionCount} 次）
                              </span>
                              <button
                                type="button"
                                className="btn btn-secondary btn-compact"
                                onClick={async () => {
                                  await api.refreshVoucherStatus().catch(() => {});
                                  await onRefresh();
                                }}
                              >
                                刷新时长
                              </button>
                            </div>
                            <div className="progress-track" style={{ marginTop: 6, height: 5 }}>
                              <div
                                className="progress-fill"
                                style={{
                                  width: `${pct.toFixed(1)}%`,
                                  background: vp.exhausted || vp.revoked ? "var(--danger-red, #D1323C)" : "var(--violet)",
                                }}
                              />
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })()}
                  {notice && (
                    <div className={`inline-banner ${notice.ok ? "ok" : "err"}`}>{notice.msg}</div>
                  )}
                </div>
              )}
            </div>
          );
        })()}

        {/* ASR B: OpenAI / Groq Cloud Speech */}
        {(() => {
          const active = config.asrProvider === "openAIWhisper";
          const expanded = expandedASR === "openAIWhisper";
          const notice = asrNotice.openAIWhisper;
          return (
            <div className={`engine-card ${active ? "active" : expanded ? "expanded" : ""}`}>
              <div
                className="engine-card-header"
                onClick={() => setExpandedASR(expanded ? null : "openAIWhisper")}
              >
                {expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ fontSize: 13, fontWeight: active ? 600 : 500 }}>
                      OpenAI / Groq 云端语音大模型
                    </span>
                    <span className="keycap-chip">{config.openAIASRModel}</span>
                  </div>
                  {(active || expanded) && (
                    <div style={{ fontSize: 11.5, color: "var(--ink-secondary)", marginTop: 2 }}>
                      支持 OpenAI gpt-4o-mini-transcribe 与 Groq whisper-large-v3-turbo · 自动复用 OpenAI Key
                    </div>
                  )}
                </div>
                <span
                  className={`pill-badge ${
                    snapshot.hasEffectiveOpenaiAsrKey || isOpenAILocalKeyless ? "pill-ok" : "pill-warn"
                  }`}
                >
                  {snapshot.isOpenaiAsrReusingLlmKey
                    ? "复用 OpenAI 密钥"
                    : isOpenAILocalKeyless
                      ? "本地免密"
                      : snapshot.hasEffectiveOpenaiAsrKey
                        ? "密钥已存"
                        : "待填密钥"}
                </span>
                <span className={`pill-badge ${active ? "pill-green" : "pill-muted"}`}>
                  {active ? "● 当前生效" : "未启用"}
                </span>
              </div>

              {expanded && (
                <div className="engine-drawer">
                  <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <span style={{ width: 58, fontSize: 11.5, color: "var(--ink-secondary)" }}>快捷预设</span>
                    {[
                      { label: "OpenAI Mini", url: "https://api.openai.com/v1", model: "gpt-4o-mini-transcribe" },
                      { label: "OpenAI Full", url: "https://api.openai.com/v1", model: "gpt-4o-transcribe" },
                      { label: "Groq 极速 Whisper", url: "https://api.groq.com/openai/v1", model: "whisper-large-v3-turbo" },
                    ].map((p) => (
                      <button
                        key={p.label}
                        type="button"
                        className="btn btn-secondary btn-compact"
                        style={
                          openaiAsrUrl === p.url && openaiAsrModel === p.model
                            ? { borderColor: "var(--violet)", color: "var(--violet)" }
                            : undefined
                        }
                        onClick={() => {
                          setOpenaiAsrUrl(p.url);
                          setOpenaiAsrModel(p.model);
                        }}
                      >
                        {p.label}
                      </button>
                    ))}
                  </div>

                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span style={{ width: 58, fontSize: 11.5, color: "var(--ink-secondary)" }}>接口地址</span>
                    <input
                      className="input input-compact"
                      value={openaiAsrUrl}
                      onChange={(e) => setOpenaiAsrUrl(e.target.value)}
                    />
                    <span style={{ fontSize: 11.5, color: "var(--ink-secondary)", whiteSpace: "nowrap" }}>模型</span>
                    <input
                      className="input input-compact"
                      style={{ width: 185, flexShrink: 0 }}
                      value={openaiAsrModel}
                      onChange={(e) => setOpenaiAsrModel(e.target.value)}
                    />
                  </div>

                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span style={{ width: 58, fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--ink-secondary)" }}>
                      API Key
                    </span>
                    <input
                      type="password"
                      className="input input-compact"
                      placeholder={
                        isGroq
                          ? "粘贴 Groq API Key（gsk_...）"
                          : snapshot.isOpenaiAsrReusingLlmKey
                            ? "已自动复用下方 OpenAI 密钥（留空即可）"
                            : "粘贴 OpenAI API Key（或留空复用下方 OpenAI Key）"
                      }
                      value={openaiAsrKey}
                      onChange={(e) => setOpenaiAsrKey(e.target.value)}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary btn-compact"
                      onClick={async () => {
                        await api.saveOpenAIASRConfig(openaiAsrUrl, openaiAsrModel, openaiAsrKey);
                        setOpenaiAsrKey("");
                        await onRefresh();
                      }}
                    >
                      保存
                    </button>
                    <button
                      type="button"
                      className="btn btn-secondary btn-compact"
                      disabled={asrBusy !== null}
                      onClick={() => void handleProbeOpenAIASR()}
                    >
                      <Zap size={11} />
                      <span>{asrBusy === "probe-oai" ? "测速中…" : "测速"}</span>
                    </button>
                    {!active && (
                      <button
                        type="button"
                        className="btn btn-primary btn-compact"
                        disabled={asrBusy !== null}
                        onClick={() => void handleActivateASR("openAIWhisper")}
                      >
                        {asrBusy === "act-openAIWhisper" ? "校验中…" : "校验并切换"}
                      </button>
                    )}
                  </div>

                  {notice && (
                    <div className={`inline-banner ${notice.ok ? "ok" : "err"}`}>{notice.msg}</div>
                  )}
                </div>
              )}
            </div>
          );
        })()}

        {/* ASR C: Local SenseVoice FP32 (886MB) */}
        {(() => {
          const active = config.asrProvider === "localSenseVoice";
          const expanded = expandedASR === "localSenseVoice";
          const notice = asrNotice.localSenseVoice;
          return (
            <div className={`engine-card ${active ? "active" : expanded ? "expanded" : ""}`}>
              <div
                className="engine-card-header"
                onClick={() => setExpandedASR(expanded ? null : "localSenseVoice")}
              >
                {expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ fontSize: 13, fontWeight: active ? 600 : 500 }}>
                      纯本机 SenseVoice FP32 离线满血模型
                    </span>
                    <span className="keycap-chip">886MB · 100% 离线</span>
                  </div>
                  {(active || expanded) && (
                    <div style={{ fontSize: 11.5, color: "var(--ink-secondary)", marginTop: 2 }}>
                      基于 sherpa-onnx 原生推理 · 零联网隐私保护 · 同时作为云端断网时的 0 丢字热备底座
                    </div>
                  )}
                </div>
                <span className={`pill-badge ${snapshot.senseVoiceLoaded ? "pill-ok" : "pill-warn"}`}>
                  {snapshot.senseVoiceFullFp32
                    ? "满血包已装好"
                    : snapshot.senseVoiceLoaded
                      ? "已就绪"
                      : "未下载"}
                </span>
                <span className={`pill-badge ${active ? "pill-green" : "pill-muted"}`}>
                  {active ? "● 当前生效" : "未启用"}
                </span>
              </div>

              {expanded && (
                <div className="engine-drawer">
                  {snapshot.isDownloadingOfflineModel ? (
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div className="progress-track">
                        <div
                          className="progress-fill"
                          style={{ width: `${Math.round(snapshot.offlineDownloadProgress * 100)}%` }}
                        />
                      </div>
                      <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--violet)" }}>
                        {snapshot.offlineDownloadStatusText}
                      </span>
                      <button
                        type="button"
                        className="btn btn-secondary btn-compact"
                        onClick={() => void api.cancelOfflineModelDownload()}
                      >
                        取消
                      </button>
                    </div>
                  ) : (
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      {!snapshot.senseVoiceFullFp32 && (
                        <button
                          type="button"
                          className="btn btn-secondary btn-compact"
                          onClick={() => void api.startOfflineModelDownload()}
                        >
                          <Download size={12} />
                          <span>一键后台下载 886MB 离线满血模型</span>
                        </button>
                      )}
                      {!active && (
                        <button
                          type="button"
                          className="btn btn-primary btn-compact"
                          disabled={asrBusy !== null}
                          onClick={() => void handleActivateASR("localSenseVoice")}
                        >
                          {asrBusy === "act-localSenseVoice" ? "校验中…" : "校验并切换"}
                        </button>
                      )}
                      {!snapshot.sherpaRuntimeAvailable && (
                        <span style={{ fontSize: 11.5, color: "var(--amber)" }}>
                          ⚠️ 开发态未放置 sherpa-onnx-c-api.dll（正式安装包已自带）
                        </span>
                      )}
                    </div>
                  )}
                  {notice && (
                    <div className={`inline-banner ${notice.ok ? "ok" : "err"}`}>{notice.msg}</div>
                  )}
                </div>
              )}
            </div>
          );
        })()}
        </div>
      </section>

      {/* Card 3: LLM Polishing & 7 Providers */}
      <section className="card card-titled">
        <div className="card-header-band">
          <span className="section-num-badge">03</span>
          <span style={{ fontSize: 13.5, fontWeight: 600 }}>智能排版大模型与密钥</span>
          <span style={{ marginLeft: "auto", fontSize: 11.5, color: "var(--ink-secondary)" }}>
            支持 DeepSeek / 豆包 / 通义 / OpenAI / Gemini / Claude / 本地 Ollama
          </span>
        </div>
        <div className="card-body-pad">

        <div className="segment-bar">
          {(
            [
              ["structured", "结构化精炼（分段 · 1.2.3.列点）"],
              ["lightPolish", "轻度纠错（保留原句式）"],
              ["verbatimLocal", "纯原声直出（不走大模型）"],
            ] as Array<[FormattingStyle, string]>
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              className={`segment-btn ${config.formattingStyle === id ? "selected" : ""}`}
              onClick={() => void setFormattingStyle(id)}
            >
              {label}
            </button>
          ))}
        </div>

        {LLM_PROVIDERS.map((p) => {
          const active = config.selectedProvider === p.id;
          const expanded = expandedLLM === p.id;
          const hasKey = Boolean(snapshot.savedProviderKeys[p.id]);
          const isLocalKeyless =
            p.id === "custom" &&
            (customUrl.toLowerCase().includes("localhost") ||
              customUrl.toLowerCase().includes("127.0.0.1"));
          const notice = llmNotice[p.id];

          return (
            <div key={p.id} className={`engine-card ${active ? "active" : expanded ? "expanded" : ""}`}>
              <div
                className="engine-card-header"
                onClick={() => setExpandedLLM(expanded ? null : p.id)}
              >
                {expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ fontSize: 13, fontWeight: active ? 600 : 500 }}>{p.title}</span>
                    <span className="keycap-chip">{llmModels[p.id] || p.defaultModelName}</span>
                  </div>
                  {(active || expanded) && (
                    <div style={{ fontSize: 11.5, color: "var(--ink-secondary)", marginTop: 2 }}>
                      {p.subtitle}
                    </div>
                  )}
                </div>
                <span className={`pill-badge ${hasKey || isLocalKeyless ? "pill-ok" : "pill-warn"}`}>
                  {isLocalKeyless ? "本地免密" : hasKey ? "密钥已存" : "待填密钥"}
                </span>
                <span className={`pill-badge ${active ? "pill-green" : "pill-muted"}`}>
                  {active ? "● 当前生效" : "未启用"}
                </span>
              </div>

              {expanded && (
                <div className="engine-drawer">
                  {p.id === "custom" && (
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span style={{ width: 58, fontSize: 11.5, color: "var(--ink-secondary)" }}>接口地址</span>
                      <input
                        className="input input-compact"
                        placeholder="https://api.siliconflow.cn/v1 或 http://localhost:11434/v1"
                        value={customUrl}
                        onChange={(e) => setCustomUrl(e.target.value)}
                      />
                    </div>
                  )}

                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span style={{ width: 58, fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--ink-secondary)" }}>
                      API Key
                    </span>
                    <input
                      type="password"
                      className="input input-compact"
                      placeholder={
                        hasKey
                          ? "已加密保存（如需更新请粘贴新密钥）"
                          : p.id === "custom"
                            ? "粘贴 API Key（本地 Ollama 可留空）"
                            : `粘贴 ${p.shortName} API Key`
                      }
                      value={llmKeys[p.id] || ""}
                      onChange={(e) => setLlmKeys((prev) => ({ ...prev, [p.id]: e.target.value }))}
                    />
                    <input
                      className="input input-compact"
                      style={{ width: 170, flexShrink: 0 }}
                      placeholder="模型 ID"
                      value={llmModels[p.id] || ""}
                      onChange={(e) => setLlmModels((prev) => ({ ...prev, [p.id]: e.target.value }))}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary btn-compact"
                      onClick={async () => {
                        await api.saveLLMProviderDraft(
                          p.id,
                          p.id === "custom" ? customUrl : p.defaultBaseURL,
                          llmModels[p.id] || p.defaultModelName,
                          llmKeys[p.id] || "",
                        );
                        setLlmKeys((prev) => ({ ...prev, [p.id]: "" }));
                        await onRefresh();
                      }}
                    >
                      保存
                    </button>
                    <button
                      type="button"
                      className="btn btn-secondary btn-compact"
                      disabled={llmBusy !== null}
                      onClick={() => void handleLLMBench(p.id, p.defaultBaseURL)}
                    >
                      <Zap size={11} />
                      <span>{llmBusy === `bench-${p.id}` ? "测速中…" : "测速"}</span>
                    </button>
                    {!active && (
                      <button
                        type="button"
                        className="btn btn-primary btn-compact"
                        disabled={llmBusy !== null}
                        onClick={() => void handleLLMActivate(p.id, p.defaultBaseURL)}
                      >
                        {llmBusy === `act-${p.id}` ? "校验中…" : "校验并切换"}
                      </button>
                    )}
                  </div>

                  {notice && (
                    <div className={`inline-banner ${notice.ok ? "ok" : "err"}`}>{notice.msg}</div>
                  )}
                </div>
              )}
            </div>
          );
        })}
        </div>
      </section>

      {/* Card 4: Everyday Windows System & Smart Guard Switches */}
      <section className="card card-titled">
        <div className="card-header-band">
          <span className="section-num-badge">04</span>
          <span style={{ fontSize: 13.5, fontWeight: 600 }}>Windows 系统体验与智能护航</span>
        </div>
        <div className="card-body-pad" style={{ gap: 2 }}>
        <ToggleSwitch
          title="开机自动启动（静默驻留右下角托盘）"
          desc="登录 Windows 后自动后台待命，随时按快捷键开口成文"
          checked={config.launchAtLogin}
          onChange={(v) => void toggleFlag("launchAtLogin", v)}
        />
        <ToggleSwitch
          title="关闭主窗口时最小化到右下角系统托盘"
          desc="点右上角 × 不会退出语音服务，右键托盘图标可随时退出"
          checked={config.minimizeToTray}
          onChange={(v) => void toggleFlag("minimizeToTray", v)}
        />
        <ToggleSwitch
          title="听写期间自动静音系统外放，松手瞬间恢复"
          desc="听歌/看视频时开口说话不串音，严格尊重您原有的静音状态"
          checked={config.enableAutoMuteDuringDictation}
          onChange={(v) => void toggleFlag("enableAutoMuteDuringDictation", v)}
        />
        <ToggleSwitch
          title="≤28 字干净短句 0ms 免检直通"
          desc="云端已精准标点且无口癖/改口的短句跳过大模型，零等待瞬贴上屏"
          checked={config.enableFastBypassForShortPhrases}
          onChange={(v) => void toggleFlag("enableFastBypassForShortPhrases", v)}
        />
        <ToggleSwitch
          title="微信 / 飞书 / QQ / 终端自动去掉句末句号"
          desc="让即时聊天单句回复更自然顺眼"
          checked={config.stripTrailingPeriodInChatApps}
          onChange={(v) => void toggleFlag("stripTrailingPeriodInChatApps", v)}
        />
        <ToggleSwitch
          title="中英文与数字盘古留白（Pangu Spacing）"
          desc="自动在中英文与数字之间插入优雅半角空格"
          checked={config.enablePanguSpacing}
          onChange={(v) => void toggleFlag("enablePanguSpacing", v)}
        />
        <ToggleSwitch
          title="25dB 气声耳语自动增益（Whisper Boost AGC）"
          desc="办公室或深夜极低音量轻声说话也能清晰拾音"
          checked={config.enableWhisperAGC}
          onChange={(v) => void toggleFlag("enableWhisperAGC", v)}
        />
        <ToggleSwitch
          title="手动改字与选中语音改写无感自学习"
          desc="您修正过的专有名词将自动沉淀到个人专属词库，越用越懂您"
          checked={config.enableAutoLearn}
          onChange={(v) => void toggleFlag("enableAutoLearn", v)}
        />
        </div>
      </section>
    </div>
  );
};
