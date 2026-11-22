export type DictationMode = "dictate" | "rewriteSelection";

export type PipelinePhase =
  | { kind: "idle" }
  | { kind: "listening"; livePreview: string; mode: DictationMode }
  | { kind: "polishing"; rawText: string }
  | { kind: "completed"; finalText: string; latencyMs: number }
  | { kind: "savedToClipboard"; textPreview: string }
  | { kind: "error"; message: string };

export type TriggerKeyOption =
  | "rightAlt"
  | "rightCtrl"
  | "leftAlt"
  | "leftCtrl"
  | "rightShift"
  | "altSpace"
  | "ctrlSpace"
  | "leftShift"
  | "capsLock"
  | "f2"
  | "custom";

export interface CustomHotkeySpec {
  vkCode: number;
  modifiers: number;
  label: string;
}

export type TriggerBehavior = "tapToggle" | "holdToTalk";
export type ASRProviderOption = "volcSeedASR" | "openAIWhisper" | "localSenseVoice";
export type LLMProviderOption =
  | "deepseek"
  | "volcengine"
  | "dashscope"
  | "openai"
  | "gemini"
  | "anthropic"
  | "custom";
export type FormattingStyle = "structured" | "lightPolish" | "verbatimLocal";
export type LexiconCategory =
  | "人名/称呼"
  | "项目/技术"
  | "标的/商业"
  | "纪要/备忘"
  | "浏览高频"
  | "纠错自学习";

export interface LexiconEntry {
  id: string;
  term: string;
  aliases: string[];
  phoneticKey: string;
  category: LexiconCategory;
  weight: number;
  hitCount: number;
  createdAt: string;
}

export interface DictationRecord {
  id: string;
  timestamp: string;
  rawTranscript: string;
  polishedText: string;
  durationSeconds: number;
  polishLatencyMs: number;
  targetAppName: string;
  mode: DictationMode;
  matchedTerms: string[];
}

export interface LLMConfig {
  selectedProvider: LLMProviderOption;
  baseURL: string;
  modelName: string;
  customBaseURL: string;
  providerModels: Record<string, string>;
  formattingStyle: FormattingStyle;
  asrProvider: ASRProviderOption;
  openAIASRBaseURL: string;
  openAIASRModel: string;
  enableVolcSeedASR: boolean;
  enableLiveInlineTyping: boolean;
  enableFastBypassForShortPhrases: boolean;
  stripTrailingPeriodInChatApps: boolean;
  enablePanguSpacing: boolean;
  enableWhisperAGC: boolean;
  enableAutoLearn: boolean;
  enableAutoMuteDuringDictation: boolean;
  speechLocale: string;
  triggerKey: TriggerKeyOption;
  customHotkey: CustomHotkeySpec;
  triggerBehavior: TriggerBehavior;
  minimizeToTray: boolean;
  launchAtLogin: boolean;
  onboardingCompleted: boolean;
  useOfficialCloudTrial?: boolean;
}

export interface CloudUserProfile {
  id: string;
  email: string;
  balanceCny: number;
  balanceMicroCny?: number;
  totalUsedCny: number;
  asrSecondsUsed: number;
  llmRequestsUsed: number;
  trialGranted: boolean;
  isBanned: boolean;
}

export interface DashboardStats {
  totalCharacters: number;
  timeSavedMinutes: number;
  averageCpm: number;
  averageLatencyMs: number;
  activeDays: number;
  dailyCounts: Record<string, number>;
}

export interface AppSnapshot {
  phase: PipelinePhase;
  config: LLMConfig;
  history: DictationRecord[];
  lexicon: LexiconEntry[];
  savedProviderKeys: Record<string, boolean>;
  hasVolcSpeechKey: boolean;
  hasOpenaiAsrOverrideKey: boolean;
  hasEffectiveOpenaiAsrKey: boolean;
  isOpenaiAsrReusingLlmKey: boolean;
  micAvailable: boolean;
  senseVoiceLoaded: boolean;
  senseVoiceFullFp32: boolean;
  sherpaRuntimeAvailable: boolean;
  statusBanner: string;
  sandboxText: string;
  isRecordingShortcut: boolean;
  isDownloadingOfflineModel: boolean;
  offlineDownloadProgress: number;
  offlineDownloadStatusText: string;
  activeTriggerDisplayName: string;
  activeTriggerCompactLabel: string;
  stats: DashboardStats;
  cloudUser?: CloudUserProfile | null;
  isOfficialCloudTrialActive?: boolean;
}

