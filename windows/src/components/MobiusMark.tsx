import React, { useMemo } from "react";

interface Props {
  size?: number;
}

/** Custom vector Möbius Strip brand mark matching TypeZero macOS FloatingPillPanel.swift */
export const MobiusMark: React.FC<Props> = ({ size = 22 }) => {
  const gradId = useMemo(
    () => `tz-mobius-grad-${Math.random().toString(36).slice(2, 8)}`,
    [],
  );

  const pathData = useMemo(() => {
    const cx = 50;
    const cy = 52;
    const rx = 38;
    const ry = 24;
    const steps = 90;
    const pts: string[] = [];
    for (let i = 0; i <= steps; i++) {
      const t = (i / steps) * Math.PI * 2;
      const denom = 1 + Math.sin(t) * Math.sin(t);
      const x = cx + (rx * Math.cos(t)) / denom;
      const y = cy + (ry * 1.55 * Math.sin(t) * Math.cos(t)) / denom;
      pts.push(`${i === 0 ? "M" : "L"}${x.toFixed(2)},${y.toFixed(2)}`);
    }
    return `${pts.join(" ")} Z`;
  }, []);

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      fill="none"
      aria-hidden="true"
      style={{ flexShrink: 0 }}
    >
      <defs>
        <linearGradient id={gradId} x1="12%" y1="25%" x2="88%" y2="75%">
          <stop offset="0%" stopColor="#5A46E8" />
          <stop offset="50%" stopColor="#7C58F2" />
          <stop offset="100%" stopColor="#387DF5" />
        </linearGradient>
      </defs>
      <path
        d={pathData}
        stroke={`url(#${gradId})`}
        strokeWidth={14.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
