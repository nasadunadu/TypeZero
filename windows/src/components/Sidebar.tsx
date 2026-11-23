import React from "react";
import { BookOpen, Clock, Layers, SlidersHorizontal } from "lucide-react";
import { MobiusMark } from "./MobiusMark";
import type { AppSnapshot, SidebarTab } from "../types";

interface Props {
  snapshot: AppSnapshot;
  selectedTab: SidebarTab;
  onSelectTab: (tab: SidebarTab) => void;
  onOpenMicSettings: () => void;
  onCheckForUpdates: () => void;
  onInstallUpdate: () => void;
}

const NAV_ITEMS: Array<{ id: SidebarTab; label: string; icon: React.ReactNode }> = [
  { id: "home", label: "洞察总览", icon: <Layers size={15} className="nav-icon" /> },
  { id: "history", label: "口述历史", icon: <Clock size={15} className="nav-icon" /> },
  { id: "dictionary", label: "个人词库", icon: <BookOpen size={15} className="nav-icon" /> },
  { id: "settings", label: "引擎与快捷键", icon: <SlidersHorizontal size={15} className="nav-icon" /> },
];

export const Sidebar: React.FC<Props> = ({
  snapshot,
  selectedTab,
  onSelectTab,
  onOpenMicSettings,
  onCheckForUpdates,
  onInstallUpdate,
}) => {
  const { config } = snapshot;

  const asrReady = (() => {
    if (snapshot.isOfficialCloudTrialActive) return true;
    if (config.asrProvider === "volcSeedASR") {
      return snapshot.hasVolcSpeechKey || snapshot.senseVoiceLoaded;
    }
    if (config.asrProvider === "openAIWhisper") {
      return snapshot.hasEffectiveOpenaiAsrKey || snapshot.senseVoiceLoaded;
    }
    return snapshot.senseVoiceLoaded;
  })();

  const asrTag = (() => {
    if (snapshot.isOfficialCloudTrialActive) {
      return "CLOUD TRIAL · SEED-ASR 2.0";
    }
    if (config.asrProvider === "volcSeedASR" && snapshot.hasVolcSpeechKey) {
      return snapshot.senseVoiceFullFp32 ? "SEED-ASR 2.0 + FP32" : "SEED-ASR 2.0 · CLOUD";
    }
    if (config.asrProvider === "openAIWhisper" && snapshot.hasEffectiveOpenaiAsrKey) {
      const isGroq = config.openAIASRBaseURL.toLowerCase().includes("groq.com");
      const tag = isGroq ? "GROQ WHISPER" : "OPENAI ASR";
      return snapshot.senseVoiceFullFp32 ? `${tag} + FP32` : `${tag} · CLOUD`;
    }
    if (snapshot.senseVoiceLoaded) {
      return snapshot.senseVoiceFullFp32 ? "SENSEVOICE FP32 · FULL" : "SENSEVOICE INT8 · LOCAL";
    }
    return "WAITING FOR KEY…";
  })();

  const llmShortLabel = (() => {
    if (config.formattingStyle === "verbatimLocal") return "纯原声不排版";
    switch (config.selectedProvider) {
      case "deepseek":
        return "DeepSeek 4 Flash";
      case "volcengine":
        return "火山 Doubao-Seed";
      case "dashscope":
        return "百炼 Qwen-Flash";
      case "openai":
        return `OpenAI ${config.modelName}`;
      case "gemini":
        return `Gemini ${config.modelName}`;
      case "anthropic":
        return `Claude ${config.modelName}`;
      default:
        return config.modelName;
    }
  })();

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="brand-orb">
          <MobiusMark size={21} />
        </div>
        <div style={{ minWidth: 0 }}>
          <div className="brand-name">TypeZero</div>
          <div
            className="brand-asr-tag"
            style={{ color: asrReady ? "var(--emerald)" : "var(--violet)" }}
          >
            {asrTag}
          </div>
        </div>
      </div>

      <nav className="nav-list" aria-label="主导航">
        {NAV_ITEMS.map((item) => {
          const active = selectedTab === item.id;
          return (
            <button
              key={item.id}
              type="button"
              className={`nav-btn ${active ? "active" : ""}`}
              onClick={() => onSelectTab(item.id)}
            >
              {item.icon}
              <span>{item.label}</span>
              {item.id === "dictionary" && (
                <span className="nav-count-pill">{snapshot.lexicon.length}</span>
              )}
            </button>
          );
        })}
      </nav>

      <div className="telemetry-card">
        <div className="telemetry-head">
          <span
            className="telemetry-dot"
            style={{
              background: snapshot.micAvailable ? "var(--emerald)" : "var(--amber)",
            }}
          />
          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {llmShortLabel}
          </span>
        </div>

        <div className="telemetry-row">
          <span style={{ color: "var(--ink-muted)" }}>全局触发键</span>
          <span className="keycap-chip">{snapshot.activeTriggerCompactLabel}</span>
        </div>

        {snapshot.stats.averageLatencyMs > 0 && (
          <div className="telemetry-row">
            <span style={{ color: "var(--ink-muted)" }}>平均首包延迟</span>
            <span
              style={{
                fontFamily: "var(--font-mono)",
                fontWeight: 600,
                color: "var(--violet)",
              }}
            >
              {snapshot.stats.averageLatencyMs} ms
            </span>
          </div>
        )}

        {snapshot.cloudUser ? (
          <div className="telemetry-row" style={{ borderTop: "1px solid var(--hairline)", paddingTop: 6, marginTop: 4 }}>
            <span style={{ color: "var(--ink-muted)" }}>
              {snapshot.isOfficialCloudTrialActive ? "☁️ 官方体验余额" : "云端体验余额"}
            </span>
            <span
              style={{
                fontFamily: "var(--font-mono)",
                fontWeight: 600,
                color: snapshot.cloudUser.balanceCny > 0 ? "var(--emerald)" : "var(--amber)",
              }}
            >
              ¥{snapshot.cloudUser.balanceCny.toFixed(4)}
            </span>
          </div>
        ) : (
          <button
            type="button"
            className="btn btn-secondary btn-compact"
            style={{ width: "100%", marginTop: 4 }}
            onClick={() => onSelectTab("settings")}
          >
            🎁 登录领 ¥1.00 免费体验
          </button>
        )}

        <div className="telemetry-row">
          <span style={{ color: "var(--ink-muted)" }}>Windows 托盘</span>
          <span
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: 10.5,
              color: "var(--emerald)",
              fontWeight: 600,
            }}
          >
            常驻待命
          </span>
        </div>

        <div className="telemetry-row" style={{ borderTop: "1px solid var(--hairline)", paddingTop: 6, marginTop: 4 }}>
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--ink-muted)" }}>
            v{snapshot.currentVersion || "0.5.6"}
          </span>
          {snapshot.availableUpdate ? (
            <button
              type="button"
              style={{
                border: "none",
                background: "transparent",
                padding: 0,
                cursor: "pointer",
                fontSize: 11,
                fontWeight: 600,
                color: "var(--violet)",
              }}
              disabled={Boolean(snapshot.isInstallingUpdate)}
              onClick={onInstallUpdate}
            >
              {snapshot.isInstallingUpdate ? "升级中…" : `✨ 升级 ${snapshot.availableUpdate.tag}`}
            </button>
          ) : (
            <button
              type="button"
              style={{
                border: "none",
                background: "transparent",
                padding: 0,
                cursor: "pointer",
                fontSize: 11,
                color: "var(--ink-secondary)",
              }}
              disabled={Boolean(snapshot.isCheckingUpdate)}
              onClick={onCheckForUpdates}
            >
              {snapshot.isCheckingUpdate ? "检查中…" : "检查更新"}
            </button>
          )}
        </div>

        {!snapshot.micAvailable && (
          <button
            type="button"
            className="btn btn-primary btn-compact"
            style={{ width: "100%", marginTop: 2 }}
            onClick={onOpenMicSettings}
          >
            打开 Windows 麦克风设置
          </button>
        )}
      </div>
    </aside>
  );
};
