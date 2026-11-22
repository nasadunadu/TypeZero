import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import { open as openDialog } from "@tauri-apps/plugin-dialog";
import type {
  AppSnapshot,
  ASRProviderOption,
  FormattingStyle,
  LLMConfig,
  LLMProviderOption,
  LexiconCategory,
  PillTelemetry,
  TriggerBehavior,
  TriggerKeyOption,
} from "./types";

export function isTauriRuntime(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

const DEMO_SNAPSHOT: AppSnapshot = {
  phase: { kind: "idle" },
  config: {
    selectedProvider: "deepseek",
    baseURL: "https://api.deepseek.com/v1",
    modelName: "deepseek-flash",
    customBaseURL: "https://api.siliconflow.cn/v1",
    providerModels: { deepseek: "deepseek-flash" },
    formattingStyle: "structured",
    asrProvider: "volcSeedASR",
    openAIASRBaseURL: "https://api.openai.com/v1",
    openAIASRModel: "gpt-4o-mini-transcribe",
    enableVolcSeedASR: true,
    enableLiveInlineTyping: false,
    enableFastBypassForShortPhrases: true,
    stripTrailingPeriodInChatApps: true,
    enablePanguSpacing: true,
    enableWhisperAGC: true,
    enableAutoLearn: true,
    enableAutoMuteDuringDictation: true,
    speechLocale: "zh-CN",
    triggerKey: "rightAlt",
    customHotkey: { vkCode: 0x20, modifiers: 5, label: "Ctrl + Shift + Space" },
    triggerBehavior: "tapToggle",
    minimizeToTray: true,
    launchAtLogin: false,
    onboardingCompleted: true,
  },
  history: [
    {
      id: "demo-1",
      timestamp: new Date().toISOString(),
      rawTranscript:
        "嗯我们今天在 Windows 上测三件事第一右Alt一键启停会不会激活菜单栏第二微信和飞书里多行粘贴安不安全第三断网切回本地SenseVoice满血模型",
      polishedText:
        "我们今天在 Windows 上测 3 件事：\n1. 右 Alt 一键启停是否完全屏蔽菜单栏误激活；\n2. 微信和飞书里多行粘贴是否安全框内换行；\n3. 断网时自动切回本地 SenseVoice 满血模型。",
      durationSeconds: 7.4,
      polishLatencyMs: 218,
      targetAppName: "Feishu",
      mode: "dictate",
      matchedTerms: ["SenseVoice", "Windows"],
    },
  ],
  lexicon: [
    {
      id: "lex-1",
      term: "DeepSeek",
      aliases: ["迪普西克", "deep seek"],
      phoneticKey: "deepseek",
      category: "项目/技术",
      weight: 9,
      hitCount: 18,
      createdAt: new Date().toISOString(),
    },
    {
      id: "lex-2",
      term: "TypeZero",
      aliases: ["type zero", "太普零"],
      phoneticKey: "typezero",
      category: "项目/技术",
      weight: 9,
      hitCount: 12,
      createdAt: new Date().toISOString(),
    },
  ],
  savedProviderKeys: { deepseek: true },
  hasVolcSpeechKey: true,
  hasOpenaiAsrOverrideKey: false,
  hasEffectiveOpenaiAsrKey: false,
  isOpenaiAsrReusingLlmKey: false,
  micAvailable: true,
  senseVoiceLoaded: true,
  senseVoiceFullFp32: true,
  sherpaRuntimeAvailable: true,
  statusBanner: "",
  sandboxText: "",
  isRecordingShortcut: false,
  isDownloadingOfflineModel: false,
  offlineDownloadProgress: 0,
  offlineDownloadStatusText: "",
  activeTriggerDisplayName: "右侧 Alt（推荐）",
  activeTriggerCompactLabel: "右 Alt",
  stats: {
    totalCharacters: 12480,
    timeSavedMinutes: 214,
    averageCpm: 196,
    averageLatencyMs: 218,
    activeDays: 19,
    dailyCounts: {
      [new Date().toISOString().slice(0, 10)]: 680,
    },
  },
};

export const api = {
  async getSnapshot(): Promise<AppSnapshot> {
    if (!isTauriRuntime()) return structuredClone(DEMO_SNAPSHOT);
    return invoke<AppSnapshot>("get_app_snapshot");
  },

  async clearStatusBanner(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("clear_status_banner");
  },

  async setSandboxText(text: string): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("set_sandbox_text", { text });
  },

  async startSandboxDictation(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("start_sandbox_dictation");
  },

  async stopDictation(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("stop_dictation");
  },

  async copyText(text: string): Promise<void> {
    if (!isTauriRuntime()) {
      await navigator.clipboard?.writeText(text).catch(() => {});
      return;
    }
    await invoke("copy_text_to_clipboard", { text });
  },

  async updatePreferences(config: LLMConfig): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("update_preferences", { config });
  },

  async setTriggerKey(key: TriggerKeyOption): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("set_trigger_key", { key });
  },

  async setTriggerBehavior(behavior: TriggerBehavior): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("set_trigger_behavior", { behavior });
  },

  async setFormattingStyle(style: FormattingStyle): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("set_formatting_style", { style });
  },

  async startShortcutCapture(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("start_shortcut_capture");
  },

  async cancelShortcutCapture(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("cancel_shortcut_capture");
  },

  async saveVolcSpeechKey(apiKey: string): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("save_volc_speech_key", { apiKey });
  },

  async saveOpenAIASRConfig(baseUrl: string, model: string, apiKey: string): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("save_openai_asr_config", { baseUrl, model, apiKey });
  },

  async probeSeedASR(apiKey: string): Promise<string> {
    if (!isTauriRuntime()) return "⚡ 预览模式模拟测速：118ms";
    return invoke<string>("probe_seed_asr", { apiKey });
  },

  async probeOpenAIASR(baseUrl: string, model: string, apiKey: string): Promise<string> {
    if (!isTauriRuntime()) return "⚡ 预览模式模拟测速：240ms";
    return invoke<string>("probe_openai_asr", { baseUrl, model, apiKey });
  },

  async activateASRProvider(
    provider: ASRProviderOption,
    apiKey: string,
    openaiUrl: string,
    openaiModel: string,
  ): Promise<string> {
    if (!isTauriRuntime()) return "⚡ 已切换生效（预览模式）";
    return invoke<string>("activate_asr_provider", {
      provider,
      apiKey,
      openaiUrl,
      openaiModel,
    });
  },

  async saveLLMProviderDraft(
    provider: LLMProviderOption,
    baseUrl: string,
    modelName: string,
    apiKey: string,
  ): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("save_llm_provider_draft", {
      provider,
      baseUrl,
      modelName,
      apiKey,
    });
  },

  async benchmarkLLMProvider(
    provider: LLMProviderOption,
    baseUrl: string,
    modelName: string,
    apiKey: string,
  ): Promise<string> {
    if (!isTauriRuntime()) return "⚡ 预览模式模拟测速：TTFT 215ms";
    return invoke<string>("benchmark_llm_provider", {
      provider,
      baseUrl,
      modelName,
      apiKey,
    });
  },

  async activateLLMProvider(
    provider: LLMProviderOption,
    baseUrl: string,
    modelName: string,
    apiKey: string,
  ): Promise<string> {
    if (!isTauriRuntime()) return "⚡ 已校验生效（预览模式）";
    return invoke<string>("activate_llm_provider", {
      provider,
      baseUrl,
      modelName,
      apiKey,
    });
  },

  async upsertLexiconEntry(
    term: string,
    aliases: string[],
    category: LexiconCategory,
    weight: number,
  ): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("upsert_lexicon_entry", { term, aliases, category, weight });
  },

  async updateLexiconEntry(
    id: string,
    newTerm: string,
    newAliases: string[],
    newCategory: LexiconCategory,
    newWeight: number,
  ): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("update_lexicon_entry", {
      id,
      newTerm,
      newAliases,
      newCategory,
      newWeight,
    });
  },

  async removeLexiconEntry(id: string): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("remove_lexicon_entry", { id });
  },

  async removeLexiconBatch(ids: string[]): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("remove_lexicon_batch", { ids });
  },

  async bulkImportLexiconLines(rawText: string, category: LexiconCategory): Promise<number> {
    if (!isTauriRuntime()) return 0;
    return invoke<number>("bulk_import_lexicon_lines", { rawText, category });
  },

  async distillPastedCorpus(rawCorpus: string): Promise<number> {
    if (!isTauriRuntime()) return 0;
    return invoke<number>("distill_pasted_corpus", { rawCorpus });
  },

  async pickAndImportFolder(): Promise<number> {
    if (!isTauriRuntime()) return 0;
    const selected = await openDialog({
      directory: true,
      multiple: false,
      title: "选择包含会议纪要或 Markdown 笔记的文件夹",
    });
    if (typeof selected === "string" && selected.length > 0) {
      return invoke<number>("import_lexicon_from_folder", { folderPath: selected });
    }
    return 0;
  },

  async importFromBrowsers(): Promise<number> {
    if (!isTauriRuntime()) return 0;
    return invoke<number>("import_lexicon_from_browsers");
  },

  async startOfflineModelDownload(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("start_offline_model_download");
  },

  async cancelOfflineModelDownload(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("cancel_offline_model_download");
  },

  async completeOnboarding(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("complete_onboarding");
  },

  async openWindowsMicSettings(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("open_windows_mic_settings");
  },

  async cloudRefreshProfile(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("cloud_refresh_profile");
  },

  async cloudSendEmailCode(email: string): Promise<string> {
    if (!isTauriRuntime()) return "演示模式：验证码已发送";
    return invoke<string>("cloud_send_email_code", { email });
  },

  async cloudVerifyEmailCode(email: string, code: string): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("cloud_verify_email_code", { email, code });
  },

  async cloudStartGoogleLogin(): Promise<{ sessionId: string; authUrl: string }> {
    if (!isTauriRuntime()) {
      throw new Error("请在 Windows 桌面客户端中使用 Google 登录");
    }
    return invoke<{ sessionId: string; authUrl: string }>("cloud_start_google_login");
  },

  async cloudPollGoogleLogin(sessionId: string): Promise<{ status: string; error?: string }> {
    if (!isTauriRuntime()) return { status: "expired" };
    return invoke<{ status: string; error?: string }>("cloud_poll_google_login", { sessionId });
  },

  async cloudSetUseTrial(enabled: boolean): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("cloud_set_use_trial", { enabled });
  },

  async cloudLogout(): Promise<void> {
    if (!isTauriRuntime()) return;
    await invoke("cloud_logout");
  },

  async listenStateChanged(cb: (snap: AppSnapshot) => void): Promise<UnlistenFn> {
    if (!isTauriRuntime()) return () => {};
    return listen<AppSnapshot>("state-changed", (ev) => cb(ev.payload));
  },

  async listenPillTelemetry(cb: (tel: PillTelemetry) => void): Promise<UnlistenFn> {
    if (!isTauriRuntime()) return () => {};
    return listen<PillTelemetry>("pill-telemetry", (ev) => cb(ev.payload));
  },
};