export interface PillTelemetry {
  phase: PipelinePhase;
  audioLevel: number;
  recognizedCount: number;
  enableLiveInlineTyping: boolean;
}

export type SidebarTab = "home" | "history" | "dictionary" | "settings";

export const WINDOWS_HOTKEY_PRESETS: Array<{
  id: TriggerKeyOption;
  label: string;
  hint?: string;
}> = [
  { id: "rightAlt", label: "右侧 Alt", hint: "推荐" },
  { id: "rightCtrl", label: "右侧 Ctrl" },
  { id: "leftAlt", label: "左侧 Alt" },
  { id: "leftCtrl", label: "左侧 Ctrl" },
  { id: "rightShift", label: "右侧 Shift" },
  { id: "altSpace", label: "Alt + Space" },
  { id: "ctrlSpace", label: "Ctrl + Space" },
  { id: "leftShift", label: "左侧 Shift" },
  { id: "capsLock", label: "Caps Lock" },
  { id: "f2", label: "F2 功能键" },
];

export const LLM_PROVIDERS: Array<{
  id: LLMProviderOption;
  title: string;
  shortName: string;
  subtitle: string;
  defaultBaseURL: string;
  defaultModelName: string;
}> = [
  {
    id: "deepseek",
    title: "DeepSeek 4 Flash",
    shortName: "DeepSeek",
    subtitle: "极速主力推荐 · KV 缓存命中约 210ms 首包",
    defaultBaseURL: "https://api.deepseek.com/v1",
    defaultModelName: "deepseek-flash",
  },
  {
    id: "volcengine",
    title: "火山方舟 Doubao-Seed",
    shortName: "火山方舟",
    subtitle: "字节豆包大模型 · 支持 Seed-2.1-lite 或 ep- 接入点",
    defaultBaseURL: "https://ark.cn-beijing.volces.com/api/v3",
    defaultModelName: "doubao-seed-2-1-lite-260915",
  },
  {
    id: "dashscope",
    title: "阿里百炼 Qwen-Flash",
    shortName: "阿里百炼",
    subtitle: "阿里云百炼兼容模式 · 通义极速轻量模型",
    defaultBaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
    defaultModelName: "qwen-flash",
  },
  {
    id: "openai",
    title: "OpenAI GPT",
    shortName: "OpenAI",
    subtitle: "OpenAI 官方直连 · 兼容 gpt-4.1-mini / gpt-5-mini / gpt-4o-mini",
    defaultBaseURL: "https://api.openai.com/v1",
    defaultModelName: "gpt-4.1-mini",
  },
  {
    id: "gemini",
    title: "Google Gemini",
    shortName: "Gemini",
    subtitle: "Google AI Studio 官方兼容通道 · 支持 gemini-3.8-flash / 2.5-flash",
    defaultBaseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
    defaultModelName: "gemini-3.8-flash",
  },
  {
    id: "anthropic",
    title: "Anthropic Claude",
    shortName: "Claude",
    subtitle: "Anthropic 原生 Messages 流式协议 · 支持 claude-haiku-5-5 / 4-5",
    defaultBaseURL: "https://api.anthropic.com/v1",
    defaultModelName: "claude-haiku-5-5",
  },
  {
    id: "custom",
    title: "自定义 OpenAI 兼容接口",
    shortName: "自定义接口",
    subtitle: "支持 SiliconFlow / OpenRouter / MiniMax / 本地 Ollama & LM Studio 免密",
    defaultBaseURL: "https://api.siliconflow.cn/v1",
    defaultModelName: "deepseek-ai/DeepSeek-V3",
  },
];

export const LEXICON_CATEGORIES: LexiconCategory[] = [
  "人名/称呼",
  "项目/技术",
  "标的/商业",
  "纪要/备忘",
  "浏览高频",
  "纠错自学习",
];
