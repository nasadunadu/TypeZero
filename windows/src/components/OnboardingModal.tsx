import React, { useState } from "react";
import { CheckCircle2, Download, TriangleAlert } from "lucide-react";
import { api } from "../ipc";
import { MobiusMark } from "./MobiusMark";
import {
  LLM_PROVIDERS,
  WINDOWS_HOTKEY_PRESETS,
  type AppSnapshot,
  type ASRProviderOption,
  type LLMProviderOption,
} from "../types";

interface Props {
  snapshot: AppSnapshot;
  onRefresh: () => Promise<void>;
  onFinish: () => Promise<void>;
}

export const OnboardingModal: React.FC<Props> = ({ snapshot, onRefresh, onFinish }) => {
  const { config } = snapshot;
  const [asrChoice, setAsrChoice] = useState<ASRProviderOption>(config.asrProvider);
  const [asrKey, setAsrKey] = useState("");
  const [llmChoice, setLlmChoice] = useState<LLMProviderOption>(config.selectedProvider);
  const [llmKey, setLlmKey] = useState("");

  const handleSaveASR = async () => {
    if (asrChoice === "volcSeedASR") {
      await api.saveVolcSpeechKey(asrKey);
      await api.updatePreferences({ ...config, asrProvider: "volcSeedASR", enableVolcSeedASR: true });
    } else if (asrChoice === "openAIWhisper") {
      await api.saveOpenAIASRConfig(config.openAIASRBaseURL, config.openAIASRModel, asrKey);
      await api.updatePreferences({ ...config, asrProvider: "openAIWhisper", enableVolcSeedASR: false });
    } else {
      await api.updatePreferences({ ...config, asrProvider: "localSenseVoice", enableVolcSeedASR: false });
    }
    setAsrKey("");
    await onRefresh();
  };

  const handleSaveLLM = async () => {
    const meta = LLM_PROVIDERS.find((p) => p.id === llmChoice) ?? LLM_PROVIDERS[0];
    await api.saveLLMProviderDraft(llmChoice, meta.defaultBaseURL, meta.defaultModelName, llmKey);
    await api.updatePreferences({
      ...config,
      selectedProvider: llmChoice,
      baseURL: meta.defaultBaseURL,
      modelName: meta.defaultModelName,
    });
    setLlmKey("");
    await onRefresh();
  };

  const handleComplete = async () => {
    if (asrKey.trim()) await handleSaveASR();
    if (llmKey.trim()) await handleSaveLLM();
    await onFinish();
  };

  return (
    <div className="modal-backdrop">
      <div className="modal-card">
        <div style={{ display: "flex", alignItems: "center", gap: 11 }}>
          <div className="brand-orb">
            <MobiusMark size={22} />
          </div>
          <div>
            <h2 style={{ fontFamily: "var(--font-serif)", fontSize: 21, fontWeight: 700 }}>
              欢迎使用 TypeZero for Windows
            </h2>
            <p style={{ fontSize: 12.5, color: "var(--ink-secondary)", marginTop: 2 }}>
              花 60 秒完成以下 3 步配置，即可在任意 Windows 软件中开口成文
            </p>
          </div>
          <span className="pill-badge pill-lilac" style={{ marginLeft: "auto", fontFamily: "var(--font-mono)" }}>
            v0.5
          </span>
        </div>

        <div style={{ height: 1, background: "var(--strong-line)" }} />

        {/* Step 1: Windows Mic Check (Zero Accessibility/TCC friction!) */}
        <div className="card" style={{ padding: 14, display: "flex", flexDirection: "column", gap: 8 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <strong style={{ fontSize: 13.5 }}>第 1 步 · 确认麦克风已连接（Windows 免辅助功能授权）</strong>
            <span className={`pill-badge ${snapshot.micAvailable ? "pill-ok" : "pill-warn"}`}>
              {snapshot.micAvailable ? <CheckCircle2 size={11} /> : <TriangleAlert size={11} />}
              <span>{snapshot.micAvailable ? "麦克风就绪" : "请检查麦克风"}</span>
            </span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span style={{ fontSize: 12, color: "var(--ink-secondary)", flex: 1 }}>
              Windows 版开箱即用，支持在微信、飞书、Word、WPS、Chrome、VS Code 等任意输入框直接全局上屏。
            </span>
            {!snapshot.micAvailable && (
              <button
                type="button"
                className="btn btn-primary btn-compact"
                onClick={() => void api.openWindowsMicSettings()}
              >
                打开麦克风隐私设置
              </button>
            )}
          </div>
        </div>

        {/* Step 2: Dual Keys */}
        <div className="card" style={{ padding: 14, display: "flex", flexDirection: "column", gap: 9 }}>
          <strong style={{ fontSize: 13.5 }}>第 2 步 · 填入语音与排版密钥（加密存于 Windows 凭据管理器）</strong>

          <div style={{ display: "flex", gap: 7, alignItems: "center" }}>
            <select
              className="select input-compact"
              style={{ width: 112, flexShrink: 0 }}
              value={asrChoice}
              onChange={(e) => setAsrChoice(e.target.value as ASRProviderOption)}
            >
              <option value="volcSeedASR">豆包语音</option>
              <option value="openAIWhisper">OpenAI语音</option>
              <option value="localSenseVoice">仅本机离线</option>
            </select>
            {asrChoice === "localSenseVoice" ? (
              <span style={{ fontSize: 12, color: "var(--ink-secondary)", flex: 1 }}>
                已选纯本机 SenseVoice 离线识别，可在下方第 3 步一键下载 886MB 满血模型
              </span>
            ) : (
              <>
                <input
                  type="password"
                  className="input input-compact"
                  placeholder={
                    asrChoice === "volcSeedASR"
                      ? "粘贴火山豆包语音 API Key"
                      : "粘贴 OpenAI / Groq Key（与下方 OpenAI Key 可共用）"
                  }
                  value={asrKey}
                  onChange={(e) => setAsrKey(e.target.value)}
                />
                <button
                  type="button"
                  className="btn btn-primary btn-compact"
                  onClick={() => void handleSaveASR()}
                >
                  保存
                </button>
              </>
            )}
          </div>

          <div style={{ display: "flex", gap: 7, alignItems: "center" }}>
            <select
              className="select input-compact"
              style={{ width: 112, flexShrink: 0 }}
              value={llmChoice}
              onChange={(e) => setLlmChoice(e.target.value as LLMProviderOption)}
            >
              {LLM_PROVIDERS.filter((p) => p.id !== "custom").map((p) => (
                <option key={p.id} value={p.id}>
                  {p.shortName}
                </option>
              ))}
            </select>
            <input
              type="password"
              className="input input-compact"
              placeholder="粘贴排版大模型 API Key（推荐 DeepSeek）"
              value={llmKey}
              onChange={(e) => setLlmKey(e.target.value)}
            />
            <button
              type="button"
              className="btn btn-primary btn-compact"
              onClick={() => void handleSaveLLM()}
            >
              保存
            </button>
          </div>
        </div>

        {/* Step 3: Windows Hotkey + Optional Offline Pack */}
        <div className="card" style={{ padding: 14, display: "flex", flexDirection: "column", gap: 9 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <strong style={{ fontSize: 13.5 }}>第 3 步 · 选择顺手 Windows 快捷键与离线热备包（可选）</strong>
            {snapshot.senseVoiceFullFp32 && <span className="pill-badge pill-ok">离线满血包已装好</span>}
          </div>

          <div className="hotkey-grid">
            {WINDOWS_HOTKEY_PRESETS.map((preset) => (
              <button
                key={preset.id}
                type="button"
                className={`hotkey-tile ${config.triggerKey === preset.id ? "selected" : ""}`}
                onClick={async () => {
                  await api.setTriggerKey(preset.id);
                  await onRefresh();
                }}
              >
                <span>{preset.label}</span>
                {preset.hint && <span className="hotkey-hint">{preset.hint}</span>}
              </button>
            ))}
          </div>

          {snapshot.isDownloadingOfflineModel ? (
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <div className="progress-track">
                <div
                  className="progress-fill"
                  style={{ width: `${Math.round(snapshot.offlineDownloadProgress * 100)}%` }}
                />
              </div>
              <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--violet)" }}>
                {snapshot.offlineDownloadStatusText}
              </span>
            </div>
          ) : (
            !snapshot.senseVoiceFullFp32 && (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <button
                  type="button"
                  className="btn btn-secondary btn-compact"
                  onClick={() => void api.startOfflineModelDownload()}
                >
                  <Download size={12} />
                  <span>后台下载 886MB 离线满血模型</span>
                </button>
                <span style={{ fontSize: 11.5, color: "var(--ink-muted)" }}>
                  日常有网用豆包无需下载；经常出差/无网建议后台下载
                </span>
              </div>
            )
          )}
        </div>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <span style={{ fontSize: 11.5, color: "var(--ink-muted)" }}>
            用法：聚焦任意输入框 ➔ 按一下 {snapshot.activeTriggerCompactLabel} 说话 ➔ 再按一下瞬间成稿
          </span>
          <button type="button" className="btn btn-primary" onClick={() => void handleComplete()}>
            完成配置，开始体验
          </button>
        </div>
      </div>
    </div>
  );
};
