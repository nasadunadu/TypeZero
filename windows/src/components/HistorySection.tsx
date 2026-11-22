import React, { useState } from "react";
import { Check, Copy, Wand2 } from "lucide-react";
import type { AppSnapshot } from "../types";

interface Props {
  snapshot: AppSnapshot;
  onCopyText: (text: string) => void;
  onQuickAddCorrection: (term: string, alias: string) => Promise<void>;
}

export const HistorySection: React.FC<Props> = ({
  snapshot,
  onCopyText,
  onQuickAddCorrection,
}) => {
  const [quickTerm, setQuickTerm] = useState("");
  const [quickAlias, setQuickAlias] = useState("");
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const handleCopy = (id: string, text: string) => {
    onCopyText(text);
    setCopiedId(id);
    setTimeout(() => {
      setCopiedId((prev) => (prev === id ? null : prev));
    }, 1400);
  };

  const handleQuickAdd = async () => {
    if (!quickTerm.trim()) return;
    await onQuickAddCorrection(quickTerm.trim(), quickAlias.trim());
    setQuickTerm("");
    setQuickAlias("");
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
      <header className="editorial-header">
        <div className="editorial-header-top">
          <h1 className="editorial-title">口述历史与原声对照</h1>
          <span className="editorial-badge">
            UTTERANCE ARCHIVE · {snapshot.history.length} RECORDS
          </span>
        </div>
        <div className="editorial-sub">
          <span className="editorial-sub-bar" />
          <span>保留每一条声学原稿与大模型结构化成品对照 ｜ 发现偶发误听可一键回流至专属词库</span>
        </div>
        <div className="editorial-rule" />
      </header>

      {/* Quick Correction Bar */}
      <section className="card" style={{ display: "flex", alignItems: "center", gap: 10, padding: "13px 15px" }}>
        <Wand2 size={15} style={{ color: "var(--violet)", flexShrink: 0 }} />
        <input
          className="input"
          placeholder="正确标准词（如 DeepSeek）"
          value={quickTerm}
          onChange={(e) => setQuickTerm(e.target.value)}
        />
        <input
          className="input"
          placeholder="刚才被误听成的词（如 迪普西克）"
          value={quickAlias}
          onChange={(e) => setQuickAlias(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void handleQuickAdd();
          }}
        />
        <button type="button" className="btn btn-primary" onClick={() => void handleQuickAdd()}>
          记入词库纠偏
        </button>
      </section>

      {snapshot.history.length === 0 ? (
        <section className="card" style={{ padding: 26 }}>
          <div style={{ fontSize: 15, fontWeight: 600 }}>尚无口述记录</div>
          <p style={{ fontSize: 13, color: "var(--ink-secondary)", marginTop: 6 }}>
            按下 <strong>{snapshot.activeTriggerDisplayName}</strong> 口述任意内容后，此处将自动记录原声粗稿、排版成品与首包耗时。
          </p>
        </section>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {snapshot.history.map((rec) => (
            <article key={rec.id} className="card" style={{ display: "flex", flexDirection: "column", gap: 10, padding: 16 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span className="pill-badge pill-lilac">
                  {rec.mode === "rewriteSelection" ? "选中改写" : "口述成稿"}
                </span>
                <span style={{ fontSize: 12, fontWeight: 600, color: "var(--ink-secondary)" }}>
                  {rec.targetAppName || "外部应用"}
                </span>
                <span
                  style={{
                    marginLeft: "auto",
                    fontFamily: "var(--font-mono)",
                    fontSize: 11,
                    color: "var(--ink-muted)",
                  }}
                >
                  首包 {rec.polishLatencyMs}ms · 录音 {rec.durationSeconds.toFixed(1)}s
                </span>
                <button
                  type="button"
                  className="btn btn-secondary btn-compact"
                  onClick={() => handleCopy(rec.id, rec.polishedText)}
                >
                  {copiedId === rec.id ? <Check size={11} /> : <Copy size={11} />}
                  <span>{copiedId === rec.id ? "已复制" : "复制"}</span>
                </button>
              </div>

              <div
                style={{
                  fontSize: 14,
                  lineHeight: 1.65,
                  whiteSpace: "pre-wrap",
                  color: "var(--ink-primary)",
                }}
              >
                {rec.polishedText}
              </div>

              {rec.rawTranscript !== rec.polishedText && (
                <div
                  style={{
                    display: "flex",
                    alignItems: "flex-start",
                    gap: 8,
                    padding: "7px 10px",
                    borderRadius: 8,
                    background: "var(--soft-well)",
                    fontSize: 12,
                    color: "var(--ink-secondary)",
                  }}
                >
                  <span
                    style={{
                      fontFamily: "var(--font-mono)",
                      fontSize: 10.5,
                      fontWeight: 600,
                      color: "var(--ink-muted)",
                      flexShrink: 0,
                      marginTop: 1,
                    }}
                  >
                    声学原稿
                  </span>
                  <span style={{ lineHeight: 1.5 }}>{rec.rawTranscript}</span>
                </div>
              )}
            </article>
          ))}
        </div>
      )}
    </div>
  );
};
