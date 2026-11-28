(() => {
  "use strict";

  const STAGE = {
    width: 540,
    height: 396,
    anchorX: 256,
    anchorY: 368
  };

  const KB = { x: 118, y: 331, width: 276, height: 72 };
  const KB_BASE_Z = 8;
  const CAP_TOP_Z = 11.8;
  const KB_MID_X = KB.x + KB.width / 2;
  const KB_BOTTOM_Y = KB.y + KB.height;
  const PERSP_DIST = 520;
  const PERSP_TILT = 0.68;
  const PERSP_ORIGIN_Y = 340;
  const BASE_SCALE = 0.82;

  function projectDeck(x, y, z = 0) {
    const s = PERSP_DIST / (PERSP_DIST + KB_BOTTOM_Y - y);
    const dx = (x - KB_MID_X) * s;
    return {
      x: KB_MID_X + dx,
      y: PERSP_ORIGIN_Y + (y - KB.y) * PERSP_TILT * s - z * s
    };
  }

  function unprojectDeck(pt) {
    const dy = pt.y - PERSP_ORIGIN_Y;
    const ny = KB.y + (dy * (PERSP_DIST + KB.height)) / (PERSP_DIST * PERSP_TILT + dy);
    return {
      x: KB_MID_X + ((pt.x - KB_MID_X) * (PERSP_DIST + KB_BOTTOM_Y - ny)) / PERSP_DIST,
      y: ny
    };
  }

  function deckQuad(x, y, w, h, z) {
    return [
      projectDeck(x, y, z),
      projectDeck(x + w, y, z),
      projectDeck(x + w, y + h, z),
      projectDeck(x, y + h, z)
    ];
  }

  const KEY_ROWS = [
    [["Escape", "ESC"], ..."1234567890".split("").map((d) => [`Digit${d}`, d]), ["Minus", "−"], ["Equal", "+"], ["Backspace", "⌫", 1.8]],
    [["Tab", "⇥", 1.35], ..."QWERTYUIOP".split("").map((k) => [`Key${k}`, k]), ["BracketLeft", "["], ["BracketRight", "]"], ["Backslash", "\\", 1.45]],
    [["CapsLock", "⇪", 1.7], ..."ASDFGHJKL".split("").map((k) => [`Key${k}`, k]), ["Semicolon", ";"], ["Quote", "'"], ["Enter", "↵", 2.1]],
    [["ShiftLeft", "⇧", 2.15], ..."ZXCVBNM".split("").map((k) => [`Key${k}`, k]), ["Comma", ","], ["Period", "."], ["Slash", "/"], ["ShiftRight", "⇧", 2.65]],
    [["ControlLeft", "ctrl", 1.35], ["AltLeft", "⌥", 1.2], ["MetaLeft", "⌘", 1.35], ["Space", "space", 5.5], ["MetaRight", "⌘", 1.3], ["AltRight", "⌥", 1.2], ["ControlRight", "ctrl"], ["ArrowLeft", "←"], ["ArrowDown", "↓"], ["ArrowRight", "→"]]
  ];

  const ALL_KEYS = KEY_ROWS.flatMap((row, rowIdx) => {
    const totalUnits = row.reduce((sum, item) => sum + (item[2] ?? 1), 0);
    const unitW = (KB.width - 12) / totalUnits;
    let cursor = 0;
    return row.flatMap(([code, label, units = 1]) => {
      const w = units * unitW - 2;
      const def = {
        code,
        label,
        x: KB.x + KB.width - 6 - cursor * unitW - w,
        y: KB.y + KB.height - 6 - rowIdx * 12 - 10,
        width: w,
        height: 10,
        side: cursor + units / 2 < totalUnits / 2 ? "right" : "left"
      };
      cursor += units;
      if (code === "ArrowDown") {
        return [
          { ...def, height: 4.5 },
          { ...def, code: "ArrowUp", label: "↑", y: def.y + 5.5, height: 4.5 }
        ];
      }
      return [def];
    });
  });

  const KEY_BY_CODE = new Map(ALL_KEYS.map((k) => [k.code, k]));

  function bubbleLabelForCode(code) {
    if (code === "Space") return "␣";
    const mouseLabels = {
      MouseLeft: "左键",
      MouseRight: "右键",
      MouseMiddle: "中键",
      WheelUp: "↑ 滚轮",
      WheelDown: "↓ 滚轮"
    };
    return (
      mouseLabels[code] ??
      KEY_BY_CODE.get(code)?.label ??
      code.replace(/^(Key|Digit)/, "").replace(/Left|Right/g, "")
    );
  }

  function keyTargetPoint(code) {
    const k = KEY_BY_CODE.get(code);
    if (!k) return undefined;
    return {
      ...projectDeck(k.x + k.width / 2, k.y + k.height / 2, CAP_TOP_Z),
      side: k.side
    };
  }

  const BREEDS = {
    black: {
      label: "经典小黑猫",
      fur: "#19171b",
      edge: "#333036",
      iris: "#e5f672",
      whisker: "#b4aead"
    },
    siamese: {
      label: "挖煤暹罗猫",
      fur: "#eee2cf",
      edge: "#6c594a",
      iris: "#69d1ff",
      whisker: "#675044",
      point: "#3d2c22"
    },
    huangzongzi: {
      label: "橘白黄粽子",
      fur: "#d79754",
      edge: "#8c603d",
      iris: "#b7be73",
      whisker: "#fff5df",
      tabby: true,
      silver: false
    },
    shorthair: {
      label: "美短银虎斑",
      fur: "#b9beb9",
      edge: "#5e6364",
      iris: "#d8c967",
      whisker: "#f6f7f5",
      tabby: true,
      silver: true
    }
  };

  const BREED_ORDER = ["black", "siamese", "huangzongzi", "shorthair"];

  const MOUSE_HOME = { x: 96, y: 344 };
  const MOUSE_BOUNDS = { left: 73, right: 106, top: 329, bottom: 361 };
  const PAW_REST = {
    left: { x: 209, y: 322 },
    right: { x: 250, y: 323 }
  };

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }
  function smoothstep(t) {
    return t * t * (3 - 2 * t);
  }
  function clamp01Range(val, a, b) {
    return Math.max(0, Math.min(1, (val - a) / (b - a)));
  }
  function mixPt2(a, b, t) {
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  }
  function subdivideQuad(a, b, c, d) {
    const ab = mixPt2(a, b, 0.5);
    const bc = mixPt2(b, c, 0.5);
    const cd = mixPt2(c, d, 0.5);
    const abc = mixPt2(ab, bc, 0.5);
    const bcd = mixPt2(bc, cd, 0.5);
    return [ab, abc, mixPt2(abc, bcd, 0.5), bcd, cd, d];
  }

  function hexMix(c1, c2, t) {
    if (t <= 0 || c1 === c2) return c1;
    if (t >= 1) return c2;
    const n1 = parseInt(c1.slice(1), 16);
    const n2 = parseInt(c2.slice(1), 16);
    const ch = (shift) => {
      const a = (n1 >> shift) & 255;
      const b = (n2 >> shift) & 255;
      return Math.round(a + (b - a) * t);
    };
    return `rgb(${ch(16)},${ch(8)},${ch(0)})`;
  }

  function headBasis(yaw, pitch) {
    const cy = Math.cos(yaw);
    const sy = Math.sin(yaw);
    const cp = Math.cos(pitch);
    const sp = Math.sin(pitch);
    const r = Math.hypot(cy, 0.76 * sy);
    const project = (x, y, z) => [x * cy + z * sy, y * cp + (z * cy - x * sy) * sp];
    const contour = (x, y, z) => [x * r + z * sy, y * cp + (z * cy - x * sy) * sp];
    return { project, contour, crownControl: contour(0, -38, -9), cy, cp };
  }

  function headRoll(pose) {
    return pose.turn * 0.008 + pose.headLean.x * 0.00035;
  }

  function buildEar(project, side, twitch) {
    const pt = (ax, ay, az = 0) => {
      const u = Math.max(0, (-36 - ay) / 23) * twitch;
      const d = -5 - (ax - 34) * 0.5 + (ay + 28) * 0.22 + az;
      return project(side * ax + 0.38 * u, ay, d - side * 0.4 * u);
    };
    const outer = pt(50, -14);
    const temple = project(side * 57, 2, -3);
    const outerBase = [outer[0] + (outer[0] - temple[0]) * 0.75, outer[1] + (outer[1] - temple[1]) * 0.75];
    return {
      side,
      point: pt,
      outer,
      outerBase,
      outerTip: pt(47, -57),
      temple,
      inner: pt(16, -34),
      innerBase: pt(20, -36),
      innerTip: pt(36, -61),
      tip: pt(41, -59)
    };
  }

  function trunkInfluence(y) {
    const e = Math.max(0, Math.min(1, (312 - y) / 186));
    return e * (0.8 + 0.2 * e);
  }

  function headOffset(pose) {
    return {
      x: pose.headLean.x + pose.turn * 1.35,
      y: pose.headLean.y + pose.gaze.y * 0.65
    };
  }

  function shoulderAnchor(pose, side) {
    const inf = trunkInfluence(211);
    return {
      x: (side === "left" ? 200 : 265) + pose.trunk.x * inf,
      y: 211 + (pose.trunk.y + pose.breath) * inf
    };
  }

  function readyPawTarget(pose, side) {
    const rest = PAW_REST[side];
    const r = pose.keyboardReady;
    return {
      x: rest.x + r * ((side === "left" ? 5 : 1) + pose.trunk.x * trunkInfluence(257)),
      y: rest.y + r * (258 + pose.trunk.y * trunkInfluence(257) - rest.y)
    };
  }

  function stageToLogical(pt, scale) {
    const s = scale * BASE_SCALE;
    return {
      x: (pt.x - STAGE.anchorX) / s + 230,
      y: (pt.y - STAGE.anchorY) / s + 405
    };
  }

  function stepSpring2D(state, target, dt, snap, fast = false) {
    if (snap) {
      state.x = target.x;
      state.y = target.y;
      state.vx = state.vy = 0;
      return;
    }
    const steps = Math.max(1, Math.ceil(dt / (1 / 120)));
    const h = Math.min(dt / steps, 1 / 120);
    const k = fast ? 3600 : 330;
    const damp = fast ? 112 : 29;
    for (let i = 0; i < steps; i++) {
      state.vx += ((target.x - state.x) * k - state.vx * damp) * h;
      state.vy += ((target.y - state.y) * k - state.vy * damp) * h;
      state.x += state.vx * h;
      state.y += state.vy * h;
    }
  }

  function roundedPolygon(pts, radius) {
    const path = new Path2D();
    const mid = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
    const start = mid(pts[pts.length - 1], pts[0]);
    path.moveTo(start.x, start.y);
    for (let i = 0; i < pts.length; i++) {
      const cur = pts[i];
      const nextMid = mid(cur, pts[(i + 1) % pts.length]);
      path.arcTo(cur.x, cur.y, nextMid.x, nextMid.y, radius);
      path.lineTo(nextMid.x, nextMid.y);
    }
    path.closePath();
    return path;
  }

  function buildKeycapMesh(k, pressed) {
    const zTop = CAP_TOP_Z - (pressed ? 1.9 : 0);
    const sx = 1.15;
    const sy = Math.min(1.05, k.height * 0.12);
    const baseQ = deckQuad(k.x, k.y, k.width, k.height, KB_BASE_Z);
    const topQ = deckQuad(k.x + sx, k.y + sy, k.width - 2 * sx, k.height - 2 * sy, zTop);
    const cx = k.x + k.width / 2;
    const cy = k.y + k.height / 2;
    const c = projectDeck(cx, cy, zTop);
    const ux = projectDeck(cx + 1, cy, zTop);
    const uy = projectDeck(cx, cy + 1, zTop);
    return {
      skirt: roundedPolygon([topQ[0], topQ[1], baseQ[1], baseQ[2], baseQ[3], baseQ[0]], 0.75),
      front: roundedPolygon([topQ[3], topQ[2], baseQ[2], baseQ[3]], 0.55),
      top: roundedPolygon(topQ, 0.85),
      center: c,
      xx: c.x - ux.x,
      xy: c.y - ux.y,
      yx: c.x - uy.x,
      yy: c.y - uy.y
    };
  }

  let KEYBOARD_CACHE = null;
  function getKeyboardMesh() {
    if (KEYBOARD_CACHE) return KEYBOARD_CACHE;
    const topA = deckQuad(KB.x, KB.y, KB.width, KB.height, KB_BASE_Z);
    const botL = deckQuad(KB.x, KB.y, KB.width, KB.height, 0);
    KEYBOARD_CACHE = {
      board: {
        edge: roundedPolygon([topA[0], topA[1], topA[2], botL[2], botL[3], topA[3]], 3.1),
        top: roundedPolygon(topA, 3.1)
      },
      plate: roundedPolygon(deckQuad(KB.x + 5, KB.y + 5, KB.width - 10, KB.height - 10, KB_BASE_Z), 2),
      caps: [...ALL_KEYS]
        .sort((a, b) => a.y - b.y)
        .map((key) => ({
          key,
          up: buildKeycapMesh(key, false),
          down: buildKeycapMesh(key, true)
        }))
    };
    return KEYBOARD_CACHE;
  }

  function drawKeyboard(ctx, pose, settings, nowMs) {
    const { board, plate, caps } = getKeyboardMesh();
    ctx.fillStyle = "#232226";
    ctx.fill(board.edge);
    ctx.fillStyle = "#39373b";
    ctx.fill(board.top);
    ctx.fillStyle = "#aba69d";
    ctx.fill(plate);

    if (settings.rgbGlow) {
      ctx.save();
      ctx.clip(plate);
      const phase = settings.reducedMotion ? 0.35 : (nowMs * 0.00042) % 1;
      const gx0 = 110 + Math.sin(phase * Math.PI * 2) * 55;
      const grad = ctx.createLinearGradient(gx0, 325, gx0 + 260, 398);
      grad.addColorStop(0, "rgba(255, 128, 164, 0.52)");
      grad.addColorStop(0.35, "rgba(255, 198, 138, 0.42)");
      grad.addColorStop(0.68, "rgba(130, 224, 248, 0.48)");
      grad.addColorStop(1, "rgba(196, 236, 116, 0.5)");
      ctx.fillStyle = grad;
      ctx.fillRect(90, 315, 340, 110);
      ctx.restore();
    }

    for (const { key, up, down } of caps) {
      const isDown = pose.pressed.has(key.code) || nowMs - (pose.flashes.get(key.code) ?? 0) < 135;
      const mesh = isDown ? down : up;
      const isAccent = key.code === "Escape" || key.code === "Enter";

      if (isDown && settings.rgbGlow) {
        ctx.save();
        const glow = ctx.createRadialGradient(mesh.center.x, mesh.center.y + 2, 1, mesh.center.x, mesh.center.y + 2, 22);
        glow.addColorStop(0, "rgba(205, 238, 92, 0.65)");
        glow.addColorStop(1, "rgba(205, 238, 92, 0)");
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(mesh.center.x, mesh.center.y + 2, 22, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }

      let topCol = isDown ? "#d8ea82" : isAccent ? "#f6bf60" : "#faf8f1";
      let skirtCol = isDown ? "#b6c36b" : isAccent ? "#d8a358" : "#d3cdbf";
      let frontCol = isDown ? "#98a454" : isAccent ? "#b88948" : "#b7b0a4";

      if (settings.rgbGlow && !isDown && !isAccent) {
        const wave = Math.sin((key.x - KB.x) * 0.032 - (settings.reducedMotion ? 1.1 : nowMs * 0.0032) + (key.y - KB.y) * 0.02);
        if (wave > 0.25) {
          const amt = (wave - 0.25) * 0.48;
          topCol = hexMix("#faf8f1", "#ffc2d4", amt);
          skirtCol = hexMix("#d3cdbf", "#eab0c2", amt * 0.8);
        } else if (wave < -0.35) {
          const amt = (-wave - 0.35) * 0.38;
          topCol = hexMix("#faf8f1", "#d6f3ff", amt);
        }
      }

      ctx.fillStyle = skirtCol;
      ctx.fill(mesh.skirt);
      ctx.fillStyle = frontCol;
      ctx.fill(mesh.front);
      ctx.fillStyle = topCol;
      ctx.fill(mesh.top);

      if (settings.showKeyLabels && key.label) {
        ctx.save();
        ctx.transform(mesh.xx, mesh.xy, mesh.yx, mesh.yy, mesh.center.x, mesh.center.y);
        ctx.fillStyle = "#554f4a";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.font = `600 ${key.height < 6 ? "4px" : key.label.length > 2 ? "4.6px" : "6px"} -apple-system, BlinkMacSystemFont, sans-serif`;
        ctx.fillText(key.label, 0, 0);
        ctx.restore();
      }
    }
  }

  function drawMouse(ctx, pose, nowMs) {
    const base = unprojectDeck({ x: pose.mouse.x, y: pose.mouse.y + 7 });
    const pt = (dx, dy, z = 0) => projectDeck(base.x + dx, base.y + dy, z);
    const bz = (p, c1, c2, end) => p.bezierCurveTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y);
    const shell = new Path2D();
    const nose = pt(0, -23, 10);
    const tail = pt(0, 27, 3);
    shell.moveTo(nose.x, nose.y);
    bz(shell, pt(12, -23, 11), pt(21, -14, 11), pt(21, -1, 8));
    bz(shell, pt(21, 6, 7), pt(19, 13, 5), pt(17, 17, 4));
    bz(shell, pt(14, 24, 3), pt(7, 27, 3), tail);
    bz(shell, pt(-7, 27, 3), pt(-14, 24, 3), pt(-17, 17, 4));
    bz(shell, pt(-19, 13, 5), pt(-21, 6, 7), pt(-21, -1, 8));
    bz(shell, pt(-21, -14, 11), pt(-12, -23, 11), nose);
    shell.closePath();

    ctx.save();
    ctx.translate(0, 2.7);
    ctx.fillStyle = "#a69e96";
    ctx.fill(shell);
    ctx.lineWidth = 1.1;
    ctx.strokeStyle = "#625d5b";
    ctx.stroke(shell);
    ctx.restore();

    const hi = pt(-8, -12, 12);
    const grad = ctx.createRadialGradient(hi.x, hi.y, 1, hi.x, hi.y, tail.y - nose.y);
    grad.addColorStop(0, "#fffdf6");
    grad.addColorStop(0.55, "#f5f1e8");
    grad.addColorStop(1, "#dad4ca");
    ctx.fillStyle = grad;
    ctx.fill(shell);

    const btnActive = (code) => pose.buttons.has(code) || nowMs - (pose.flashes.get(code) ?? 0) < 135;
    const mid = pt(0, 0, 10);
    ctx.save();
    ctx.clip(shell);
    for (const [code, dir] of [["MouseLeft", 1], ["MouseRight", -1]]) {
      const seam = new Path2D();
      seam.moveTo(mid.x, mid.y);
      bz(seam, pt(dir * 6, 0, 10), pt(dir * 13, 3, 8), pt(dir * 24, 4, 6));
      const area = new Path2D(seam);
      const w = pt(dir * 26, 32);
      const p0 = pt(0, 32);
      area.lineTo(w.x, w.y);
      area.lineTo(p0.x, p0.y);
      area.lineTo(tail.x, tail.y);
      bz(area, pt(0, 20, 5), pt(0, 8, 10), mid);
      area.closePath();
      ctx.fillStyle = btnActive(code) ? "#d8e58e" : "rgba(255,253,247,0.38)";
      ctx.fill(area);
      ctx.strokeStyle = "#cec7bb";
      ctx.lineWidth = 0.8;
      ctx.stroke(seam);
    }
    const split = new Path2D();
    split.moveTo(mid.x, mid.y);
    bz(split, pt(0, 8, 10), pt(0, 20, 5), tail);
    ctx.strokeStyle = "#b6aea3";
    ctx.lineWidth = 1.05;
    ctx.stroke(split);

    const w1 = pt(0, 15, 7.5);
    const w2 = pt(0, 18, 6.5);
    const sc = pt(1, 15, 7.5).x - w1.x;
    ctx.translate(w1.x, w1.y);
    ctx.rotate(Math.atan2(w1.x - w2.x, w2.y - w1.y));
    ctx.scale(sc, sc);
    ctx.beginPath();
    ctx.roundRect(-3, -5.2, 6, 10.4, 3);
    ctx.fillStyle = "#756b60";
    ctx.fill();
    ctx.beginPath();
    ctx.roundRect(-2.05, -4.45, 4.1, 8.4, 2.05);
    ctx.fillStyle = ["MouseMiddle", "WheelUp", "WheelDown"].some(btnActive) ? "#b58a3d" : "#e0b56b";
    ctx.fill();
    ctx.restore();
    ctx.strokeStyle = "#7d766e";
    ctx.lineWidth = 0.95;
    ctx.stroke(shell);
  }

  function tabbyColors(pal) {
    if (pal.silver) {
      return {
        bib: "#f6f7f5",
        bibShade: "#dfe2de",
        furDark: "#949a96",
        stripe: "#4e5355",
        stripeDark: "#3c4042",
        mid: "#686e70",
        tailTip: "#dfe3df",
        earInner: "#dfadb5",
        nose: "#b97782"
      };
    }
    return {
      bib: "#fff4df",
      bibShade: "#eddec6",
      furDark: "#be8046",
      stripe: "#aa632f",
      stripeDark: "#a66d39",
      mid: "#bf8046",
      tailTip: "#efc394",
      earInner: "#e9ac83",
      nose: "#af6d57"
    };
  }

  function tabbyArmGradient(ctx, p0, p1, isRight, farAmt = 0, pal = BREEDS.huangzongzi) {
    const tc = tabbyColors(pal);
    const grad = ctx.createLinearGradient(...p0, ...p1);
    const baseCol = hexMix(pal.fur, tc.furDark, farAmt);
    const stripeCol = hexMix(tc.mid, tc.stripeDark, farAmt);
    const cuffStop = isRight ? 0.71 : 0.8;
    for (const [stop, col] of [
      [0, baseCol],
      [0.31, baseCol],
      [0.33, stripeCol],
      [0.38, stripeCol],
      [0.4, baseCol],
      [0.52, baseCol],
      [0.54, stripeCol],
      [0.58, stripeCol],
      [0.6, baseCol],
      [cuffStop, baseCol],
      [cuffStop + 0.018, hexMix(tc.bib, tc.bibShade, farAmt)]
    ]) {
      grad.addColorStop(stop, col);
    }
    return grad;
  }

  function drawTabbyTailRings(ctx, p0, p1, p2, p3, width, pal) {
    const tc = tabbyColors(pal);
    const evalCubic = (t) => {
      const u = 1 - t;
      return [0, 1].map((idx) => u * u * u * p0[idx] + 3 * u * u * t * p1[idx] + 3 * u * t * t * p2[idx] + t * t * t * p3[idx]);
    };
    ctx.save();
    ctx.lineWidth = width;
    ctx.lineCap = "butt";
    for (const [t0, t1, col] of [
      [0.08, 0.24, tc.stripe],
      [0.46, 0.64, tc.stripe],
      [0.82, 1, tc.tailTip]
    ]) {
      ctx.beginPath();
      ctx.moveTo(...evalCubic(t0));
      for (let i = 1; i <= 8; i++) {
        ctx.lineTo(...evalCubic(t0 + ((t1 - t0) * i) / 8));
      }
      ctx.strokeStyle = col;
      ctx.stroke();
    }
    ctx.fillStyle = tc.tailTip;
    ctx.beginPath();
    ctx.arc(...p3, width / 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function drawTabbyTorsoBib(ctx, walkBlend, mapPt, pal) {
    const tc = tabbyColors(pal);
    const pt = (x0, y0, x1, y1) => mapPt(x0 + (x1 - x0) * walkBlend, y0 + (y1 - y0) * walkBlend);
    ctx.fillStyle = tc.bib;
    ctx.beginPath();
    ctx.moveTo(...pt(-46, -190, 64, -141));
    ctx.bezierCurveTo(...pt(-32, -155, 67, -122), ...pt(-16, -145, 62, -107), ...pt(-13, -109, 60, -98));
    ctx.bezierCurveTo(...pt(-12, -41, 58, -92), ...pt(-26, -18, 57, -83), ...pt(-38, 3, 58, -75));
    ctx.lineTo(...pt(37, 3, 80, -73));
    ctx.lineTo(...pt(13, -109, 97, -79));
    ctx.quadraticCurveTo(...pt(16, -144, 106, -98), ...pt(48, -190, 86, -143));
    ctx.closePath();
    ctx.fill();

    ctx.save();
    ctx.rect(-2048, -2048, 4096, 4096);
    ctx.clip("evenodd");
    ctx.fillStyle = tc.mid;
    for (const side of [-1, 1]) {
      for (let i = 0; i < 3; i++) {
        const y0 = -130 + 23 * i;
        const x1 = -65 + 27 * i + (side + 1) * 7;
        ctx.beginPath();
        ctx.moveTo(...pt(side * 72, y0, x1, -192));
        ctx.quadraticCurveTo(...pt(side * 53, y0 + 15, x1 - 6, -148), ...pt(side * 38, y0 + 12, x1 + 7, -124 + (i % 2) * 11));
        ctx.quadraticCurveTo(...pt(side * 55, y0 + 24, x1 + 10, -152), ...pt(side * 73, y0 + 9, x1 + 13, -192));
        ctx.fill();
      }
    }
    ctx.restore();
  }

  function drawTabbyHeadMarkings(ctx, map3D, pal) {
    const tc = tabbyColors(pal);
    ctx.fillStyle = tc.bib;
    ctx.beginPath();
    ctx.moveTo(...map3D(-52, 42, 3));
    ctx.bezierCurveTo(...map3D(-35, 36, 12), ...map3D(-15, 37, 24), ...map3D(0, 31, 28));
    ctx.bezierCurveTo(...map3D(14, 37, 24), ...map3D(36, 36, 12), ...map3D(52, 42, 3));
    ctx.lineTo(...map3D(65, 73, 0));
    ctx.lineTo(...map3D(-65, 73, 0));
    ctx.fill();

    ctx.fillStyle = tc.stripe;
    for (const nx of [-15, -5, 5, 15]) {
      const inner = Math.abs(nx) < 10;
      ctx.beginPath();
      ctx.moveTo(...map3D(nx, -41, 2));
      ctx.quadraticCurveTo(...map3D(nx - 5, -24, 16), ...map3D(nx * 0.85, inner ? -11 : -18, 21));
      ctx.quadraticCurveTo(...map3D(nx + 4, -23, 16), ...map3D(nx + 3, -41, 2));
      ctx.fill();
    }
    for (const side of [-1, 1]) {
      for (const sy of [8, 18]) {
        ctx.beginPath();
        ctx.moveTo(...map3D(side * 57, sy - 8, 0));
        ctx.quadraticCurveTo(...map3D(side * 44, sy + 3, 10), ...map3D(side * 32, sy + 4, 21));
        ctx.quadraticCurveTo(...map3D(side * 42, sy + 10, 12), ...map3D(side * 57, sy, 0));
        ctx.fill();
      }
    }
    ctx.fillStyle = tc.nose;
    ctx.beginPath();
    ctx.moveTo(...map3D(-4, 17, 26));
    ctx.quadraticCurveTo(...map3D(0, 15, 27), ...map3D(4, 17, 26));
    ctx.quadraticCurveTo(...map3D(0, 25, 28), ...map3D(-4, 17, 26));
    ctx.fill();
  }

  function fillEllipse(ctx, x, y, rx, ry, color, rot = 0) {
    ctx.beginPath();
    ctx.ellipse(x, y, rx, ry, rot, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
  }

  function drawSeatedTail(ctx, pose, pal) {
    const s = pose.tail * 0.28;
    const o = pose.tailTip * 0.38;
    ctx.beginPath();
    ctx.moveTo(282, 288);
    ctx.bezierCurveTo(304, 289, 314, 297, 325, 279 + s);
    ctx.bezierCurveTo(335, 262 + s, 343, 252 + o, 363, 252 + o);
    ctx.strokeStyle = pal.edge;
    ctx.lineWidth = 18.5;
    ctx.stroke();
    ctx.strokeStyle = pal.point ?? pal.fur;
    ctx.lineWidth = 17;
    ctx.stroke();
    if (pal.tabby) {
      drawTabbyTailRings(ctx, [325, 279 + s], [335, 262 + s], [343, 252 + o], [363, 252 + o], 17, pal);
    }
  }

  function buildFootDef(start, c1, c2, toe, c3, end, marking) {
    const curves = [...subdivideQuad(start, c1, c2, toe), mixPt2(toe, c3, 2 / 3), mixPt2(end, c3, 2 / 3), end];
    return { start, toe, end, curves, marking };
  }

  const HIND_FEET = {
    left: buildFootDef([175, 314], [169, 325], [178, 333], [188, 330], [195, 329], [194, 322], [183, 325]),
    right: buildFootDef([265, 322], [264, 332], [276, 334], [283, 327], [288, 323], [284, 315], [277, 325])
  };

  function traceCubicChain(ctx, pts, mapFn) {
    for (let i = 0; i < pts.length; i += 3) {
      ctx.bezierCurveTo(...mapFn(...pts[i]), ...mapFn(...pts[i + 1]), ...mapFn(...pts[i + 2]));
    }
  }

  function drawFootMarking(ctx, pal, x, y) {
    if (pal.tabby) {
      fillEllipse(ctx, x, y, 14, 14, tabbyColors(pal).bib);
      return;
    }
    if (!pal.point) return;
    const g = ctx.createLinearGradient(0, y - 12, 0, y + 2);
    g.addColorStop(0, pal.fur);
    g.addColorStop(0.6, "#765e4c");
    g.addColorStop(1, pal.point);
    fillEllipse(ctx, x, y, 12, 10, g);
  }

  function bellySpan(mapFn) {
    return [mapFn(...HIND_FEET.left.end), mapFn(209, 326, true), mapFn(249, 326, true), mapFn(...HIND_FEET.right.start)];
  }

  function drawSeatedTorso(ctx, pose, pal, mapFn = (x, y) => [x, y]) {
    const bodyPt = (x, y) => {
      const inf = trunkInfluence(y);
      return mapFn(x + inf * pose.trunk.x, y + inf * (pose.trunk.y + pose.breath));
    };
    const ho = headOffset(pose);
    ctx.beginPath();
    ctx.moveTo(...mapFn(190 + ho.x, 148 + ho.y + pose.breath));
    ctx.bezierCurveTo(...bodyPt(185, 183), ...bodyPt(169, 216), ...bodyPt(163, 254));
    ctx.bezierCurveTo(...bodyPt(158, 277), ...bodyPt(161, 302), ...mapFn(...HIND_FEET.left.start));
    traceCubicChain(ctx, HIND_FEET.left.curves, mapFn);
    const [, b1, b2, b3] = bellySpan(mapFn);
    ctx.bezierCurveTo(...b1, ...b2, ...b3);
    traceCubicChain(ctx, HIND_FEET.right.curves, mapFn);
    ctx.bezierCurveTo(...bodyPt(304, 295), ...bodyPt(304, 260), ...bodyPt(294, 229));
    ctx.bezierCurveTo(...bodyPt(288, 209), ...bodyPt(277, 176), ...mapFn(271 + ho.x, 148 + ho.y + pose.breath));
    ctx.closePath();
    ctx.fillStyle = pal.fur;
    ctx.fill();
    ctx.strokeStyle = pal.edge;
    ctx.lineWidth = 1;
    ctx.stroke();

    if (!pal.tabby && !pal.point) {
      ctx.save();
      ctx.strokeStyle = "rgba(148, 152, 160, 0.42)";
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(...bodyPt(196, 252));
      ctx.quadraticCurveTo(...bodyPt(189, 278), ...bodyPt(184, 302));
      ctx.moveTo(...bodyPt(257, 252));
      ctx.quadraticCurveTo(...bodyPt(266, 278), ...bodyPt(274, 302));
      ctx.stroke();
      ctx.restore();
    }

    if (pal.point || pal.tabby) {
      ctx.save();
      ctx.clip();
      if (pal.tabby) {
        drawTabbyTorsoBib(ctx, 0, (ux, uy) => bodyPt(231 + ux, 330 + uy), pal);
      }
      drawFootMarking(ctx, pal, ...HIND_FEET.left.marking);
      drawFootMarking(ctx, pal, ...HIND_FEET.right.marking);
      ctx.restore();
    }
  }

  function drawCatEye(ctx, pose, side, pos, sx, sy, irisCol, tension, profile) {
    ctx.save();
    ctx.translate(...pos);
    ctx.scale(sx, sy);
    ctx.rotate((side < 0 ? 0.12 : -0.1) * (1 - profile));
    const openAmt = 1 - pose.closed;
    if (openAmt < 0.08) {
      ctx.beginPath();
      ctx.moveTo(-13, 2);
      ctx.quadraticCurveTo(0, 7.5, 13, 1);
      ctx.strokeStyle = irisCol;
      ctx.lineWidth = 1.6;
      ctx.stroke();
    } else {
      ctx.scale(1, openAmt);
      const lidY = -23 + 20 * tension;
      const lidSlope = side * (11 + 4 * profile) * tension;
      if (tension > 0) {
        ctx.beginPath();
        ctx.moveTo(-21, lidY + lidSlope);
        ctx.lineTo(21, lidY - lidSlope);
        ctx.lineTo(21, 20);
        ctx.lineTo(-21, 20);
        ctx.closePath();
        ctx.clip();
      }
      fillEllipse(ctx, 0, 0, 16.4, 14.7, irisCol);
      ctx.save();
      ctx.clip();
      fillEllipse(ctx, pose.gaze.x * 1.05, pose.gaze.y * 1.05, 5.3, 10.1, "#151518");
      if (tension > 0) {
        ctx.beginPath();
        ctx.moveTo(-21, lidY + lidSlope);
        ctx.lineTo(21, lidY - lidSlope);
        ctx.strokeStyle = "#2e2422";
        ctx.lineWidth = 3 * tension;
        ctx.stroke();
      }
      ctx.restore();
    }
    ctx.restore();
  }

  function traceEarPath(path, ear, forward) {
    const { outerBase, outerTip, outer, innerBase, innerTip, inner, tip } = ear;
    if (forward) {
      path.bezierCurveTo(...outerBase, ...outerTip, ...tip);
      path.bezierCurveTo(...innerTip, ...innerBase, ...inner);
    } else {
      path.bezierCurveTo(...innerBase, ...innerTip, ...tip);
      path.bezierCurveTo(...outerTip, ...outerBase, ...outer);
    }
  }

  function drawCatHead(ctx, pose, pal, tension = 0, profile = 0, clipBody, extras = null) {
    ctx.save();
    const ho = headOffset(pose);
    ctx.translate(231 + ho.x, 126 + ho.y + pose.breath);
    ctx.rotate(headRoll(pose));

    const { project, contour, crownControl, cy, cp } = headBasis(pose.headYaw, pose.headPitch);
    const profMix = (pt, px, py) => (profile === 0 ? pt : [pt[0] + (px - pt[0]) * profile, pt[1] + (py - pt[1]) * profile]);
    const leftEar = buildEar(project, -1, pose.earLeft);
    const rightEar = buildEar(project, 1, pose.earRight);

    if (profile > 0) {
      leftEar.temple = profMix(leftEar.temple, -46, 9);
      leftEar.outer = profMix(leftEar.outer, -35, -7);
      leftEar.outerBase = profMix(leftEar.outerBase, -37, -17);
      leftEar.outerTip = profMix(leftEar.outerTip, -40, -51);
      leftEar.tip = profMix(leftEar.tip, -34, -55);
      leftEar.innerTip = profMix(leftEar.innerTip, -29, -59);
      leftEar.innerBase = profMix(leftEar.innerBase, -10, -43);
      leftEar.inner = profMix(leftEar.inner, 1, -32);

      rightEar.inner = profMix(rightEar.inner, -7, -42);
      rightEar.innerBase = profMix(rightEar.innerBase, -4, -52);
      rightEar.innerTip = profMix(rightEar.innerTip, 1, -66);
      rightEar.tip = profMix(rightEar.tip, 9, -62);
      rightEar.outerTip = profMix(rightEar.outerTip, 15, -60);
      rightEar.outerBase = profMix(rightEar.outerBase, 27, -42);
      rightEar.outer = profMix(rightEar.outer, 30, -32);
      rightEar.temple = profMix(rightEar.temple, 44, -22);
    }

    const headSilhouette = new Path2D();
    const jawLeft = profMix(contour(-49, 42, 5), -34, 47);
    headSilhouette.moveTo(...jawLeft);
    headSilhouette.bezierCurveTo(...profMix(contour(-62, 26, 0), -52, 37), ...leftEar.temple, ...leftEar.outer);
    ctx.strokeStyle = pal.edge;

    const topCrown = new Path2D();
    topCrown.moveTo(...leftEar.outer);
    traceEarPath(topCrown, leftEar, true);
    topCrown.quadraticCurveTo(...profMix(crownControl, -2, -38), ...rightEar.inner);
    traceEarPath(topCrown, rightEar, false);
    const jawRight = profMix(contour(49, 40, 5), 39, 24);
    const cheekRight = profMix(contour(61, 23, 0), 46, -4);
    topCrown.bezierCurveTo(...rightEar.temple, ...cheekRight, ...jawRight);

    traceEarPath(headSilhouette, leftEar, true);
    headSilhouette.quadraticCurveTo(...profMix(crownControl, -2, -38), ...rightEar.inner);
    traceEarPath(headSilhouette, rightEar, false);
    headSilhouette.bezierCurveTo(...rightEar.temple, ...cheekRight, ...jawRight);

    if (profile < 1) {
      ctx.save();
      ctx.globalAlpha *= 1 - profile;
      ctx.lineWidth = 0.85;
      ctx.stroke(headSilhouette);
      ctx.restore();
    }

    const chinR = profMix(contour(36, 56, 12), 33, 48);
    const chinL = profMix(contour(-34, 58, 12), -13, 51);
    headSilhouette.bezierCurveTo(...chinR, ...chinL, ...jawLeft);
    headSilhouette.closePath();
    ctx.fillStyle = pal.fur;
    ctx.fill(headSilhouette);

    if (profile > 0) {
      ctx.save();
      ctx.globalAlpha *= profile;
      if (clipBody) {
        const mask = new Path2D();
        mask.rect(-350, -350, 700, 700);
        mask.addPath(clipBody.path, ctx.getTransform().inverse().multiply(clipBody.transform));
        ctx.clip(mask, "evenodd");
      }
      const chinStroke = new Path2D();
      chinStroke.moveTo(...jawRight);
      chinStroke.bezierCurveTo(...chinR, ...chinL, ...jawLeft);
      ctx.lineWidth = 1.9;
      ctx.stroke(chinStroke);
      ctx.restore();

      ctx.save();
      ctx.globalAlpha *= profile;
      ctx.lineWidth = 1.9;
      ctx.stroke(topCrown);
      ctx.restore();
    }

    const faceY = pose.gaze.y * 0.55 + 6 * pose.keyboardReady;
    const sinYaw = Math.sin(pose.headYaw);

    if (pal.point) {
      ctx.save();
      ctx.clip(headSilhouette);
      ctx.save();
      ctx.translate(...profMix(project(0, faceY + 6, 17), 31, 18));
      ctx.scale(54 * cy + (47 - 54 * cy) * profile, 38 * cp);
      const rg = ctx.createRadialGradient(0, 0, 0, 0, 0, 1);
      rg.addColorStop(0, pal.point);
      rg.addColorStop(0.48, "#453126");
      rg.addColorStop(0.72, "#846b58");
      rg.addColorStop(1, "rgba(238,226,207,0)");
      fillEllipse(ctx, 0, 0, 1, 1, rg);
      ctx.restore();

      const [nx, ny] = profMix(project(0, faceY + 14, 24), 38, 26);
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(nx - 3.1 * cy, ny);
      ctx.quadraticCurveTo(nx, ny - 2, nx + 3.1 * cy, ny);
      ctx.quadraticCurveTo(nx, ny + 5, nx - 3.1 * cy, ny);
      ctx.fillStyle = "#f6e9d8";
      ctx.fill();
      ctx.restore();

      const earPts = new Path2D();
      for (const ear of [leftEar, rightEar]) {
        if (profile > 0) {
          earPts.moveTo(...ear.outer);
          traceEarPath(earPts, ear, true);
          const isLeft = ear.side < 0;
          earPts.bezierCurveTo(
            ...profMix(ear.point(24, -33), isLeft ? -25 : 0, isLeft ? -40 : -42),
            ...profMix(ear.point(40, -25), isLeft ? -43 : 13, isLeft ? -25 : -40),
            ...ear.outer
          );
          earPts.closePath();
          continue;
        }
        const turnLift = Math.max(0, ear.side * sinYaw) * (9 - 12 * pose.headPitch);
        earPts.moveTo(...ear.tip);
        earPts.bezierCurveTo(...ear.innerTip, ...ear.innerBase, ...ear.inner);
        earPts.bezierCurveTo(...ear.point(24, -33), ...ear.point(40, -25 - turnLift), ...ear.point(50, -14 - turnLift));
        earPts.lineTo(...ear.point(74, -10 - turnLift));
        earPts.lineTo(...ear.point(74, -76));
        earPts.lineTo(...ear.point(41, -76));
        earPts.closePath();
      }
      ctx.fillStyle = pal.point;
      ctx.fill(earPts);
      ctx.restore();
    }

    if (pal.tabby) {
      const tc = tabbyColors(pal);
      ctx.save();
      ctx.clip(headSilhouette);
      drawTabbyHeadMarkings(ctx, (vx, vy, vz) => profMix(project(vx, vy, vz), 17 + vx * 0.65 + vz * 0.45, vy * 0.91 + 7), pal);
      for (const ear of [leftEar, rightEar]) {
        const sub = (p) => mixPt2(ear.tip, p, 0.7);
        const bo = sub(ear.outer);
        const bi = sub(ear.inner);
        ctx.beginPath();
        ctx.moveTo(...mixPt2(ear.tip, bo, 0.2));
        ctx.lineTo(...bo);
        ctx.lineTo(...bi);
        ctx.fillStyle = tc.earInner;
        ctx.fill();
      }
      ctx.restore();
    }

    const whiskL = new Path2D();
    const whiskR = new Path2D();
    const muzzle = profMix(project(0, faceY + 20, 26), 26, 38);
    const mScaleX = tension * (cy + (1.12 - cy) * profile);
    const mScaleY = tension * cp;
    const mapMuzzle = (vx, vy) => [vx * (1 + (vx < 0 ? 0.07 : -0.46) * profile), vy * (vx > 0 ? 1 - 0.18 * profile : 1) - 0.14 * vx * profile];
    const tFast = Math.min(1, tension * 8);
    const tSmooth = tFast * tFast * (3 - 2 * tFast);
    const eyeLX = 14;
    const eyeRX = 36;
    const eyeBaseY = 8 + 8 * tension;
    const tfm = tension > 0 && profile > 0 ? ctx.getTransform() : undefined;
    const slopeComp = tfm ? (tension * (eyeRX - eyeLX) * tfm.b) / tfm.d : 0;

    for (const side of [-1, 1]) {
      const yawShrink = Math.max(0, side * sinYaw);
      const isLeft = side < 0;
      const eyePos = profMix(project(side * 23 + pose.turn * 0.35, faceY, 16 - 24 * yawShrink), isLeft ? eyeLX : eyeRX, isLeft ? eyeBaseY : eyeBaseY - slopeComp);
      const baseSX = (Math.cos(pose.headYaw + side * 0.29) / Math.cos(0.29)) * (1 - 0.12 * yawShrink);
      const profSX = isLeft ? 1.02 + 0.1 * tension : 0.32;
      drawCatEye(ctx, pose, side, eyePos, baseSX + (profSX - baseSX) * profile, cp, pal.iris, tension, profile);
      if (!isLeft && profile === 1) continue;

      const wPath = isLeft ? whiskL : whiskR;
      for (let idx = 0; idx < 3; idx++) {
        const wy = 25 + idx * 5 + 6 * pose.keyboardReady;
        const dy = -0.6 + idx * 3.4;
        const p0 = profMix(project(side * (29 + idx * 0.5), wy, 31), isLeft ? 0 : 38, 26 + idx * 5);
        const p1 = profMix(project(side * 38, wy + dy * 0.5 - 0.45, 40), isLeft ? -11 : 38, 26 + idx * 5);
        const p2 = profMix(project(side * (idx === 1 ? 48 : 46.5), wy + dy, 50), isLeft ? -24 : 38, isLeft ? 22 + idx * 8 : 26 + idx * 5);
        if (tension > 0) {
          const [mx, my] = mapMuzzle(side * (idx === 1 ? 9 : 7), idx * 2.3 - 2);
          const ox = muzzle[0] + mx * mScaleX;
          const oy = muzzle[1] + my * mScaleY;
          const span = (idx === 1 ? 34 : 31) * (isLeft ? 1 - 0.15 * profile : 1 - 0.78 * profile);
          const flare = (idx - 1) * 7;
          wPath.moveTo(...mixPt2(p0, [ox, oy], tSmooth));
          wPath.quadraticCurveTo(...mixPt2(p1, [ox + side * span * 0.5, oy + flare * 0.35 - 1], tension), ...mixPt2(p2, [ox + side * span, oy + flare], tension));
        } else {
          wPath.moveTo(...p0);
          wPath.quadraticCurveTo(...p1, ...p2);
        }
      }
    }

    if (tension > 0) {
      ctx.save();
      ctx.translate(...muzzle);
      ctx.scale(mScaleX, mScaleY);
      ctx.beginPath();
      ctx.moveTo(...mapMuzzle(-14, -2));
      ctx.quadraticCurveTo(...mapMuzzle(-10, -9), ...mapMuzzle(0, -4));
      ctx.quadraticCurveTo(...mapMuzzle(11, -9), ...mapMuzzle(14, -1));
      ctx.bezierCurveTo(...mapMuzzle(15, 8), ...mapMuzzle(6, 11), ...mapMuzzle(0, 4));
      ctx.bezierCurveTo(...mapMuzzle(-7, 12), ...mapMuzzle(-17, 8), ...mapMuzzle(-14, -2));
      ctx.fillStyle = pal.point ? "#eedcca" : "#ded4c4";
      ctx.fill();
      ctx.strokeStyle = pal.edge;
      ctx.lineWidth = 1.8;
      ctx.stroke();
      ctx.restore();
    }

    ctx.lineWidth = 1.5;
    for (const [wPath, alpha] of [
      [whiskR, 1 - profile * profile],
      [whiskL, 1]
    ]) {
      if (alpha !== 0) {
        ctx.save();
        ctx.globalAlpha *= alpha;
        ctx.strokeStyle = pal.tabby ? "#f2e4cd" : "#7c777e";
        ctx.stroke(wPath);
        ctx.clip(headSilhouette);
        ctx.strokeStyle = pal.whisker;
        ctx.stroke(wPath);
        ctx.restore();
      }
    }

    if (extras?.headphones && profile === 0) {
      ctx.save();
      ctx.beginPath();
      ctx.arc(0, -4, 55, Math.PI * 1.07, Math.PI * 1.93);
      ctx.strokeStyle = "#fff8ee";
      ctx.lineWidth = 6.5;
      ctx.stroke();
      ctx.strokeStyle = "#f26b7a";
      ctx.lineWidth = 3;
      ctx.stroke();
      for (const side of [-1, 1]) {
        const ex = side * 53;
        const ey = 7;
        ctx.save();
        ctx.translate(ex, ey);
        ctx.rotate(side * 0.14);
        fillEllipse(ctx, 0, 0, 9.5, 15.5, "#f26b7a");
        fillEllipse(ctx, -side * 2, 0, 5.5, 11.5, "#fff8ee");
        ctx.restore();
      }
      ctx.restore();
    }

    if (extras?.anger > 0.04 && profile === 0) {
      const a = Math.min(1, extras.anger);
      const pulse = 1 + Math.sin(pose.time * 16) * 0.09;
      ctx.save();
      ctx.translate(28, -22);
      ctx.scale(a * pulse, a * pulse);
      ctx.strokeStyle = "#ef4444";
      ctx.lineWidth = 3.1;
      ctx.lineCap = "round";
      for (let q = 0; q < 4; q++) {
        ctx.save();
        ctx.rotate((q * Math.PI) / 2 + 0.12);
        ctx.beginPath();
        ctx.moveTo(3.2, -9.5);
        ctx.quadraticCurveTo(3.4, -3.4, 9.5, -3.2);
        ctx.stroke();
        ctx.restore();
      }
      ctx.restore();
    }

    ctx.restore();
  }

  function buildArmGeometry(start, ctrl, end, grip = 0, spread = 0) {
    const d1 = Math.hypot(ctrl.x - start.x, ctrl.y - start.y) || 1;
    const d2 = Math.hypot(end.x - ctrl.x, end.y - ctrl.y) || 1;
    const u1 = { x: (ctrl.x - start.x) / d1, y: (ctrl.y - start.y) / d1 };
    const u2 = { x: (end.x - ctrl.x) / d2, y: (end.y - ctrl.y) / d2 };
    const w = 10.2 - 2.4 * spread;
    const sw = 15 + 7 * grip;
    const mw = 6.5 + 1.2 * grip;
    const left = [start.x - u1.y * sw, start.y + u1.x * sw];
    const right = [start.x + u1.y * sw, start.y - u1.x * sw];
    const curveLeft = [ctrl.x - (u1.y + u2.y) * mw, ctrl.y + (u1.x + u2.x) * mw];
    const curveRight = [2 * ctrl.x - curveLeft[0], 2 * ctrl.y - curveLeft[1]];
    const wristLeft = [end.x - u2.y * w, end.y + u2.x * w];
    const wristRight = [end.x + u2.y * w, end.y - u2.x * w];
    const tipLeft = [wristLeft[0] + u2.x * 14, wristLeft[1] + u2.y * 14];
    const tipRight = [wristRight[0] + u2.x * 14, wristRight[1] + u2.y * 14];
    return { left, curveLeft, wristLeft, tipLeft, tipRight, wristRight, curveRight, right, width: w, direction: u2 };
  }

  function armContourPoints(start, ctrl, end) {
    const g = buildArmGeometry(start, ctrl, end);
    return {
      contour: [
        g.left,
        mixPt2(g.left, g.curveLeft, 2 / 3),
        mixPt2(g.wristLeft, g.curveLeft, 2 / 3),
        g.wristLeft,
        ...subdivideQuad(g.wristLeft, g.tipLeft, g.tipRight, g.wristRight),
        mixPt2(g.wristRight, g.curveRight, 2 / 3),
        mixPt2(g.right, g.curveRight, 2 / 3),
        g.right
      ],
      width: g.width
    };
  }

  function armGradient(ctx, pal, start, end, blendInfo) {
    const amt = blendInfo?.amount ?? 0;
    if (!pal.point && (!blendInfo?.far || amt === 0)) return pal.fur;
    const far = blendInfo?.far;
    const mix = (a, b) => a + (b - a) * amt;
    const g = ctx.createLinearGradient(mix(start.x, end.x), mix(start.y, blendInfo?.top ?? start.y), end.x, mix(end.y, blendInfo?.bottom ?? end.y));
    if (pal.point) {
      const h = far ? Math.max(0, (amt - 0.9) * 10) : 0;
      g.addColorStop(0, hexMix(pal.fur, "#b49a81", h));
      g.addColorStop(mix(0.22, 0.2), hexMix(pal.fur, "#b1987e", h));
      g.addColorStop(mix(0.49, 0.57), hexMix("#d4c2ac", far ? "#ac9178" : pal.fur, amt));
      g.addColorStop(mix(0.76, 0.85), hexMix("#856a55", far ? "#705945" : "#b8a18a", amt));
      g.addColorStop(mix(0.98, 1), hexMix(pal.point, far ? "#584333" : "#79614c", amt));
    } else {
      g.addColorStop(0, hexMix(pal.fur, "#211f22", amt));
      g.addColorStop(1, hexMix(pal.fur, "#171619", amt));
    }
    return g;
  }

  function paintLimb(ctx, path, start, ctrl, end, width, pal, toes = 0, blendInfo, isRight = false) {
    const amt = blendInfo?.amount ?? 0;
    const inv = 1 - amt;
    const spine = new Path2D();
    spine.moveTo(start.x, start.y);
    spine.quadraticCurveTo(ctrl.x, ctrl.y, end.x, end.y);

    const rimGrad = ctx.createLinearGradient(start.x, start.y, end.x, end.y);
    const rimRGB = pal.tabby ? (pal.silver ? "94,99,100" : "142,96,62") : pal.point ? "104,84,68" : "234,232,227";
    rimGrad.addColorStop(0.28, `rgba(${rimRGB},0)`);
    rimGrad.addColorStop(0.55, `rgba(${rimRGB},0.65)`);
    rimGrad.addColorStop(1, pal.point || pal.tabby ? pal.edge : "#eeece6");

    ctx.save();
    ctx.globalAlpha *= inv * (1 - 0.83 * toes);
    ctx.strokeStyle = rimGrad;
    ctx.lineWidth = 3.6;
    ctx.stroke(path);
    if (inv > 0) {
      ctx.lineWidth = (width * 2 + 3.6) * inv;
      ctx.stroke(spine);
    }
    ctx.restore();

    const botY = blendInfo?.bottom ?? end.y;
    const fillStyle = pal.tabby
      ? tabbyArmGradient(ctx, mixPt2([start.x, start.y], [end.x, botY - 66], amt), [end.x, end.y + (botY - end.y) * amt], isRight, blendInfo?.far ? amt : 0, pal)
      : armGradient(ctx, pal, start, end, blendInfo);

    ctx.fillStyle = fillStyle;
    ctx.fill(path);
    if (inv > 0) {
      ctx.strokeStyle = fillStyle;
      ctx.lineWidth = width * 2 * inv;
      ctx.stroke(spine);
    }
    if (blendInfo && amt > 0) {
      const eg = ctx.createLinearGradient(start.x, start.y, end.x, end.y);
      const b = Math.max(0, (amt - 0.83) / 0.17);
      eg.addColorStop(0, pal.edge + Math.round(255 * b).toString(16).padStart(2, "0"));
      eg.addColorStop(0.18 + 0.42 * inv, pal.edge);
      ctx.save();
      ctx.globalAlpha *= amt;
      ctx.strokeStyle = eg;
      ctx.lineWidth = blendInfo.far ? 1.7 : 1.9;
      ctx.stroke(path);
      ctx.restore();
    }
    if (toes > 0) {
      for (const idx of [-1, 0, 1]) {
        fillEllipse(ctx, end.x + idx * 5.4 * toes, end.y + (idx === 0 ? 5.5 : 4) * toes, toes * 4.8, toes * 5.1, pal.tabby ? tabbyColors(pal).bib : pal.point ?? pal.fur);
      }
    }
  }

  function drawForearm(ctx, start, ctrl, end, grip, pal, toes = 0, isRight = false) {
    const g = buildArmGeometry(start, ctrl, end, grip, toes);
    const p = new Path2D();
    p.moveTo(...g.left);
    p.quadraticCurveTo(...g.curveLeft, ...g.wristLeft);
    p.bezierCurveTo(...g.tipLeft, ...g.tipRight, ...g.wristRight);
    p.quadraticCurveTo(...g.curveRight, ...g.right);
    if (grip > 0) {
      const m = g.width + 2 * grip;
      const paw = new Path2D();
      paw.moveTo(-31, 8);
      paw.bezierCurveTo(-18, 8, -13, m, -5, m);
      paw.lineTo(0, m);
      paw.bezierCurveTo(14, m, 14, -m, 0, -m);
      paw.lineTo(-5, -m);
      paw.bezierCurveTo(-13, -m, -18, -8, -31, -8);
      paw.closePath();
      p.addPath(paw, { a: g.direction.x, b: g.direction.y, c: -g.direction.y, d: g.direction.x, e: end.x, f: end.y });
    }
    paintLimb(ctx, p, start, ctrl, end, g.width, pal, toes, undefined, isRight);
  }

  // =========================================================================
  // 10.58s Authentic Forehead-Butting 2-Cat Shift Handover Rig (Clack-Clack)
  // =========================================================================
  const HANDOVER_TIMING = {
    approachEnd: 1550,
    braceEnd: 2420,
    duelEnd: 5420,
    turnEnd: 6000,
    exitEnd: 7920,
    watchEnd: 8150,
    walkEnd: 9250,
    sitEnd: 10200,
    end: 10580
  };

  function computeHandoverState(fromBreed, toBreed, elapsed, scale) {
    const T = HANDOVER_TIMING;
    const pApproach = smoothstep(clamp01Range(elapsed, 0, T.approachEnd));
    const pBrace = smoothstep(clamp01Range(elapsed, T.approachEnd, T.braceEnd));
    const pTensionIn = smoothstep(clamp01Range(elapsed, T.approachEnd + 190, T.braceEnd));
    const pResRelax = smoothstep(clamp01Range(elapsed, T.duelEnd + 40, T.duelEnd + 365));
    const pTurn = smoothstep(clamp01Range(elapsed, T.duelEnd + 140, T.turnEnd));
    const pExit = clamp01Range(elapsed, T.turnEnd, T.exitEnd);
    const pVisRelax = smoothstep(clamp01Range(elapsed, T.duelEnd + 100, T.duelEnd + 680));
    const pWalkIn = smoothstep(clamp01Range(elapsed, T.watchEnd, T.walkEnd));
    const pSit = smoothstep(clamp01Range(elapsed, T.walkEnd + 280, T.sitEnd));

    const leftEdge = Math.max(-52, stageToLogical({ x: 4, y: 0 }, scale).x);
    const rightEdge = Math.min(518, stageToLogical({ x: STAGE.width - 6, y: 0 }, scale).x);
    const startX = leftEdge - 140;
    const settling = smoothstep(clamp01Range(elapsed, T.walkEnd - 80, T.walkEnd + 420));
    const padX = Math.max(0, stageToLogical({ x: 5, y: 0 }, scale).x - 4);
    const visX = lerp(lerp(lerp(startX, 54, pApproach), 115 + padX, pBrace), 231, pWalkIn);

    const duelPhase = clamp01Range(elapsed, T.braceEnd, T.duelEnd);
    const headPush = 1.55 * smoothstep(clamp01Range(duelPhase, 0, 0.16)) + 0.3 * Math.sin(duelPhase * Math.PI * 4);
    const visStride = Math.sin(Math.PI * pApproach) + 0.5 * Math.sin(Math.PI * pBrace) + Math.sin(Math.PI * pWalkIn);

    const visitor = {
      breed: toBreed,
      x: visX,
      y: lerp(324, 330, pWalkIn),
      settlingAtKeys: settling > 0,
      stand: 1 - pSit,
      heading: 1 - settling,
      look: (0.53 + pTensionIn * 0.12 + pVisRelax * 0.09 - pWalkIn * 0.21) * (1 - settling) * (1 - pSit),
      pitch: -0.035 * pVisRelax * (1 - pWalkIn),
      tension: pTensionIn * (1 - pVisRelax),
      lean: headPush * pTensionIn * (1 - pVisRelax),
      stride: visStride,
      step: ((visX - startX) / 86) * 2 * Math.PI,
      crouch: smoothstep(clamp01Range(elapsed, T.walkEnd + 130, T.walkEnd + 350)) * (1 - pSit),
      working: smoothstep(clamp01Range(elapsed, T.sitEnd, T.end))
    };

    const resBraceX = 344 + padX;
    const exitCurve = pExit < 0.16 ? (pExit * pExit) / 0.32 : pExit - 0.08;
    const exitWalk = ((rightEdge + 136 - resBraceX) * exitCurve) / 0.92;

    const resident = {
      breed: fromBreed,
      x: lerp(231, resBraceX, pBrace) + exitWalk,
      y: lerp(330, 324, pBrace),
      stand: pBrace,
      turningToExit: pTurn > 0 && pTurn < 1,
      heading: lerp(-1, 1, pTurn),
      look: lerp(-0.53 - 0.12 * pTensionIn, 0.6, pResRelax) * smoothstep(clamp01Range(elapsed, 470, T.approachEnd)),
      pitch: 0,
      tension: pTensionIn * (1 - pResRelax),
      lean: headPush * pTensionIn * (1 - pResRelax),
      stride: 0.75 * Math.sin(Math.PI * pBrace) + 0.38 * Math.sin(Math.PI * pTurn) + smoothstep(clamp01Range(pExit, 0, 0.16)),
      step: pBrace * Math.PI * 2.5 + pTurn * Math.PI + (exitWalk / 118) * 2 * Math.PI,
      crouch: Math.sin(Math.PI * pBrace) + 0.22 * Math.sin(Math.PI * pTurn),
      working: 1 - smoothstep(clamp01Range(elapsed, 540, T.approachEnd))
    };

    let duelStep = 1;
    if (elapsed < T.approachEnd) duelStep = 1;
    else if (elapsed < T.braceEnd) duelStep = 2;
    else if (elapsed < T.duelEnd) duelStep = 3;
    else duelStep = 4;

    return {
      resident: elapsed < T.exitEnd ? resident : null,
      visitor,
      leftEdge,
      rightEdge,
      duelStep,
      isHeadbuttPeak: elapsed >= T.braceEnd - 150 && elapsed < T.duelEnd
    };
  }

  const BODY_SPLINES = {
    seated: [[40, -182], [34, -207, -34, -193, -43, -166], [-52, -139, -61, -115, -68, -76], [-72, -57, -70, -36, -56, -16], [-61, -11, -60, -4, -55, -1], [-52, 3, -47, 3, -43, 0], [-40, 0, -37, -3, -37, -8], [-36, -8, -34, -7, -33, -7], [-32, -7, -30, -7, -29, -8], [-29, -8, -29, -8, -29, -7], [-29, -1, -25, 3, -19, 3], [-13, 3, -9, 0, -9, -7], [26, -15, 73, -62, 63, -101], [54, -127, 46, -157, 40, -182]],
    walking: [[51, -159], [21, -143, -1, -170, -39, -161], [-69, -156, -84, -128, -83, -100], [-82, -71, -92, -54, -90, -18], [-91, -12, -95, -2, -85, 0], [-80, 1, -73, 1, -68, 0], [-62, -1, -63, -11, -69, -15], [-67, -38, -44, -58, -25, -83], [-11, -77, 10, -73, 18, -76], [15, -56, 23, -31, 25, -13], [21, 0, 29, 2, 40, 1], [50, 2, 55, -7, 46, -15], [48, -34, 65, -65, 75, -84], [106, -96, 89, -139, 51, -159]],
    braced: [[55, -148], [27, -182, 6, -197, -22, -190], [-57, -189, -82, -160, -90, -120], [-94, -95, -90, -59, -96, -16], [-99, -11, -101, -2, -91, 0], [-84, 1, -78, 1, -73, 0], [-66, -2, -69, -13, -76, -16], [-72, -42, -54, -68, -35, -83], [-18, -84, 0, -75, 12, -68], [22, -47, 32, -27, 36, -14], [34, -2, 42, 2, 52, 0], [64, 2, 70, -10, 58, -17], [53, -32, 44, -51, 46, -67], [100, -49, 96, -115, 55, -148]]
  };

  const FRONT_TURN_SPLINE = [[26, -135], [9, -148, -9, -146, -28, -136], [-47, -126, -57, -90, -52, -61], [-50, -44, -45, -23, -44, -13], [-48, -6, -46, 0, -39, 1], [-34, 2, -29, 2, -24, 0], [-17, -3, -19, -10, -24, -13], [-25, -25, -27, -33, -25, -39], [-23, -43, -17, -46, -19, -51], [-21, -37, -23, -20, -25, -13], [-29, -5, -27, 1, -18, 1], [-11, 2, -6, 0, -7, -10], [16, -18, 44, -58, 46, -83], [45, -108, 41, -124, 26, -135]];
  const FAR_HIND_BRACED = [[-67, -156, -64, -142, -64, -122], [-62, -91, -59, -48, -59, -15], [-62, -10, -62, -1, -55, 0], [-50, 1, -42, 1, -38, 0], [-32, -2, -34, -12, -40, -15], [-41, -47, -39, -88, -34, -119]];
  const FAR_HIND_SEATED = [[22, -116, 25, -110, 26, -101], [30, -79, 34, -30, 34, -9], [32, -3, 35, 2, 41, 2], [48, 3, 54, 1, 55, -4], [56, -9, 55, -13, 53, -15], [68, -36, 73, -70, 63, -101]];
  const FORE_SEATED = [[20, -117, 20, -119, 19, -119], [15, -84, 9, -36, 9, -7], [9, -1, 13, 3, 19, 3], [25, 3, 29, 0, 29, -7], [29, -39, 46, -85, 49, -119]];

  const rel231 = ([x, y]) => [x - 231, y - 330];
  function chunkRelCurves(curves) {
    return [0, 3, 6].map((idx) => curves.slice(idx, idx + 3).flatMap(rel231));
  }
  const LAND_LEFT = [[40, -182], [28, -200, -36, -208, -41, -182], [-46, -147, -62, -114, -68, -76], [-73, -53, -70, -28, ...rel231(HIND_FEET.left.start)], ...chunkRelCurves(HIND_FEET.left.curves)];
  const LAND_CHEST = [73, -35, 73, -70, 63, -101];
  const LAND_NECK = [57, -121, 46, -154, 40, -182];
  const LAND_RIGHT = [[28, -89, 28, -82, 26, -76], [31, -56, 35, -24, ...rel231(HIND_FEET.right.start)], ...chunkRelCurves(HIND_FEET.right.curves), [57, -31, 56, -56, 48, -77]];

  const NEUTRAL_POSE = {
    mouse: { ...MOUSE_HOME },
    mouseReach: 0,
    headYaw: 0,
    headPitch: 0,
    left: { ...PAW_REST.left, vx: 0, vy: 0 },
    right: { ...PAW_REST.right, vx: 0, vy: 0 },
    trunk: { x: 0, y: 0 },
    headLean: { x: 0, y: 0 },
    keyboardReady: 0,
    gaze: { x: 0, y: 0 },
    turn: 0,
    breath: 0,
    closed: 0,
    petting: 0,
    tail: 0,
    tailTip: 0,
    earLeft: 0,
    earRight: 0,
    time: 0
  };

  function warpLandingPt(actor, x, y, isBelly = false) {
    const st = actor.stand;
    const bellyLift = isBelly ? 12 * Math.max(0, 1 - (x / 37) ** 2) : 0;
    if (actor.turningToExit) {
      const turnLift = isBelly ? 32 * Math.max(0, 1 - (x / 45) ** 2) : 0;
      return [x * 0.9, y * 0.67 - turnLift];
    }
    const r = Math.max(0, Math.min(1, (-y - 16) / 60));
    const a = Math.min(1, Math.max(0, (Math.abs(x) - 30) / 30)) * Math.max(0, 1 - Math.abs(y + 65) / 65);
    return [x * (1 - 0.09 * st * r), y + st * (Math.max(0, Math.min(1, (-y - 16) / 166)) * (12 * actor.crouch - 7) - 15 * a * r - bellyLift)];
  }

  const LANDING_ARM_DEFS = ["left", "right"].map((side) => {
    const sh = shoulderAnchor(NEUTRAL_POSE, side);
    const pw = PAW_REST[side];
    const s = [sh.x - 231, sh.y - 330];
    const e = [pw.x - 231, pw.y - 330];
    const c = [(s[0] + e[0]) / 2 + (side === "left" ? -4 : 4), (s[1] + e[1]) / 2 + 9];
    const toe = armContourPoints({ x: s[0], y: s[1] }, { x: c[0], y: c[1] }, { x: e[0], y: e[1] }).contour[6];
    return { start: s, control: c, end: e, toe };
  });

  function buildLandingArm(actor, def) {
    const warp = (pt) => {
      const [wx, wy] = warpLandingPt(actor, ...pt);
      return { x: wx, y: wy };
    };
    const res = armContourPoints(warp(def.start), warp(def.control), warp(def.end));
    const dx = def.toe[0] - res.contour[6][0];
    const dy = def.toe[1] - res.contour[6][1];
    for (const p of res.contour) {
      p[0] += dx;
      p[1] += dy;
    }
    return res;
  }

  function stepCycleOffset(actor, isFore, isNear) {
    const ph = actor.step + (isNear ? 0 : Math.PI) + (isFore ? 0 : Math.PI);
    return {
      x: actor.stride * 24 * Math.sin(ph),
      y: -actor.stride * 19 * Math.max(0, Math.cos(ph))
    };
  }

  function computeRigMetrics(actor) {
    const st = actor.stand;
    const bounce = -2.4 * actor.stride * Math.sin(actor.step) ** 2;
    const bob = 12 * actor.crouch + bounce;
    const headX = st * actor.heading * (69 + actor.lean);
    const bracedY = lerp(-147, -111, actor.tension);
    const settleY = actor.settlingAtKeys ? -211 : -134;
    const headY = lerp(-204, lerp(settleY, bracedY, Math.abs(actor.heading)), st) + bob;
    const profile = st * Math.min(1, Math.abs(actor.look) / 0.49);
    const useLanding = actor.settlingAtKeys || (actor.turningToExit && BREEDS[actor.breed].tabby);
    const nod = 0.035 * actor.tension + 0.56 * actor.pitch;
    return {
      bob,
      headX,
      headY,
      profile,
      nod,
      landingArms: useLanding ? LANDING_ARM_DEFS.map((d) => buildLandingArm(actor, d)) : undefined,
      landingBelly: useLanding ? subdivideQuad(...bellySpan((nx, ny, b) => warpLandingPt(actor, nx - 231, ny - 330, b))) : undefined,
      fore: stepCycleOffset(actor, true, true),
      hind: stepCycleOffset(actor, false, true),
      farFore: stepCycleOffset(actor, true, false),
      farHind: stepCycleOffset(actor, false, false)
    };
  }

  function blendWorkingPose(actor, pose) {
    const w = actor.working;
    if (w === 1) return pose;
    const mix2 = (a, b) => ({ x: lerp(a.x, b.x, w), y: lerp(a.y, b.y, w) });
    return {
      ...pose,
      headYaw: lerp(actor.look, pose.headYaw, w),
      headPitch: lerp(actor.pitch, pose.headPitch, w),
      gaze: mix2({ x: actor.look * 9, y: actor.pitch * 12 }, pose.gaze),
      turn: pose.turn * w,
      headLean: mix2(NEUTRAL_POSE.headLean, pose.headLean),
      trunk: mix2(NEUTRAL_POSE.trunk, pose.trunk),
      left: { ...pose.left, ...mix2(PAW_REST.left, pose.left) },
      right: { ...pose.right, ...mix2(PAW_REST.right, pose.right) },
      closed: pose.closed * w,
      breath: pose.breath * w,
      tail: pose.tail * w,
      tailTip: pose.tailTip * w,
      earLeft: pose.earLeft * w,
      earRight: pose.earRight * w,
      keyboardReady: pose.keyboardReady * w,
      mouseReach: pose.mouseReach * w
    };
  }

  function rigNode(actor, rig, segIdx, coordIdx, isFar = false, isForeLimb = false) {
    const st = actor.stand;
    const absH = Math.abs(actor.heading);
    const seatSeg = BODY_SPLINES.seated[segIdx];
    const walkSeg = BODY_SPLINES.walking[segIdx];
    const braceSeg = BODY_SPLINES.braced[segIdx];
    const turnSeg = FRONT_TURN_SPLINE[segIdx];
    const useFarHind = isFar && segIdx >= 2 && segIdx <= 7;
    const targetBrace = useFarHind ? FAR_HIND_BRACED[segIdx - 2] : braceSeg;

    let px = lerp(walkSeg[coordIdx], targetBrace[coordIdx], actor.tension);
    let py = lerp(walkSeg[coordIdx + 1], targetBrace[coordIdx + 1], actor.tension);
    const origY = py;
    const isFore = segIdx >= 8;
    const stepOff = isFar ? (isFore ? rig.farFore : rig.farHind) : isFore ? rig.fore : rig.hind;
    const footWeight = Math.max(0, Math.min(1, (origY + 82) / 69));

    px += stepOff.x * footWeight;
    py += stepOff.y * footWeight;
    if (isFar) {
      px += (isFore ? 17 : 35) * (0.2 + 0.8 * footWeight) * (useFarHind ? 1 - actor.tension : 1);
      py -= 8 * footWeight;
    }
    py += (1 - footWeight) * rig.bob;

    if (rig.landingArms) {
      const onArm = isFore && (isFar || isForeLimb || (segIdx >= 9 && segIdx <= 11));
      let landPt;
      if (onArm) {
        const idx = segIdx === 8 ? 0 : 1 + (segIdx - 9) * 3 + coordIdx / 2;
        landPt = rig.landingArms[isFar ? 1 : 0].contour[idx];
      } else if (!isFar && (segIdx === 7 || segIdx === 8)) {
        landPt = rig.landingBelly[(segIdx - 7) * 3 + coordIdx / 2];
      } else {
        const tbl = isFar ? LAND_RIGHT[segIdx - 2] : segIdx === 12 ? LAND_CHEST : segIdx === 13 ? LAND_NECK : LAND_LEFT[segIdx];
        landPt = warpLandingPt(actor, tbl[coordIdx], tbl[coordIdx + 1]);
      }
      return [lerp(landPt[0], px, absH), lerp(landPt[1], py, absH)];
    }

    let sx = seatSeg[coordIdx];
    let sy = seatSeg[coordIdx + 1];
    let tx = turnSeg[coordIdx];
    let ty = turnSeg[coordIdx + 1];

    if (isFar && !isFore) {
      const tbl = FAR_HIND_SEATED[segIdx - 2];
      sx = tbl[coordIdx];
      sy = tbl[coordIdx + 1];
      tx += 64 + 16 * footWeight;
      ty -= 6 * footWeight;
    } else if (isFore && (isFar || isForeLimb)) {
      const tbl = FORE_SEATED[segIdx - 8];
      sy = tbl[coordIdx + 1];
      const e = Math.max(0, Math.min(1, (-sy - 16) / 100));
      sx = tbl[coordIdx] - (isFar ? 0 : 38 + 26 * e);
      tx += sx - seatSeg[coordIdx];
      ty += sy - seatSeg[coordIdx + 1];
      if (isFar) ty -= 4 * footWeight;
    }
    return [lerp(sx, lerp(tx, px, absH), st), lerp(sy, lerp(ty + (1 - footWeight) * rig.bob, py, absH), st)];
  }

  function rigPaws(actor, rig, isFar = false) {
    return {
      fore: rigNode(actor, rig, 10, 4, isFar),
      hind: rigNode(actor, rig, 5, 4, isFar)
    };
  }

  function buildStandingBodyPath(actor, rig, skipLegs = false) {
    const p = new Path2D();
    p.moveTo(...rigNode(actor, rig, 0, 0));
    for (let i = 1; i < BODY_SPLINES.seated.length; i++) {
      if (skipLegs && i === 3) {
        const a = rigNode(actor, rig, 2, 4);
        const b = rigNode(actor, rig, 7, 4);
        p.quadraticCurveTo(a[0], b[1], ...b);
        i = 7;
        continue;
      }
      if (skipLegs && i === 9) {
        const a = rigNode(actor, rig, 8, 4);
        const b = rigNode(actor, rig, 12, 4);
        const lift = 18 * actor.stand * Math.abs(actor.heading);
        p.bezierCurveTo(a[0], a[1] - lift, b[0], b[1] - lift, ...b);
        i = 12;
        continue;
      }
      p.bezierCurveTo(...rigNode(actor, rig, i, 0), ...rigNode(actor, rig, i, 2), ...rigNode(actor, rig, i, 4));
    }
    p.closePath();
    return p;
  }

  function standingLimbFill(ctx, pal, topY, botY, isFar) {
    if (pal.tabby) return tabbyArmGradient(ctx, [0, botY - 66], [0, botY], isFar, isFar ? 1 : 0, pal);
    const g = ctx.createLinearGradient(0, topY, 0, Math.max(topY + 1, botY));
    if (pal.point) {
      g.addColorStop(0, isFar ? "#b49a81" : pal.fur);
      g.addColorStop(0.57, isFar ? "#ac9178" : pal.fur);
      g.addColorStop(0.85, isFar ? "#705945" : "#b8a18a");
      g.addColorStop(1, isFar ? "#584333" : "#79614c");
    } else {
      g.addColorStop(0, isFar ? "#211f22" : pal.fur);
      g.addColorStop(1, isFar ? "#171619" : pal.fur);
    }
    return g;
  }

  function buildSingleLegPath(actor, rig, isFore, isFar) {
    const i0 = isFore ? 9 : 3;
    const i1 = isFore ? 12 : 7;
    const pt = (s, c) => rigNode(actor, rig, s, c, isFar, isFore);
    const p = new Path2D();
    const start = pt(i0 - 1, 4);
    p.moveTo(...start);
    for (let i = i0; i <= i1; i++) {
      p.bezierCurveTo(...pt(i, 0), ...pt(i, 2), ...pt(i, 4));
    }
    p.quadraticCurveTo(start[0], Math.min(start[1] - 5, -98), ...start);
    p.closePath();
    return p;
  }

  function drawStandingTail(ctx, actor, pal, rig) {
    const walkTail = [[-67, -112], [-91, -131], [-102, -162], [-99, -193], [-98, -215], [-86, -234], [-70, -239]];
    const seatTail = [[51, -42], [73, -41], [83, -33], [94, -51], [104, -68], [112, -78], [132, -78]];
    const pts = seatTail.map(([sx, sy], idx) => {
      const frac = idx / 6;
      const absH = Math.abs(actor.heading);
      const dir = actor.heading < 0 ? -1 : 1;
      const wy = walkTail[idx][1] + (1 - actor.tension) * 21 * frac;
      const sway = frac * 4 * actor.stride * Math.sin(actor.step - frac);
      const wx = lerp(sx * dir, walkTail[idx][0], absH);
      return [lerp(sx * dir, wx, actor.stand), lerp(sy, lerp(sy, wy, absH) + sway + rig.bob, actor.stand)];
    });
    ctx.beginPath();
    ctx.moveTo(...pts[0]);
    ctx.bezierCurveTo(...pts[1], ...pts[2], ...pts[3]);
    ctx.bezierCurveTo(...pts[4], ...pts[5], ...pts[6]);
    ctx.strokeStyle = pal.edge;
    ctx.lineWidth = lerp(18.5, 22, actor.stand);
    ctx.stroke();
    ctx.strokeStyle = pal.point ?? pal.fur;
    ctx.lineWidth = lerp(17, 20, actor.stand);
    ctx.stroke();
    if (pal.tabby) {
      drawTabbyTailRings(ctx, pts[3], pts[4], pts[5], pts[6], ctx.lineWidth, pal);
    }
  }

  function drawLandingForelimb(ctx, actor, rig, pal, isFar) {
    const absH = Math.abs(actor.heading);
    const arm = rig.landingArms[isFar ? 1 : 0];
    const pt = (s, c) => rigNode(actor, rig, s, c, isFar, true);
    const path = new Path2D();
    const start = pt(8, 4);
    path.moveTo(...start);
    for (let i = 9; i <= 12; i++) {
      path.bezierCurveTo(...pt(i, 0), ...pt(i, 2), ...pt(i, 4));
    }
    const mid = (a, b) => ({ x: (a[0] + b[0]) / 2, y: (a[1] + b[1]) / 2 });
    const pStart = mid(start, pt(12, 4));
    const pEnd = mid(pt(9, 4), pt(11, 4));
    const pMid = mid(pt(9, 0), pt(12, 2));
    const pCtrl = { x: 1.5 * pMid.x - 0.5 * pStart.x, y: 1.5 * pMid.y - 0.5 * pStart.y };
    const amt = Math.round(absH * 255) / 255;
    const blend = amt > 0 ? { amount: amt, far: isFar, top: isFar ? -137 : -148 + rig.bob, bottom: pt(10, 4)[1] } : undefined;
    paintLimb(ctx, path, pStart, pCtrl, pEnd, arm.width, pal, 0, blend, isFar);
  }

  function drawClippedTabbyTorso(ctx, clipPath, actor, rig, pal) {
    const w = actor.stand * Math.abs(actor.heading);
    ctx.save();
    ctx.clip(clipPath);
    drawTabbyTorsoBib(
      ctx,
      w,
      (ix, iy) => {
        const a = rig.landingArms ? warpLandingPt(actor, ix, iy) : [ix, iy];
        const l = Math.min(1, Math.max(0, -iy / 120));
        return [lerp(a[0], ix, w), lerp(a[1], iy + rig.bob * l + (1 - actor.tension) * 18 * l, w)];
      },
      pal
    );
    ctx.restore();
  }

  function drawLandingCatBody(ctx, actor, rig, pal) {
    const absH = Math.abs(actor.heading);
    const invH = 1 - absH;
    if (absH === 0) {
      ctx.save();
      ctx.translate(-231, -330);
      drawSeatedTorso(ctx, NEUTRAL_POSE, pal, (px, py, isBelly = false) => {
        const [wx, wy] = warpLandingPt(actor, px - 231, py - 330, isBelly);
        return [231 + wx, 330 + wy];
      });
      ctx.restore();
      drawLandingForelimb(ctx, actor, rig, pal, true);
      drawLandingForelimb(ctx, actor, rig, pal, false);
      return undefined;
    }

    const pt = (s, c) => rigNode(actor, rig, s, c);
    const body = new Path2D();
    body.moveTo(...pt(0, 0));
    for (let i = 1; i <= 8; i++) body.bezierCurveTo(...pt(i, 0), ...pt(i, 2), ...pt(i, 4));
    const outline = new Path2D(body);
    const rEnd = warpLandingPt(actor, ...rel231(HIND_FEET.right.end));
    const w8 = BODY_SPLINES.walking[8];
    const w12 = BODY_SPLINES.walking[12];
    const chestStart = [lerp(rEnd[0], w8[4], absH), lerp(rEnd[1], w8[5] + rig.bob, absH)];
    body.lineTo(...chestStart);

    const chestCtrl = (idx, frac) => {
      const s = warpLandingPt(actor, LAND_CHEST[idx], LAND_CHEST[idx + 1]);
      return [lerp(s[0], lerp(w8[4], w12[4], frac), absH), lerp(s[1], lerp(w8[5], w12[5], frac) + rig.bob, absH)];
    };
    const c1 = chestCtrl(0, 1 / 3);
    const c2 = chestCtrl(2, 2 / 3);
    const chestLine = new Path2D();
    chestLine.moveTo(...chestStart);
    chestLine.bezierCurveTo(...c1, ...c2, ...pt(12, 4));
    body.bezierCurveTo(...c1, ...c2, ...pt(12, 4));
    outline.moveTo(...pt(12, 4));
    for (const p of [body, outline]) p.bezierCurveTo(...pt(13, 0), ...pt(13, 2), ...pt(13, 4));
    body.closePath();

    const farHindLeg = buildSingleLegPath(actor, rig, false, true);
    const nearPaws = rigPaws(actor, rig);
    const farPaws = rigPaws(actor, rig, true);

    ctx.strokeStyle = pal.edge;
    ctx.lineWidth = lerp(1, 1.9, absH);
    ctx.fillStyle = pal.fur;
    ctx.fill(farHindLeg);
    ctx.save();
    ctx.globalAlpha *= absH;
    ctx.fillStyle = standingLimbFill(ctx, pal, -137, farPaws.hind[1], true);
    ctx.fill(farHindLeg);
    ctx.restore();
    ctx.stroke(farHindLeg);

    const t = Math.min(1, invH / 0.5);
    if (!pal.tabby && t < 1) {
      ctx.save();
      drawLandingForelimb(ctx, actor, rig, pal, true);
      ctx.restore();
    }
    ctx.fillStyle = pal.fur;
    ctx.fill(body);
    ctx.save();
    ctx.globalAlpha *= absH;
    if (pal.tabby) ctx.clip(buildSingleLegPath(actor, rig, false, false));
    ctx.fillStyle = standingLimbFill(ctx, pal, -148 + rig.bob, nearPaws.hind[1], false);
    ctx.fill(body);
    ctx.restore();
    if (pal.tabby) drawClippedTabbyTorso(ctx, body, actor, rig, pal);
    ctx.stroke(outline);
    ctx.save();
    ctx.globalAlpha *= invH;
    ctx.stroke(chestLine);
    ctx.restore();

    if ((pal.point || pal.tabby) && invH > 0) {
      const union = new Path2D(body);
      union.addPath(farHindLeg);
      ctx.save();
      ctx.clip(union);
      ctx.globalAlpha *= invH;
      for (const [foot, paw] of [
        [HIND_FEET.left, nearPaws.hind],
        [HIND_FEET.right, farPaws.hind]
      ]) {
        const toe = foot.toe;
        drawFootMarking(ctx, pal, paw[0] + (foot.marking[0] - toe[0]), paw[1] + (foot.marking[1] - toe[1]));
      }
      ctx.restore();
    }

    ctx.save();
    if (pal.tabby) {
      const mask = new Path2D();
      mask.rect(-350, -350, 700, 700);
      mask.addPath(body, new DOMMatrix().translate(0, -240 * t));
      ctx.clip(mask, "evenodd");
    } else if (t < 1) {
      ctx.clip(body);
      ctx.globalAlpha *= t * t * (3 - 2 * t);
    }
    drawLandingForelimb(ctx, actor, rig, pal, true);
    ctx.restore();
    drawLandingForelimb(ctx, actor, rig, pal, false);
    return body;
  }

  function drawStandingCatBody(ctx, actor, rig, pal) {
    const farFore = buildSingleLegPath(actor, rig, true, true);
    const farHind = buildSingleLegPath(actor, rig, false, true);
    const farPaws = rigPaws(actor, rig, true);

    const paintFar = (legPath, botY) => {
      ctx.fillStyle = standingLimbFill(ctx, pal, -137, botY, true);
      ctx.fill(legPath);
      ctx.strokeStyle = pal.edge;
      ctx.lineWidth = 1.7;
      ctx.stroke(legPath);
    };
    paintFar(farHind, farPaws.hind[1]);
    paintFar(farFore, farPaws.fore[1]);

    const body = buildStandingBodyPath(actor, rig);
    const walkAmt = actor.stand * Math.abs(actor.heading);
    const frontBlend = Math.max(0, 1 - walkAmt / 0.7);

    if (pal.tabby) {
      const coreBody = buildStandingBodyPath(actor, rig, true);
      const nearPaws = rigPaws(actor, rig);
      const nearHind = buildSingleLegPath(actor, rig, false, false);
      const nearFore = buildSingleLegPath(actor, rig, true, false);
      const paintTabbyLeg = (legPath, pawPt, isRight) => {
        const top = [pawPt[0], lerp(pawPt[1] - 66, -118, frontBlend)];
        ctx.fillStyle = tabbyArmGradient(ctx, top, pawPt, isRight, 0, pal);
        ctx.fill(legPath);
        const sg = ctx.createLinearGradient(...top, ...pawPt);
        sg.addColorStop(0, "transparent");
        sg.addColorStop(0.65, pal.edge);
        ctx.strokeStyle = sg;
        ctx.lineWidth = 1.7;
        ctx.stroke(legPath);
      };
      ctx.fillStyle = pal.fur;
      ctx.fill(body);
      ctx.save();
      ctx.clip(body);
      paintTabbyLeg(nearHind, nearPaws.hind, false);
      paintTabbyLeg(nearFore, nearPaws.fore, false);
      ctx.restore();
      ctx.fillStyle = pal.fur;
      ctx.fill(coreBody);
      ctx.save();
      ctx.clip(body);
      drawClippedTabbyTorso(ctx, coreBody, actor, rig, pal);
      ctx.restore();
      ctx.strokeStyle = pal.edge;
      ctx.lineWidth = lerp(1, 1.9, actor.stand);
      ctx.stroke(body);
      if (frontBlend > 0) {
        ctx.save();
        ctx.clip(body);
        const mask = new Path2D();
        mask.rect(-350, -350, 700, 700);
        mask.addPath(body, new DOMMatrix().translate(0, -240 * frontBlend));
        ctx.clip(mask, "evenodd");
        paintTabbyLeg(farFore, farPaws.fore, true);
        paintTabbyLeg(nearFore, nearPaws.fore, false);
        ctx.restore();
      }
    } else {
      ctx.fillStyle = pal.fur;
      ctx.fill(body);
      if (actor.stand > 0) {
        ctx.save();
        ctx.clip(body);
        const splitX = rigNode(actor, rig, 8, 2)[0];
        for (const isFore of [false, true]) {
          const paw = rigNode(actor, rig, isFore ? 10 : 5, 4);
          ctx.fillStyle = standingLimbFill(ctx, pal, lerp(-17, -148 + rig.bob, actor.stand), paw[1], false);
          if (isFore) ctx.fillRect(splitX, -300, 320, 410);
          else ctx.fillRect(-300, -300, splitX + 300, 410);
        }
        ctx.restore();
      }
      ctx.strokeStyle = pal.edge;
      ctx.lineWidth = lerp(1, 1.9, actor.stand);
      ctx.stroke(body);
    }

    if (actor.tension * actor.stand > 0.03) {
      const tuftPos = rigNode(actor, rig, 1, 4);
      const sc = actor.tension * actor.stand;
      ctx.save();
      ctx.translate(...tuftPos);
      ctx.scale(sc, sc);
      const spikes = new Path2D();
      spikes.moveTo(-14, 4);
      spikes.quadraticCurveTo(-8, 0, -3, 0);
      spikes.lineTo(-8, -3);
      spikes.quadraticCurveTo(0, -3, 5, 0);
      spikes.lineTo(1, -4);
      spikes.quadraticCurveTo(10, -2, 17, 4);
      const fillSpikes = new Path2D(spikes);
      fillSpikes.lineTo(16, 7);
      fillSpikes.lineTo(-14, 7);
      ctx.fillStyle = pal.fur;
      ctx.fill(fillSpikes);
      ctx.strokeStyle = pal.edge;
      ctx.lineWidth = 1.4;
      ctx.stroke(spikes);
      ctx.restore();
    }

    if (!pal.tabby && frontBlend > 0) {
      ctx.save();
      ctx.globalAlpha *= frontBlend * frontBlend * (3 - 2 * frontBlend);
      for (const isFar of [true, false]) {
        if (!isFar) ctx.clip(body);
        const leg = isFar ? farFore : buildSingleLegPath(actor, rig, true, false);
        const forePt = rigPaws(actor, rig, isFar).fore;
        const g = ctx.createLinearGradient(0, -118, 0, forePt[1]);
        g.addColorStop(0.22, pal.fur);
        g.addColorStop(0.76, pal.point ? "#856a55" : pal.fur);
        g.addColorStop(1, pal.point ?? pal.fur);
        ctx.fillStyle = g;
        ctx.fill(leg);
        const sg = ctx.createLinearGradient(0, -118, 0, forePt[1]);
        sg.addColorStop(0.28, "transparent");
        sg.addColorStop(1, pal.point || pal.tabby ? pal.edge : "#eeece6");
        ctx.strokeStyle = sg;
        ctx.lineWidth = 1.7;
        ctx.stroke(leg);
      }
      ctx.restore();
    }
    return body;
  }

  function drawHandoverActor(ctx, actor) {
    const rig = computeRigMetrics(actor);
    const pal = BREEDS[actor.breed];
    const dir = actor.heading < 0 ? -1 : 1;
    ctx.save();
    ctx.translate(actor.x, actor.y);
    ctx.scale(dir, 1);
    drawStandingTail(ctx, actor, pal, rig);
    const bodyPath = rig.landingArms ? drawLandingCatBody(ctx, actor, rig, pal) : drawStandingCatBody(ctx, actor, rig, pal);
    const clipInfo = bodyPath && { path: bodyPath, transform: ctx.getTransform() };
    ctx.translate(dir * rig.headX, rig.headY);
    const headFlip = (actor.look < 0 ? -1 : 1) * dir;
    ctx.scale(headFlip, 1);
    ctx.rotate(rig.nod);
    ctx.translate(-231, -126);
    drawCatHead(
      ctx,
      {
        ...NEUTRAL_POSE,
        headYaw: Math.abs(actor.look),
        headPitch: actor.pitch,
        gaze: { x: Math.abs(actor.look) * 10, y: actor.pitch * 10 }
      },
      pal,
      actor.tension,
      rig.profile,
      clipInfo
    );
    ctx.restore();
  }

  // =========================================================================
  // Audio Engine
  // =========================================================================
  class PetAudioManager {
    constructor() {
      this.ctx = null;
      this.buffers = new Map();
      this.enabled = false;
      this.duelSource = null;
      this.activeDuelCue = null;
      this.tone = "clear";
    }

    ensureContext() {
      if (!this.ctx) {
        const AC = window.AudioContext || window.webkitAudioContext;
        if (AC) this.ctx = new AC();
      }
      if (this.ctx && this.ctx.state === "suspended") {
        this.ctx.resume().catch(() => {});
      }
      return this.ctx;
    }

    async loadBuffer(url) {
      if (this.buffers.has(url)) return this.buffers.get(url);
      const ac = this.ensureContext();
      if (!ac) return null;
      const p = fetch(url)
        .then((r) => {
          if (!r.ok) throw new Error("audio fetch failed");
          return r.arrayBuffer();
        })
        .then((ab) => ac.decodeAudioData(ab))
        .catch(() => {
          this.buffers.delete(url);
          return null;
        });
      this.buffers.set(url, p);
      return p;
    }

    warmup() {
      this.ensureContext();
      this.loadBuffer("./media/pet/clack_duel.m4a");
      this.loadBuffer("./media/pet/kb_mx_clear.wav");
      this.loadBuffer("./media/pet/kb_mx_blue.wav");
      this.loadBuffer("./media/pet/mouse_crisp.wav");
    }

    async playKey(isMouse = false) {
      if (!this.enabled) return;
      const ac = this.ensureContext();
      if (!ac) return;
      const url = isMouse
        ? "./media/pet/mouse_crisp.wav"
        : this.tone === "blue"
          ? "./media/pet/kb_mx_blue.wav"
          : "./media/pet/kb_mx_clear.wav";
      const buf = await this.loadBuffer(url);
      if (!buf || !this.enabled) return;
      const src = ac.createBufferSource();
      const gain = ac.createGain();
      src.buffer = buf;
      src.playbackRate.value = 0.95 + Math.random() * 0.1;
      gain.gain.value = isMouse ? 0.45 : 0.34;
      src.connect(gain);
      gain.connect(ac.destination);
      src.start();
    }

    async syncDuel(duelStartPerfMs, nowPerfMs) {
      const duelDurMs = HANDOVER_TIMING.duelEnd - HANDOVER_TIMING.braceEnd;
      const cue = this.enabled && duelStartPerfMs !== null && nowPerfMs < duelStartPerfMs + duelDurMs ? duelStartPerfMs : null;
      if (cue === this.activeDuelCue) return;
      this.activeDuelCue = cue;
      if (this.duelSource) {
        try {
          this.duelSource.stop();
          this.duelSource.disconnect();
        } catch {}
        this.duelSource = null;
      }
      if (cue === null) return;
      const ac = this.ensureContext();
      if (!ac) return;
      const buf = await this.loadBuffer("./media/pet/clack_duel.m4a");
      if (!buf || this.activeDuelCue !== cue || !this.enabled) return;
      const deltaSec = (cue - performance.now()) / 1000;
      const offsetSec = Math.max(0, -deltaSec);
      const playDur = Math.min(duelDurMs / 1000, buf.duration) - offsetSec;
      if (playDur <= 0) return;
      const src = ac.createBufferSource();
      const gain = ac.createGain();
      src.buffer = buf;
      gain.gain.value = 0.72;
      src.connect(gain);
      gain.connect(ac.destination);
      src.start(ac.currentTime + Math.max(0, deltaSec), offsetSec, playDur);
      this.duelSource = src;
    }
  }

  // =========================================================================
  // Cat Simulator & Offscreen Sticker Renderer
  // =========================================================================
  class CatSimulator {
    constructor(settings) {
      this.settings = settings;
      this.pose = {
        mouse: { ...MOUSE_HOME },
        mouseReach: 0,
        headYaw: 0,
        headPitch: 0,
        left: { ...PAW_REST.left, vx: 0, vy: 0 },
        right: { ...PAW_REST.right, vx: 0, vy: 0 },
        trunk: { x: 0, y: 0 },
        headLean: { x: 0, y: 0 },
        keyboardReady: 0,
        gaze: { x: 0, y: 0 },
        turn: 0,
        breath: 0,
        closed: 0,
        petting: 0,
        tail: 0,
        tailTip: 0,
        earLeft: 0,
        earRight: 0,
        time: 0,
        pressed: new Set(),
        buttons: new Set(),
        flashes: new Map(),
        bubbles: []
      };
      this.pulseId = 1;
      this.latestPress = new Map();
      this.recentPressTimestamps = [];
      this.anger = 0;
      this.mouseTarget = { ...MOUSE_HOME };
      this.cursorLogical = { x: 230, y: 175 };
      this.gripUntil = 0;
      this.graspStart = null;
      this.graspTime = 0;
      this.readyUntil = 0;
      this.keyDirection = 0;
      this.breathPhase = 0;
      this.tailPhase = 0;
      this.nextBlink = 2.1;
      this.blinkIndex = 0;
    }

    tapKey(code, holdMs = 70) {
      const now = Date.now();
      const id = this.pulseId++;
      this.pose.pressed.add(code);
      this.latestPress.set(code, now);
      this.pose.flashes.set(code, now);
      this.recentPressTimestamps.push(now);
      if (this.recentPressTimestamps.length > 18) this.recentPressTimestamps.shift();

      if (this.settings.showKeyBubbles) {
        const pt = code.startsWith("Mouse") ? this.pose.mouse : keyTargetPoint(code) ?? { x: 248, y: KB.y };
        this.pose.bubbles.push({
          id,
          code,
          atMs: now,
          x: pt.x,
          y: Math.min(pt.y - 30, KB.y - 22)
        });
        this.pose.bubbles = this.pose.bubbles.slice(-7);
      }

      if (holdMs > 0) {
        setTimeout(() => {
          this.pose.pressed.delete(code);
        }, holdMs);
      }
    }

    moveMouse(stageX, stageY, isClick = false) {
      const now = Date.now();
      const loc = stageToLogical({ x: stageX, y: stageY }, 1);
      const dx = loc.x - this.cursorLogical.x;
      const dy = loc.y - this.cursorLogical.y;
      this.cursorLogical = loc;

      const ho = headOffset(this.pose);
      const distHead = Math.hypot(loc.x - (231 + ho.x), loc.y - (130 + ho.y));
      if (distHead < 58 && Math.hypot(dx, dy) > 0.4) {
        this.pose.petting = Math.min(1, this.pose.petting + 0.18);
        return "pet";
      }

      this.mouseTarget.x = Math.max(MOUSE_BOUNDS.left, Math.min(MOUSE_BOUNDS.right, this.mouseTarget.x + dx * 0.18));
      this.mouseTarget.y = Math.max(MOUSE_BOUNDS.top, Math.min(MOUSE_BOUNDS.bottom, this.mouseTarget.y + dy * 0.18));
      this.gripUntil = now + 450;
      if (isClick) {
        this.tapKey("MouseLeft", 95);
      }
      return "mouse";
    }

    step(dt, nowMs) {
      dt = Math.min(Math.max(dt, 0.001), 0.06);
      const p = this.pose;
      p.time += dt;
      p.petting = Math.max(0, p.petting - dt * 0.65);

      this.recentPressTimestamps = this.recentPressTimestamps.filter((t) => nowMs - t < 1100);
      const targetAnger = this.recentPressTimestamps.length >= 5 ? Math.min(1, (this.recentPressTimestamps.length - 4) / 5) : 0;
      this.anger += (targetAnger - this.anger) * (1 - Math.exp(-8 * dt));

      const bElapsed = p.time - this.nextBlink;
      const blinkCurve = Math.max(0, Math.min(1, bElapsed / 0.09, (0.29 - bElapsed) / 0.16));
      if (bElapsed >= 0.29) {
        this.nextBlink += [3.8, 5.2, 2.9][this.blinkIndex++ % 3];
      }
      const targetClosed = p.petting > 0.25 ? 0.92 : this.settings.reducedMotion ? 0 : blinkCurve;
      p.closed += (targetClosed - p.closed) * (1 - Math.exp(-28 * dt));

      const activeTargets = { left: null, right: null };
      for (const code of p.pressed) {
        const kt = keyTargetPoint(code);
        if (!kt) continue;
        const at = this.latestPress.get(code) ?? 0;
        if (!activeTargets[kt.side] || at >= activeTargets[kt.side].at) {
          activeTargets[kt.side] = { x: kt.x, y: kt.y - 2, at };
        }
      }
      const heldSide = { left: !!activeTargets.left, right: !!activeTargets.right };
      for (const [code, at] of p.flashes) {
        if (nowMs - at > 125) {
          if (nowMs - at > 520) p.flashes.delete(code);
          continue;
        }
        const kt = keyTargetPoint(code);
        if (kt && !heldSide[kt.side] && at >= (activeTargets[kt.side]?.at ?? 0)) {
          activeTargets[kt.side] = { x: kt.x, y: kt.y - 2, at };
        }
      }

      const mouseClicked = ["MouseLeft", "MouseRight", "MouseMiddle"].some((c) => nowMs - (p.flashes.get(c) ?? 0) < 180);
      const useMouse = p.buttons.size > 0 || mouseClicked || nowMs < this.gripUntil;
      const mSmooth = this.settings.reducedMotion ? 1 : 1 - Math.exp(-24 * dt);
      p.mouse.x += (this.mouseTarget.x - p.mouse.x) * mSmooth;
      p.mouse.y += (this.mouseTarget.y - p.mouse.y) * mSmooth;

      const reachSmooth = this.settings.reducedMotion ? 1 : 1 - Math.exp(-18 * dt);
      p.mouseReach += (Number(useMouse) - p.mouseReach) * reachSmooth;

      if (activeTargets.left || activeTargets.right) {
        this.readyUntil = nowMs + 460;
        const avgX = activeTargets.left && activeTargets.right
          ? (activeTargets.left.x + activeTargets.right.x) / 2
          : (activeTargets.left ?? activeTargets.right).x;
        this.keyDirection = Math.max(-1, Math.min(1, (avgX - 235) / 115));
      }

      const typingReady = nowMs < this.readyUntil;
      if (this.settings.reducedMotion) {
        p.keyboardReady = 0;
        p.trunk.x = p.trunk.y = p.headLean.x = p.headLean.y = 0;
        p.headYaw = p.headPitch = 0;
        p.breath = p.tail = p.tailTip = p.earLeft = p.earRight = 0;
      } else {
        p.keyboardReady += (Number(typingReady) - p.keyboardReady) * (1 - Math.exp(-(typingReady ? 14 : 5) * dt));
        const kr = p.keyboardReady;
        const mr = p.mouseReach;
        const musicSway = this.settings.musicMode ? Math.sin(p.time * 4.4) * 5.2 : 0;
        const musicNod = this.settings.musicMode ? Math.abs(Math.cos(p.time * 4.4)) * 3.4 : 0;
        const tx = (p.mouse.x - 230) * 0.53 * mr * (1 - 0.48 * kr) + 23 * this.keyDirection * kr * (1 - 0.65 * mr) + musicSway;
        const ty = 13 * mr + 24 * kr - 10 * mr * kr + musicNod;
        p.trunk.x += (tx - p.trunk.x) * (1 - Math.exp(-7.4 * dt));
        p.trunk.y += (ty - p.trunk.y) * (1 - Math.exp(-7.4 * dt));
        p.headLean.x += (p.trunk.x - p.headLean.x) * (1 - Math.exp(-14 * dt));
        p.headLean.y += (p.trunk.y - p.headLean.y) * (1 - Math.exp(-14 * dt));

        const lookX = Math.tanh((this.cursorLogical.x - 231 - p.headLean.x) / 165);
        const lookY = Math.tanh((this.cursorLogical.y - 126 - p.headLean.y) / 165);
        const atten = 1 - 0.82 * kr * (1 - mr);
        p.headYaw += (0.42 * atten * lookX - p.headYaw) * (1 - Math.exp(-8 * dt));
        p.headPitch += (0.22 * atten * lookY - p.headPitch) * (1 - Math.exp(-8 * dt));

        this.breathPhase += dt * 2.1;
        this.tailPhase += dt * (typingReady || this.settings.musicMode ? 2.5 : 1.45);
        p.breath = Math.sin(this.breathPhase) * 1.35;
        const tailAmp = typingReady ? 7.2 : 5;
        p.tail += (tailAmp * Math.sin(this.tailPhase) - p.tail) * (1 - Math.exp(-5 * dt));
        p.tailTip += (p.tail * 1.85 - p.tailTip) * (1 - Math.exp(-3 * dt));

        const twitchCycle = (p.time + 4.3) % 7.2;
        const twitch = twitchCycle < 0.42 ? Math.sin((Math.PI * twitchCycle) / 0.42) ** 2 * 9 : 0;
        const petFold = 4 * p.petting;
        const gazeEar = p.gaze.x * 0.65;
        const earSmooth = 1 - Math.exp(-12 * dt);
        p.earLeft += (gazeEar - petFold - twitch - p.earLeft) * earSmooth;
        p.earRight += (gazeEar + petFold - p.earRight) * earSmooth;
      }

      const gazeBlend = p.keyboardReady * (1 - p.mouseReach) * 0.85;
      const gx = Math.tanh((this.cursorLogical.x - 230) / 170) * 7 * (1 - gazeBlend) + 6 * this.keyDirection * gazeBlend;
      const gy = Math.tanh((this.cursorLogical.y - 172) / 170) * 5 * (1 - gazeBlend) + 5 * gazeBlend;
      p.gaze.x += (gx - p.gaze.x) * (1 - Math.exp(-13 * dt));
      p.gaze.y += (gy - p.gaze.y) * (1 - Math.exp(-13 * dt));
      p.turn += (p.gaze.x * 0.7 - p.turn) * (1 - Math.exp(-6 * dt));

      const liftPaw = (target) => {
        const lift = this.settings.reducedMotion ? 0 : 16 * Math.max(0, Math.min(1, 1 - (nowMs - target.at) / 55));
        return { x: target.x, y: target.y - lift };
      };

      const rightKeyTarget = useMouse && activeTargets.left && (!activeTargets.right || activeTargets.left.at > activeTargets.right.at)
        ? activeTargets.left
        : activeTargets.right;

      const leftGoal = activeTargets.left ? liftPaw(activeTargets.left) : readyPawTarget(p, "left");
      const rightGoal = rightKeyTarget ? liftPaw(rightKeyTarget) : readyPawTarget(p, "right");

      if (useMouse) {
        if (!this.graspStart) {
          this.graspStart = { x: p.left.x, y: p.left.y };
          this.graspTime = 0;
        }
        this.graspTime += dt;
        p.left.vx = p.left.vy = 0;
        if (this.settings.reducedMotion || this.graspTime >= 0.12) {
          p.left.x = p.mouse.x;
          p.left.y = p.mouse.y - 5;
        } else {
          const u = this.graspTime / 0.12;
          const s = u * u * (3 - 2 * u);
          p.left.x = this.graspStart.x + (p.mouse.x - this.graspStart.x) * s;
          p.left.y = this.graspStart.y + (p.mouse.y - 5 - this.graspStart.y) * s - 5 * Math.sin(Math.PI * u) ** 2;
        }
      } else {
        this.graspStart = null;
        stepSpring2D(p.left, leftGoal, dt, this.settings.reducedMotion, !!activeTargets.left);
      }
      stepSpring2D(p.right, rightGoal, dt, this.settings.reducedMotion, !!rightKeyTarget);

      p.bubbles = p.bubbles.filter((b) => nowMs - b.atMs < 1150);
      return p;
    }
  }

  class StageRenderer {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.catLayer = document.createElement("canvas");
      this.catCtx = this.catLayer.getContext("2d");
      this.silLayer = document.createElement("canvas");
      this.silCtx = this.silLayer.getContext("2d");
      this.dpr = 1;
      this.resize();
    }

    resize() {
      this.dpr = Math.min(window.devicePixelRatio || 1, 2.25);
      const pw = Math.round(STAGE.width * this.dpr);
      const ph = Math.round(STAGE.height * this.dpr);
      for (const c of [this.canvas, this.catLayer, this.silLayer]) {
        c.width = pw;
        c.height = ph;
      }
    }

    applyCamera(ctx) {
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      ctx.translate(STAGE.anchorX, STAGE.anchorY);
      ctx.scale(BASE_SCALE, BASE_SCALE);
      ctx.translate(-230, -405);
      ctx.lineJoin = "round";
      ctx.lineCap = "round";
    }

    drawShadow(ctx, x, y, rx, ry, alpha) {
      ctx.save();
      ctx.translate(x, y);
      ctx.scale(rx, ry);
      const g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1);
      g.addColorStop(0, `rgba(42, 33, 28, ${alpha})`);
      g.addColorStop(1, "rgba(42, 33, 28, 0)");
      fillEllipse(ctx, 0, 0, 1, 1, g);
      ctx.restore();
    }

    drawArmOn(ctx, pose, side, pal) {
      const start = shoulderAnchor(pose, side);
      const paw = pose[side];
      const lift = pose.keyboardReady * Math.max(0, Math.min(1, (PAW_REST[side].y - paw.y) / 48));
      let ctrl = {
        x: (start.x + paw.x) / 2 + (side === "left" ? -1 : 1) * (4 + 20 * lift),
        y: (start.y + paw.y) / 2 + 9 + 27 * lift
      };
      const grip = side === "left"
        ? Math.min(1, pose.mouseReach / 0.85) * Math.max(0, Math.min(1, (start.x - paw.x - 8) / 42))
        : 0;
      if (grip > 0) {
        const dx = start.x - paw.x;
        const dy = start.y - paw.y;
        const dist = Math.hypot(dx, dy) || 1;
        const arc = 0.13 * Math.sqrt(Math.max(0, 98 ** 2 - (dist / 2) ** 2));
        const gCtrl = {
          x: (start.x + paw.x) / 2 + ((2 * dy) / dist) * arc,
          y: (start.y + paw.y) / 2 - ((2 * dx) / dist) * arc
        };
        ctrl = { x: lerp(ctrl.x, gCtrl.x, grip), y: lerp(ctrl.y, gCtrl.y, grip) };
      }
      drawForearm(ctx, start, ctrl, paw, grip, pal, 0, side === "right");
    }

    compositeStickerLayer(sourceCanvas) {
      const ctx = this.ctx;
      const sctx = this.silCtx;
      const w = this.silLayer.width;
      const h = this.silLayer.height;

      sctx.setTransform(1, 0, 0, 1, 0, 0);
      sctx.clearRect(0, 0, w, h);
      sctx.drawImage(sourceCanvas, 0, 0);
      sctx.globalCompositeOperation = "source-in";
      sctx.fillStyle = "#ffffff";
      sctx.fillRect(0, 0, w, h);
      sctx.globalCompositeOperation = "source-over";

      ctx.save();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.save();
      ctx.globalAlpha = 0.16;
      ctx.drawImage(this.silLayer, 0, 2.8 * this.dpr);
      ctx.restore();

      const rad = 3.8 * this.dpr;
      const steps = 12;
      for (let i = 0; i < steps; i++) {
        const ang = (i * Math.PI * 2) / steps;
        ctx.drawImage(this.silLayer, Math.cos(ang) * rad, Math.sin(ang) * rad);
      }
      ctx.drawImage(sourceCanvas, 0, 0);
      ctx.restore();
    }

    render(pose, settings, nowMs, handoverFrame, anger) {
      const ctx = this.ctx;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      ctx.clearRect(0, 0, STAGE.width, STAGE.height);

      ctx.save();
      this.applyCamera(ctx);

      if (handoverFrame) {
        for (const actor of [handoverFrame.resident, handoverFrame.visitor]) {
          if (actor) this.drawShadow(ctx, actor.x, actor.y, 75, 6, 0.18);
        }
      } else {
        this.drawShadow(ctx, 229, 330, 75, 6, 0.18);
      }
      this.drawShadow(ctx, 257, 382, 144, 8, 0.14);
      this.drawShadow(ctx, pose.mouse.x - 4, pose.mouse.y + 20, 19, 4.5, 0.18);

      drawKeyboard(ctx, pose, settings, nowMs);
      drawMouse(ctx, pose, nowMs);
      ctx.restore();

      const cctx = this.catCtx;
      cctx.setTransform(1, 0, 0, 1, 0, 0);
      cctx.clearRect(0, 0, this.catLayer.width, this.catLayer.height);
      cctx.save();
      this.applyCamera(cctx);

      let seatedPose = handoverFrame ? null : pose;
      let seatedPal = BREEDS[settings.breed];

      if (handoverFrame) {
        const clip = new Path2D();
        clip.rect(handoverFrame.leftEdge, -480, handoverFrame.rightEdge - handoverFrame.leftEdge, 3 * STAGE.height);
        cctx.save();
        cctx.clip(clip);
        const { resident, visitor } = handoverFrame;
        const order = resident && resident.y > visitor.y ? [visitor, resident] : [resident, visitor];
        for (const actor of order) {
          if (!actor) continue;
          if (actor.stand > 0) {
            drawHandoverActor(cctx, actor);
          } else {
            seatedPose = blendWorkingPose(actor, pose);
            seatedPal = BREEDS[actor.breed];
          }
        }
        cctx.restore();
      }

      if (seatedPose) {
        drawSeatedTail(cctx, seatedPose, seatedPal);
        drawSeatedTorso(cctx, seatedPose, seatedPal);
        this.drawArmOn(cctx, seatedPose, "left", seatedPal);
        this.drawArmOn(cctx, seatedPose, "right", seatedPal);
        drawCatHead(cctx, seatedPose, seatedPal, 0, 0, undefined, {
          headphones: settings.musicMode && !handoverFrame,
          anger: handoverFrame ? 0 : anger
        });
      }
      cctx.restore();

      if (settings.stickerOutline) {
        this.compositeStickerLayer(this.catLayer);
      } else {
        ctx.save();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.drawImage(this.catLayer, 0, 0);
        ctx.restore();
      }

      ctx.save();
      this.applyCamera(ctx);

      if (!handoverFrame && settings.musicMode && !settings.reducedMotion) {
        for (let i = 0; i < 2; i++) {
          const prog = (pose.time * 0.45 + i * 0.5) % 1;
          const alpha = Math.sin(prog * Math.PI) * 0.85;
          const nx = 152 - i * 24 + Math.sin(pose.time * 2.2 + i) * 7;
          const ny = 96 - prog * 34;
          ctx.save();
          ctx.globalAlpha = alpha;
          ctx.font = "700 16px -apple-system, sans-serif";
          ctx.fillStyle = i === 0 ? "#f26b7a" : "#584ce5";
          ctx.fillText(i === 0 ? "♪" : "♫", nx, ny);
          ctx.restore();
        }
      }

      if (!handoverFrame && settings.showKeyBubbles) {
        for (const b of pose.bubbles) {
          const age = Math.max(0, (nowMs - b.atMs) / 1000);
          const alpha = Math.min(1, age * 11) * Math.min(1, (1.15 - age) * 3.2);
          if (alpha <= 0) continue;
          const label = bubbleLabelForCode(b.code);
          ctx.save();
          ctx.globalAlpha = alpha;
          ctx.font = "700 14px -apple-system, BlinkMacSystemFont, sans-serif";
          const bw = Math.max(30, ctx.measureText(label).width + 18);
          const bx = b.x + Math.sin(b.id * 2.4) * age * 9;
          const by = b.y - age * 62;
          ctx.beginPath();
          ctx.roundRect(bx - bw / 2, by + 3, bw, 26, 8);
          ctx.fillStyle = "#3c3533";
          ctx.fill();
          ctx.beginPath();
          ctx.roundRect(bx - bw / 2, by, bw, 26, 8);
          ctx.fillStyle = "#fffdf7";
          ctx.fill();
          ctx.strokeStyle = "#3c3533";
          ctx.lineWidth = 2;
          ctx.stroke();
          ctx.fillStyle = "#2a211c";
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          ctx.fillText(label, bx, by + 13);
          ctx.restore();
        }
      }

      if (!handoverFrame && pose.petting > 0.22) {
        ctx.save();
        ctx.globalAlpha = Math.min(1, pose.petting * 1.2);
        ctx.font = "700 16px -apple-system, sans-serif";
        ctx.fillStyle = "#f26b7a";
        ctx.fillText("♥", 268, 76 - Math.sin(pose.time * 6) * 4);
        ctx.restore();
      }

      ctx.restore();
    }
  }

  // =========================================================================
  // 3-Act Panoramic SVG + Cat Director Timeline Scripts
  // =========================================================================
  const CINEMA_ACTS = [
    {
      id: "act1",
      durationMs: 6000,
      appBadge: "💬 聊天窗口 · 秒回消息",
      latencyText: "118 ms",
      segments: [
        { text: "呃那个", bug: true },
        { text: "琳琳不好意思呀，我刚下地铁拎着东西没法打字，", bug: false },
        { text: "周三不对", bug: true },
        { text: "改成周四晚七点那家云南菜哈", bug: false }
      ],
      badges: ["✂️ 秒删口头禅", "🎯 捉住改口：周三→周四", "✨ 语气自然润色"],
      polished: "琳琳不好意思呀，我刚下地铁手里拎着东西不方便打字。周四晚上七点那家云南菜我订好啦，不见不散！",
      keys: [
        "KeyL", "KeyI", "KeyN", "Space", "KeyD", "KeyI", "KeyT", "KeyI", "KeyE", "Space",
        "KeyZ", "KeyH", "KeyO", "KeyU", "Digit4", "Space", "KeyQ", "KeyI", "KeyD", "KeyI", "KeyA", "KeyN",
        "Space", "KeyY", "KeyU", "KeyN", "KeyN", "KeyA", "KeyN", "Enter"
      ]
    },
    {
      id: "act2",
      durationMs: 6200,
      appBadge: "📕 小红书 / 备忘录 · 碎碎念成稿",
      latencyText: "132 ms",
      segments: [
        { text: "记一下周五探店拍摄", bug: false },
        { text: "呃怎么说呢", bug: true },
        { text: "三件事哈，第一带奶油色针织开衫，第二提前订靠窗位，第三", bug: false },
        { text: "那个啥", bug: true },
        { text: "把两块相机电池充满", bug: false }
      ],
      badges: ["✂️ 滤除碎碎念废话", "📑 自动分点 1·2·3", "⚡ 零乱码直出光标"],
      polished: "周五探店拍摄清单：\n1. 穿搭准备：带上奶油色针织开衫；\n2. 场地预约：提前锁定靠窗拍照座位；\n3. 设备检查：把两块备用相机电池充满。",
      keys: [
        "Digit1", "KeyK", "KeyA", "KeyI", "KeyS", "KeyH", "KeyA", "KeyN", "Enter",
        "Digit2", "KeyK", "KeyA", "KeyO", "KeyC", "KeyH", "KeyU", "KeyA", "KeyN", "KeyG", "Enter",
        "Digit3", "KeyX", "KeyI", "KeyA", "KeyN", "KeyG", "KeyJ", "KeyI", "Enter"
      ]
    },
    {
      id: "act3",
      durationMs: 10800,
      isDuelAct: true,
      appBadge: "🐾 桌面搭子 · 换猫交接仪式",
      latencyText: "名场面"
    }
  ];

  // =========================================================================
  // Mount Controller & Auto-Director
  // =========================================================================
  function initPetStage() {
    const canvas = document.getElementById("heroPetCanvas");
    if (!canvas) return null;

    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const settings = {
      breed: "black",
      rgbGlow: true,
      musicMode: false,
      stickerOutline: true,
      showKeyLabels: true,
      showKeyBubbles: true,
      reducedMotion: prefersReduced || Boolean(window.tzMotionPaused)
    };

    const sim = new CatSimulator(settings);
    const renderer = new StageRenderer(canvas);
    const audio = new PetAudioManager();

    let handover = null;
    let userMutedExplicitly = false;

    // Cinema DOM elements
    const actBtns = Array.from(document.querySelectorAll("[data-cinema-act]"));
    const waveBars = Array.from(document.querySelectorAll("#capsuleWaveSvg rect"));
    const capsuleStatusEl = document.getElementById("cinemaCapsuleStatus");
    const capsuleLatencyEl = document.getElementById("cinemaCapsuleLatency");
    const capsulePillEl = document.getElementById("cinemaVoiceCapsule");
    const appBadgeEl = document.getElementById("cinemaAppBadge");
    const spokenContainerEl = document.getElementById("cinemaSpokenText");
    const magicBadgesEl = document.getElementById("cinemaMagicBadges");
    const flowLineEl = document.getElementById("cinemaSvgFlowPath");
    const polishedBoxEl = document.getElementById("cinemaPolishedText");
    const doneChipEl = document.getElementById("cinemaDoneChip");
    const voiceStageView = document.getElementById("cinemaVoiceView");
    const duelStageView = document.getElementById("cinemaDuelView");
    const duelStepEls = Array.from(document.querySelectorAll("[data-duel-step]"));
    const duelPairTitleEl = document.getElementById("cinemaDuelPairTitle");

    // SVG Overlays on Cat Stage
    const svgTypingBubble = document.getElementById("svgCatTypingBubble");
    const svgDuelBubble = document.getElementById("svgCatDuelBubble");
    const soundBtn = document.getElementById("petSoundToggle");
    const rgbBtn = document.getElementById("petRgbToggle");
    const musicBtn = document.getElementById("petMusicToggle");
    const breedBtns = Array.from(document.querySelectorAll("[data-pet-breed]"));

    // Director state
    let currentActIdx = 0;
    let actStartPerf = performance.now();
    let lastFiredKeySlot = -1;
    let renderedActSignature = "";

    function syncControlUI() {
      breedBtns.forEach((btn) => {
        const active = btn.dataset.petBreed === settings.breed;
        btn.classList.toggle("is-active", active);
        btn.setAttribute("aria-pressed", String(active));
      });
      if (soundBtn) {
        soundBtn.classList.toggle("is-on", audio.enabled);
        soundBtn.textContent = audio.enabled ? "🔊 原声已开" : "🔈 开启原声";
      }
      if (rgbBtn) {
        rgbBtn.classList.toggle("is-on", settings.rgbGlow);
        rgbBtn.textContent = settings.rgbGlow ? "✨ 键盘闪光：开" : "🌙 键盘闪光：关";
      }
      if (musicBtn) {
        musicBtn.classList.toggle("is-on", settings.musicMode);
        musicBtn.textContent = settings.musicMode ? "🎧 听歌耳机：开" : "🎧 戴上耳机";
      }
    }

    function autoEnableSoundOnGesture() {
      if (!userMutedExplicitly && !audio.enabled) {
        audio.enabled = true;
        audio.warmup();
        syncControlUI();
      } else if (audio.enabled) {
        audio.ensureContext();
      }
    }

    function renderSpokenTemplate(act) {
      if (!spokenContainerEl || !act.segments) return;
      spokenContainerEl.innerHTML = act.segments
        .map((seg, i) => {
          if (seg.bug) {
            return `<span class="raw-seg is-bug" data-seg-idx="${i}"><span class="bug-txt">${seg.text}</span><svg class="strike-svg" viewBox="0 0 100 16" preserveAspectRatio="none" aria-hidden="true"><path d="M2 10 Q 50 5, 98 9" pathLength="1"/></svg></span>`;
          }
          return `<span class="raw-seg" data-seg-idx="${i}">${seg.text}</span>`;
        })
        .join("");

      if (magicBadgesEl) {
        magicBadgesEl.innerHTML = act.badges
          .map((b) => `<span class="cinema-fix-pill">${b}</span>`)
          .join("");
      }
    }

    function startAct(idx, options = {}) {
      currentActIdx = ((idx % CINEMA_ACTS.length) + CINEMA_ACTS.length) % CINEMA_ACTS.length;
      actStartPerf = performance.now();
      lastFiredKeySlot = -1;
      const act = CINEMA_ACTS[currentActIdx];

      actBtns.forEach((b, i) => {
        const active = i === currentActIdx;
        b.classList.toggle("is-active", active);
        b.setAttribute("aria-selected", String(active));
        b.style.setProperty("--act-progress", active ? "0%" : "0%");
      });

      if (act.isDuelAct) {
        if (voiceStageView) voiceStageView.hidden = true;
        if (duelStageView) duelStageView.hidden = false;
        if (appBadgeEl) appBadgeEl.textContent = act.appBadge;

        const prevBreed = handover ? handover.to : settings.breed;
        const targetBreed = options.targetBreed && options.targetBreed !== prevBreed
          ? options.targetBreed
          : BREED_ORDER[(BREED_ORDER.indexOf(prevBreed) + 1) % BREED_ORDER.length];

        settings.breed = targetBreed;
        syncControlUI();

        if (duelPairTitleEl) {
          duelPairTitleEl.textContent = `${BREEDS[prevBreed].label} ⇄ ${BREEDS[targetBreed].label}`;
        }

        if (!settings.reducedMotion) {
          handover = {
            from: prevBreed,
            to: targetBreed,
            startPerfMs: actStartPerf
          };
        } else {
          handover = null;
        }
      } else {
        if (handover) {
          handover = null;
          audio.syncDuel(null, actStartPerf);
        }
        if (voiceStageView) voiceStageView.hidden = false;
        if (duelStageView) duelStageView.hidden = true;

        if (appBadgeEl) appBadgeEl.textContent = act.appBadge;
        if (capsuleLatencyEl) capsuleLatencyEl.textContent = act.latencyText;
        const sig = act.id;
        if (renderedActSignature !== sig) {
          renderSpokenTemplate(act);
          renderedActSignature = sig;
        } else {
          renderSpokenTemplate(act);
        }
      }
    }

    function updateDirectorTimeline(nowPerf) {
      const act = CINEMA_ACTS[currentActIdx];
      const elapsed = nowPerf - actStartPerf;

      if (settings.reducedMotion) {
        // Static crystal-clear state when reduced motion is active
        if (!act.isDuelAct) {
          spokenContainerEl?.querySelectorAll(".raw-seg").forEach((el) => {
            el.classList.add("is-visible", "is-struck");
          });
          magicBadgesEl?.classList.add("is-lit");
          if (polishedBoxEl) polishedBoxEl.textContent = act.polished;
          if (doneChipEl) doneChipEl.classList.add("is-visible");
          if (capsuleStatusEl) capsuleStatusEl.textContent = "已整理直出";
        }
        if (svgTypingBubble) svgTypingBubble.classList.remove("is-visible");
        if (svgDuelBubble) svgDuelBubble.classList.remove("is-visible");
        return;
      }

      if (elapsed >= act.durationMs) {
        startAct((currentActIdx + 1) % CINEMA_ACTS.length);
        return;
      }

      const progressPct = Math.min(100, (elapsed / act.durationMs) * 100);
      const activeBtn = actBtns[currentActIdx];
      if (activeBtn) {
        activeBtn.style.setProperty("--act-progress", `${progressPct.toFixed(1)}%`);
      }

      if (act.isDuelAct) {
        if (capsulePillEl) capsulePillEl.classList.remove("is-speaking");
        if (capsuleStatusEl) capsuleStatusEl.textContent = "桌面搭子 · 交接班小剧场";
        if (capsuleLatencyEl) capsuleLatencyEl.textContent = "10.5s 实况";
        waveBars.forEach((bar) => {
          bar.setAttribute("y", "11");
          bar.setAttribute("height", "4");
        });
        if (svgTypingBubble) svgTypingBubble.classList.remove("is-visible");
        return;
      }

      // Voice + Bug-Catching + Cat Clacking Act Timeline (0 ~ 6000ms)
      // 0 ~ 2100ms: User speaking into mic (waveform bouncing + raw segments appear)
      // 1750 ~ 2500ms: Red SVG pen strikes out filler/self-correction bugs + badges light up!
      // 1950 ~ 4350ms: Cat furiously clacks keys + polished text streams into app cursor!
      // 4350 ~ 6000ms: Clean finished output held clearly for reading before next act!
      const isSpeaking = elapsed < 2250;
      const isStriking = elapsed >= 1700;
      const isStreaming = elapsed >= 1900 && elapsed < 4400;
      const isFinished = elapsed >= 4300;

      if (capsulePillEl) capsulePillEl.classList.toggle("is-speaking", isSpeaking);
      if (capsuleStatusEl) {
        capsuleStatusEl.textContent = isSpeaking
          ? "🎙️ 正在按住说话…"
          : isStreaming
            ? "⚡ 极速捉错直出中"
            : "✅ 已直出漂亮终稿";
      }

      // Animate 14 SVG waveform bars smoothly
      waveBars.forEach((bar, i) => {
        if (isSpeaking) {
          const v = Math.abs(Math.sin(nowPerf * 0.012 + i * 0.65)) * 0.65 + Math.abs(Math.cos(nowPerf * 0.019 - i * 0.4)) * 0.35;
          const h = Math.round(4 + v * 17);
          const y = Math.round(13 - h / 2);
          bar.setAttribute("y", String(y));
          bar.setAttribute("height", String(h));
        } else {
          bar.setAttribute("y", "11");
          bar.setAttribute("height", "4");
        }
      });

      // Reveal raw spoken segments progressively (0 ~ 1650ms)
      if (spokenContainerEl) {
        const segEls = spokenContainerEl.querySelectorAll(".raw-seg");
        const count = segEls.length || 1;
        segEls.forEach((el, idx) => {
          const threshold = (idx / count) * 1450;
          el.classList.toggle("is-visible", elapsed >= threshold);
          if (el.classList.contains("is-bug")) {
            el.classList.toggle("is-struck", isStriking);
          }
        });
      }

      if (magicBadgesEl) {
        magicBadgesEl.classList.toggle("is-lit", isStriking);
      }
      if (flowLineEl) {
        flowLineEl.classList.toggle("is-flowing", elapsed >= 1650 && elapsed < 4500);
      }

      // Stream polished text & trigger synchronized cat clacking!
      if (polishedBoxEl) {
        if (elapsed < 1900) {
          polishedBoxEl.textContent = "";
        } else {
          const streamFrac = clamp01Range(elapsed, 1900, 4250);
          const chars = Math.round(streamFrac * act.polished.length);
          polishedBoxEl.textContent = act.polished.slice(0, chars);
        }
      }
      if (doneChipEl) {
        doneChipEl.classList.toggle("is-visible", isFinished);
      }

      // Trigger synchronized cat keycap clacks every ~78ms during streaming window
      if (isStreaming) {
        const slot = Math.floor((elapsed - 1900) / 78);
        if (slot !== lastFiredKeySlot && slot < act.keys.length) {
          lastFiredKeySlot = slot;
          sim.tapKey(act.keys[slot], 62);
          audio.playKey(false);
        }
      }

      if (svgTypingBubble) {
        svgTypingBubble.classList.toggle("is-visible", isStreaming);
      }
      if (svgDuelBubble) {
        svgDuelBubble.classList.remove("is-visible");
      }
    }

    // Bind Act Tab Buttons
    actBtns.forEach((btn, idx) => {
      btn.addEventListener("click", () => {
        autoEnableSoundOnGesture();
        startAct(idx);
      });
    });

    // Bind Breed Switcher Pills -> immediately jump to Act 3 Duel with chosen cat!
    breedBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const chosen = btn.dataset.petBreed;
        autoEnableSoundOnGesture();
        startAct(2, { targetBreed: chosen });
      });
    });

    if (soundBtn) {
      soundBtn.addEventListener("click", () => {
        audio.enabled = !audio.enabled;
        userMutedExplicitly = !audio.enabled;
        if (audio.enabled) {
          audio.warmup();
          sim.tapKey("KeyK", 70);
          audio.playKey(false);
        } else {
          audio.syncDuel(null, performance.now());
        }
        syncControlUI();
      });
    }

    if (rgbBtn) {
      rgbBtn.addEventListener("click", () => {
        settings.rgbGlow = !settings.rgbGlow;
        syncControlUI();
      });
    }

    if (musicBtn) {
      musicBtn.addEventListener("click", () => {
        settings.musicMode = !settings.musicMode;
        syncControlUI();
      });
    }

    // Story cards below hero jump up & play the exact scene!
    document.querySelectorAll("[data-pet-trigger]").forEach((el) => {
      el.addEventListener("click", () => {
        const action = el.dataset.petTrigger;
        const heroCinema = document.getElementById("heroCinema");
        if (heroCinema) {
          heroCinema.scrollIntoView({ behavior: settings.reducedMotion ? "auto" : "smooth", block: "center" });
        }
        setTimeout(() => {
          if (action === "voice") {
            autoEnableSoundOnGesture();
            startAct(0);
          } else if (action === "duel") {
            autoEnableSoundOnGesture();
            startAct(2);
          } else if (action === "rgb-off") {
            settings.rgbGlow = !settings.rgbGlow;
            audio.tone = audio.tone === "clear" ? "blue" : "clear";
            autoEnableSoundOnGesture();
            sim.tapKey("KeyT", 75);
            audio.playKey(false);
            syncControlUI();
          } else if (action === "music") {
            settings.musicMode = true;
            syncControlUI();
          }
        }, settings.reducedMotion ? 0 : 260);
      });
    });

    // Pointer interaction on cat canvas
    canvas.addEventListener("pointermove", (e) => {
      const rect = canvas.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      const sx = ((e.clientX - rect.left) / rect.width) * STAGE.width;
      const sy = ((e.clientY - rect.top) / rect.height) * STAGE.height;
      sim.moveMouse(sx, sy, false);
    });

    canvas.addEventListener("pointerdown", (e) => {
      const rect = canvas.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      const sx = ((e.clientX - rect.left) / rect.width) * STAGE.width;
      const sy = ((e.clientY - rect.top) / rect.height) * STAGE.height;
      const loc = stageToLogical({ x: sx, y: sy }, 1);
      if (loc.y > 315 && loc.x > 115) {
        const sample = ["KeyC", "KeyA", "KeyT", "KeyL", "KeyO", "KeyV", "KeyE", "Digit2", "Enter"];
        const pick = sample[Math.floor(Math.random() * sample.length)];
        sim.tapKey(pick, 85);
        audio.playKey(false);
      } else {
        sim.moveMouse(sx, sy, true);
        audio.playKey(true);
      }
    });

    window.addEventListener("keydown", (e) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const tag = document.activeElement?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;
      if (KEY_BY_CODE.has(e.code)) {
        sim.tapKey(e.code, 90);
        audio.playKey(false);
      }
    });

    window.addEventListener("resize", () => renderer.resize(), { passive: true });

    // Start Act 1 immediately!
    syncControlUI();
    startAct(0);

    let lastPerf = performance.now();
    function tick(nowPerf) {
      settings.reducedMotion = Boolean(window.tzMotionPaused) || window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      const dt = Math.min(0.06, Math.max(0.001, (nowPerf - lastPerf) / 1000));
      lastPerf = nowPerf;

      updateDirectorTimeline(nowPerf);

      const nowMs = Date.now();
      const pose = sim.step(dt, nowMs);

      let hFrame = null;
      if (handover) {
        const elapsed = nowPerf - handover.startPerfMs;
        if (elapsed < HANDOVER_TIMING.end) {
          hFrame = computeHandoverState(handover.from, handover.to, elapsed, 1);
          pose.bubbles.length = 0;
          audio.syncDuel(handover.startPerfMs + HANDOVER_TIMING.braceEnd, nowPerf);
          if (svgDuelBubble) {
            svgDuelBubble.classList.toggle("is-visible", hFrame.isHeadbuttPeak);
          }
          duelStepEls.forEach((stepEl) => {
            const stepNum = Number(stepEl.dataset.duelStep);
            stepEl.classList.toggle("is-active", stepNum === hFrame.duelStep);
            stepEl.classList.toggle("is-done", stepNum < hFrame.duelStep);
          });
        } else {
          handover = null;
          audio.syncDuel(null, nowPerf);
          if (svgDuelBubble) svgDuelBubble.classList.remove("is-visible");
        }
      } else {
        audio.syncDuel(null, nowPerf);
      }

      renderer.render(pose, settings, nowMs, hFrame, sim.anger);
      requestAnimationFrame(tick);
    }

    requestAnimationFrame(tick);

    return {
      startAct,
      setMotionPaused(paused) {
        settings.reducedMotion = paused;
        if (paused && handover) {
          handover = null;
          audio.syncDuel(null, performance.now());
        } else if (!paused) {
          startAct(currentActIdx);
        }
      }
    };
  }

  window.TypeZeroPetStage = { init: initPetStage };
})();
