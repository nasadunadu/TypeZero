import React, { useEffect, useRef, useState } from "react";
import { AlertTriangle, CheckCircle2, ClipboardCheck } from "lucide-react";
import { api } from "../ipc";
import { MobiusMark } from "./MobiusMark";
import type { PillTelemetry } from "../types";

const GLYPH_CYCLE = ["•", "·", "✦", "•", "▪", "·"];

/** 120Hz Canvas 3-layer fluid sine wave identical in feel to macOS FloatingPillPanel.swift */
const FluidSineWaveCanvas: React.FC<{ levelRef: React.MutableRefObject<number>; accent: string; width: number; height: number }> = ({
  levelRef,
  accent,
  width,
  height,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    let rafId = 0;
    let displayLevel = 0.08;
    const t0 = performance.now();

    const draw = (now: number) => {
      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext("2d");
        if (ctx) {
          const dpr = window.devicePixelRatio || 1;
          if (canvas.width !== Math.round(width * dpr) || canvas.height !== Math.round(height * dpr)) {
            canvas.width = Math.round(width * dpr);
            canvas.height = Math.round(height * dpr);
          }
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          ctx.clearRect(0, 0, width, height);

          const target = Math.max(0.06, Math.min(1.0, levelRef.current));
          const coeff = target > displayLevel ? 0.36 : 0.14;
          displayLevel += (target - displayLevel) * coeff;

          const t = (now - t0) / 1000;
          const midY = height * 0.5;
          const amp = Math.max(1.6, displayLevel * height * 0.47);

          const layers = [
            { speed: 10.5, freq: 2.7, scale: 1.0, opacity: 0.94, lw: 1.9 },
            { speed: 7.4, freq: 2.0, scale: 0.78, opacity: 0.42, lw: 1.35 },
            { speed: 5.2, freq: 1.5, scale: 0.55, opacity: 0.2, lw: 1.0 },
          ];

          layers.forEach((layer, idx) => {
            ctx.beginPath();
            const phaseShift = idx * 1.15;
            for (let x = 0; x <= width; x += 2) {
              const norm = x / width;
              const envelope = Math.pow(Math.sin(norm * Math.PI), 1.25);
              const yOffset =
                Math.sin(norm * Math.PI * layer.freq - t * layer.speed + phaseShift) *
                (amp * layer.scale) *
                envelope;
              const y = midY + yOffset;
              if (x === 0) ctx.moveTo(x, y);
              else ctx.lineTo(x, y);
            }
            ctx.strokeStyle = accent;
            ctx.globalAlpha = layer.opacity;
            ctx.lineWidth = layer.lw;
            ctx.lineCap = "round";
            ctx.stroke();
          });
          ctx.globalAlpha = 1;
        }
      }
      rafId = requestAnimationFrame(draw);
    };

    rafId = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafId);
  }, [accent, height, levelRef, width]);

  return <canvas ref={canvasRef} style={{ width, height, display: "block" }} />;
};

export const FloatingPill: React.FC = () => {
  const [telemetry, setTelemetry] = useState<PillTelemetry>({
    phase: { kind: "idle" },
    audioLevel: 0.08,
    recognizedCount: 0,
    enableLiveInlineTyping: false,
  });
  const levelRef = useRef<number>(0.08);

  useEffect(() => {
    let unlisten: (() => void) | undefined;
    void api.listenPillTelemetry((tel) => {
      levelRef.current = tel.audioLevel;
      setTelemetry(tel);
    }).then((fn) => {
      unlisten = fn;
    });
    return () => unlisten?.();
  }, []);

  const { phase, recognizedCount, enableLiveInlineTyping } = telemetry;

  if (phase.kind === "idle") {
    return <div className="pill-stage" />;
  }

  if (phase.kind === "listening") {
    const accent = phase.mode === "rewriteSelection" ? "#8F3DE0" : "#5A46E8";

    if (enableLiveInlineTyping || phase.mode === "rewriteSelection") {
      return (
        <div className="pill-stage">
          <div className="pill-shell compact">
            <MobiusMark size={16} />
            <FluidSineWaveCanvas levelRef={levelRef} accent={accent} width={64} height={16} />
          </div>
        </div>
      );
    }

    const maxWindow = 12;
    const windowCount = Math.min(maxWindow, recognizedCount);
    const startSerial = Math.max(0, recognizedCount - maxWindow);

    return (
      <div className="pill-stage">
        <div className="pill-shell">
          <div className="pill-symbol-row">
            {windowCount === 0 ? (
              <div className="shimmer-dots">
                <span className="shimmer-dot" style={{ width: 3.5, height: 3.5, background: "#17161B" }} />
                <span className="shimmer-dot" style={{ width: 3.5, height: 3.5, background: "#17161B" }} />
                <span className="shimmer-dot" style={{ width: 3.5, height: 3.5, background: "#17161B" }} />
              </div>
            ) : (
              <>
                <div style={{ display: "flex", alignItems: "center", gap: 3 }}>
                  {Array.from({ length: windowCount }).map((_, slot) => {
                    const serial = startSerial + slot;
                    const glyph = GLYPH_CYCLE[serial % GLYPH_CYCLE.length];
                    const isNewest = slot === windowCount - 1;
                    return (
                      <span
                        key={serial}
                        style={{
                          fontFamily: "var(--font-mono)",
                          fontSize: glyph === "✦" ? 8.5 : 10.5,
                          fontWeight: 700,
                          color: isNewest ? accent : "rgba(23, 22, 27, 0.68)",
                        }}
                      >
                        {glyph}
                      </span>
                    );
                  })}
                </div>
                <span className="pill-symbol-count">{recognizedCount}</span>
              </>
            )}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <MobiusMark size={14} />
            <FluidSineWaveCanvas levelRef={levelRef} accent={accent} width={88} height={14} />
          </div>
        </div>
      </div>
    );
  }

  if (phase.kind === "polishing") {
    return (
      <div className="pill-stage">
        <div className="pill-shell compact" style={{ borderColor: "rgba(90, 70, 232, 0.28)" }}>
          <MobiusMark size={15} />
          <div className="shimmer-dots">
            <span className="shimmer-dot" />
            <span className="shimmer-dot" />
            <span className="shimmer-dot" />
          </div>
        </div>
      </div>
    );
  }

  if (phase.kind === "completed") {
    return (
      <div className="pill-stage">
        <div className="pill-shell compact">
          <CheckCircle2 size={14} color="#14804A" />
        </div>
      </div>
    );
  }

  if (phase.kind === "savedToClipboard") {
    return (
      <div className="pill-stage">
        <div className="pill-shell compact" style={{ borderColor: "rgba(26, 107, 255, 0.35)" }}>
          <ClipboardCheck size={13} color="#1A6BFF" />
          <span style={{ fontSize: 11, fontWeight: 600, color: "#17161B", whiteSpace: "nowrap" }}>
            {phase.textPreview}
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="pill-stage">
      <div className="pill-shell compact" style={{ borderColor: "rgba(209, 50, 60, 0.35)" }}>
        <AlertTriangle size={13} color="#D1323C" />
        <span style={{ fontSize: 11, fontWeight: 600, color: "#D1323C", maxWidth: 180, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {phase.message}
        </span>
      </div>
    </div>
  );
};
