import React, { useMemo } from "react";
import { Mic, Square } from "lucide-react";
import type { AppSnapshot } from "../types";

interface Props {
  snapshot: AppSnapshot;
  onChangeSandbox: (text: string) => void;
  onStartSandbox: () => void;
  onStopDictation: () => void;
}

function formatCount(n: number): string {
  if (n >= 10_000) return `${(n / 1000).toFixed(1)}K`;
  return String(n);
}

function cellColor(chars: number): string {
  if (chars === 0) return "rgba(234, 230, 219, 0.65)";
  if (chars < 200) return "#cfc7f7";
  if (chars < 800) return "#9482f0";
  return "#5a46e8";
}

export const HomeInsights: React.FC<Props> = ({
  snapshot,
  onChangeSandbox,
  onStartSandbox,
  onStopDictation,
}) => {
  const isRecording = snapshot.phase.kind === "listening";
  const isPolishing = snapshot.phase.kind === "polishing";

  const heatmapWeeks = useMemo(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const weeks: Array<Array<{ dateKey: string; chars: number }>> = [];
    for (let w = 0; w < 26; w++) {
      const col: Array<{ dateKey: string; chars: number }> = [];
      for (let d = 0; d < 7; d++) {
        const offsetDays = -((25 - w) * 7 + (6 - d));
        const dt = new Date(today.getTime() + offsetDays * 86_400_000);
        const key = `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(
          dt.getDate(),
        ).padStart(2, "0")}`;
        col.push({ dateKey: key, chars: snapshot.stats.dailyCounts[key] ?? 0 });
      }
      weeks.push(col);
    }
    return weeks;
  }, [snapshot.stats.dailyCounts]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      <header className="editorial-header">
        <div className="editorial-header-top">
          <h1 className="editorial-title">说话，不要打字</h1>
          <span className="editorial-badge">WINDOWS NATIVE · V0.5</span>
        </div>
        <div className="editorial-sub">
          <span className="editorial-sub-bar" />
          <span>
            豆包 Seed-ASR 2.0 / OpenAI & Groq / 本机 886MB SenseVoice FP32 三擎声学 ｜ 亚秒级结构化排版与模糊声韵专属词库
          </span>
        </div>
        <div className="editorial-rule" />
      </header>

      {/* 4-Column Big-Number Strip */}
      <section className="card">
        <div className="stats-strip">
          <div className="stat-col">
            <div className="stat-val-row">
              <span className="stat-val highlight">
                {formatCount(snapshot.stats.totalCharacters)}
              </span>
              <span className="stat-unit">字</span>
            </div>
            <div className="stat-label">累计口述成稿</div>
          </div>

          <div className="stat-col">
            <div className="stat-val-row">
              <span className="stat-val">{snapshot.stats.timeSavedMinutes}</span>
              <span className="stat-unit">分钟</span>
            </div>
            <div className="stat-label">累计节省敲键时间</div>
          </div>

          <div className="stat-col">
            <div className="stat-val-row">
              <span className="stat-val">{snapshot.stats.averageCpm}</span>
              <span className="stat-unit">字/分</span>
            </div>
            <div className="stat-label">平均口述吞吐语速</div>
          </div>

          <div className="stat-col">
            <div className="stat-val-row">
              <span className="stat-val">
                {snapshot.stats.averageLatencyMs > 0 ? snapshot.stats.averageLatencyMs : "—"}
              </span>
              <span className="stat-unit">ms</span>
            </div>
            <div className="stat-label">云端平均首包延迟</div>
          </div>
        </div>
      </section>

      {/* 26-Week Heatmap */}
      <section className="card">
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 12 }}>
          <div>
            <div style={{ fontSize: 15, fontWeight: 600 }}>创作节律热力矩阵</div>
            <div style={{ fontSize: 12, color: "var(--ink-secondary)", marginTop: 3 }}>
              过去 26 周每日语音创作密度分布 · 活跃 {snapshot.stats.activeDays} 天 · 词库守护{" "}
              {snapshot.lexicon.length} 词
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 10.5, color: "var(--ink-muted)" }}>
            <span>少</span>
            {[0, 120, 450, 1000].map((v) => (
              <span
                key={v}
                style={{
                  width: 10,
                  height: 10,
                  borderRadius: 2.5,
                  background: cellColor(v),
                  display: "inline-block",
                }}
              />
            ))}
            <span>多</span>
          </div>
        </div>

        <div className="heatmap-grid">
          {heatmapWeeks.map((col, wIdx) => (
            <div key={wIdx} className="heatmap-col">
              {col.map((cell) => (
                <div
                  key={cell.dateKey}
                  className="heatmap-cell"
                  style={{ background: cellColor(cell.chars) }}
                  title={`${cell.dateKey}：${cell.chars} 字`}
                />
              ))}
            </div>
          ))}
        </div>
      </section>

      {/* Live Test & Structuring Sandbox */}
      <section className="card" style={{ display: "flex", flexDirection: "column", gap: 11 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: "50%",
              background: isRecording ? "var(--crimson)" : "var(--violet)",
            }}
          />
          <span style={{ fontSize: 15, fontWeight: 600 }}>原位试音与排版沙盒</span>
          <div style={{ marginLeft: "auto", display: "flex", gap: 8 }}>
            {snapshot.sandboxText.length > 0 && (
              <button
                type="button"
                className="btn btn-secondary btn-compact"
                onClick={() => onChangeSandbox("")}
              >
                清空
              </button>
            )}
            <button
              type="button"
              className="btn btn-primary btn-compact"
              disabled={isPolishing}
              onClick={() => (isRecording ? onStopDictation() : onStartSandbox())}
            >
              {isRecording ? <Square size={11} /> : <Mic size={12} />}
              <span>
                {isPolishing
                  ? "智能排版中…"
                  : isRecording
                    ? "停止并触发排版"
                    : "点击试音（或直接按快捷键）"}
              </span>
            </button>
          </div>
        </div>

        <p style={{ fontSize: 12, color: "var(--ink-secondary)", lineHeight: 1.55 }}>
          日常在任意 Windows 软件（微信 / 飞书 / 钉钉 / Word / WPS / Chrome / Edge / VS Code / Cursor）聚焦输入框后，直接按{" "}
          <strong style={{ color: "var(--ink-primary)" }}>{snapshot.activeTriggerDisplayName}</strong>{" "}
          说话即可瞬间上屏；也可直接在下方沙盒体验 `1. 2. 3.` 智能列点与自然分段。
        </p>

        <textarea
          className="textarea"
          rows={5}
          value={snapshot.sandboxText}
          onChange={(e) => onChangeSandbox(e.target.value)}
          placeholder="试着按下快捷键说：「我们今天做三件事，第一把 Windows 版本打包发给同事测试，第二检查微信和飞书里多行粘贴效果，第三补充个人专属词库……」"
          style={{
            borderColor: isRecording ? "rgba(90, 70, 232, 0.58)" : undefined,
            fontSize: 13.5,
          }}
        />
      </section>
    </div>
  );
};
