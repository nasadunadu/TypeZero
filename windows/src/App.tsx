import React, { useCallback, useEffect, useState } from "react";
import { Sparkles, X } from "lucide-react";
import { api } from "./ipc";
import { DictionarySection } from "./components/DictionarySection";
import { HistorySection } from "./components/HistorySection";
import { HomeInsights } from "./components/HomeInsights";
import { OnboardingModal } from "./components/OnboardingModal";
import { SettingsSection } from "./components/SettingsSection";
import { Sidebar } from "./components/Sidebar";
import type { AppSnapshot, SidebarTab } from "./types";

export const App: React.FC = () => {
  const [snapshot, setSnapshot] = useState<AppSnapshot | null>(null);
  const [selectedTab, setSelectedTab] = useState<SidebarTab>("home");

  const refresh = useCallback(async () => {
    const snap = await api.getSnapshot();
    setSnapshot(snap);
  }, []);

  useEffect(() => {
    void refresh();
    let unlisten: (() => void) | undefined;
    void api.listenStateChanged((snap) => setSnapshot(snap)).then((fn) => {
      unlisten = fn;
    });
    return () => unlisten?.();
  }, [refresh]);

  if (!snapshot) {
    return (
      <div
        style={{
          height: "100vh",
          display: "grid",
          placeItems: "center",
          background: "var(--paper-bg)",
          color: "var(--ink-secondary)",
          fontSize: 13,
        }}
      >
        正在初始化 TypeZero for Windows…
      </div>
    );
  }

  const showOnboarding = !snapshot.config.onboardingCompleted;

  return (
    <div className="app-shell">
      <Sidebar
        snapshot={snapshot}
        selectedTab={selectedTab}
        onSelectTab={setSelectedTab}
        onOpenMicSettings={() => void api.openWindowsMicSettings()}
        onCheckForUpdates={() => void api.checkForUpdates(true).catch(() => {})}
        onInstallUpdate={() => void api.installAvailableUpdate().catch(() => {})}
      />

      <main className="main-scroll">
        <div className="main-container">
          {snapshot.availableUpdate &&
            (snapshot.isInstallingUpdate ||
              snapshot.availableUpdate.version !== snapshot.skippedUpdateVersion) && (
              <div
                style={{
                  background: "var(--lilac-tint, #ECE9FB)",
                  border: "1px solid rgba(90, 70, 232, 0.28)",
                  borderRadius: 11,
                  padding: "12px 14px",
                  marginBottom: 14,
                  display: "flex",
                  flexDirection: "column",
                  gap: 8,
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <Sparkles size={15} style={{ color: "var(--violet)", flexShrink: 0 }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>
                      发现新版本 TypeZero {snapshot.availableUpdate.tag}（当前 v{snapshot.currentVersion || "0.5.7"}）
                    </div>
                    <div style={{ fontSize: 11.5, color: "var(--ink-secondary)", marginTop: 2 }}>
                      {snapshot.isInstallingUpdate
                        ? snapshot.updateStatusText
                        : "无需重新打开官网 · 支持应用内校验 SHA-256 一键下载并无损覆盖升级"}
                    </div>
                  </div>
                  {!snapshot.isInstallingUpdate && (
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <button
                        type="button"
                        className="btn btn-secondary btn-compact"
                        onClick={async () => {
                          await api.dismissUpdateBanner();
                          await refresh();
                        }}
                      >
                        暂不提示
                      </button>
                      <button
                        type="button"
                        className="btn btn-primary btn-compact"
                        onClick={() => void api.installAvailableUpdate().catch(() => {})}
                      >
                        ⚡ 一键下载并升级
                      </button>
                    </div>
                  )}
                </div>
                {snapshot.isInstallingUpdate && (
                  <div className="progress-track" style={{ height: 6 }}>
                    <div
                      className="progress-fill"
                      style={{ width: `${Math.round((snapshot.updateDownloadProgress || 0) * 100)}%` }}
                    />
                  </div>
                )}
              </div>
            )}

          {snapshot.statusBanner && (
            <div className="status-banner" role="status">
              <Sparkles size={14} style={{ color: "var(--violet)", flexShrink: 0 }} />
              <span>{snapshot.statusBanner}</span>
              <button
                type="button"
                className="status-banner-close"
                onClick={async () => {
                  await api.clearStatusBanner();
                  await refresh();
                }}
                aria-label="关闭提示"
              >
                <X size={13} />
              </button>
            </div>
          )}

          {selectedTab === "home" && (
            <HomeInsights
              snapshot={snapshot}
              onChangeSandbox={async (text) => {
                setSnapshot((prev) => (prev ? { ...prev, sandboxText: text } : prev));
                await api.setSandboxText(text);
              }}
              onStartSandbox={() => void api.startSandboxDictation()}
              onStopDictation={() => void api.stopDictation()}
            />
          )}

          {selectedTab === "history" && (
            <HistorySection
              snapshot={snapshot}
              onCopyText={(txt) => void api.copyText(txt)}
              onQuickAddCorrection={async (term, alias) => {
                await api.upsertLexiconEntry(term, alias ? [alias] : [], "项目/技术", 9);
                await refresh();
              }}
            />
          )}

          {selectedTab === "dictionary" && (
            <DictionarySection
              snapshot={snapshot}
              onUpsert={async (term, aliases, cat, weight) => {
                await api.upsertLexiconEntry(term, aliases, cat, weight);
                await refresh();
              }}
              onUpdate={async (id, newTerm, newAliases, cat, weight) => {
                await api.updateLexiconEntry(id, newTerm, newAliases, cat, weight);
                await refresh();
              }}
              onRemove={async (id) => {
                await api.removeLexiconEntry(id);
                await refresh();
              }}
              onRemoveBatch={async (ids) => {
                await api.removeLexiconBatch(ids);
                await refresh();
              }}
              onBulkLines={async (raw, cat) => {
                await api.bulkImportLexiconLines(raw, cat);
                await refresh();
              }}
              onDistillCorpus={async (raw) => {
                await api.distillPastedCorpus(raw);
                await refresh();
              }}
              onImportFolder={async () => {
                await api.pickAndImportFolder();
                await refresh();
              }}
              onImportBrowsers={async () => {
                await api.importFromBrowsers();
                await refresh();
              }}
            />
          )}

          {selectedTab === "settings" && (
            <SettingsSection
              snapshot={snapshot}
              onUpdateConfig={async (nextCfg) => {
                setSnapshot((prev) => (prev ? { ...prev, config: nextCfg } : prev));
                await api.updatePreferences(nextCfg);
                await refresh();
              }}
              onRefresh={refresh}
            />
          )}
        </div>
      </main>

      {showOnboarding && (
        <OnboardingModal
          snapshot={snapshot}
          onRefresh={refresh}
          onFinish={async () => {
            await api.completeOnboarding();
            await refresh();
          }}
        />
      )}
    </div>
  );
};
