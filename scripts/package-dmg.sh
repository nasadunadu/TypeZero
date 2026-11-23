#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="TypeZero"
VERSION="0.5.7"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/${APP_NAME}-v${VERSION}-macOS-arm64.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
if [ -z "$NOTARY_PROFILE" ]; then
    for cand in ScreenCapture-Notary TypeZeroNotary; do
        if xcrun notarytool history --keychain-profile "$cand" >/dev/null 2>&1; then
            NOTARY_PROFILE="$cand"
            break
        fi
    done
    NOTARY_PROFILE="${NOTARY_PROFILE:-ScreenCapture-Notary}"
fi

echo "==> 1. Building & signing ${APP_NAME}.app v${VERSION}..."
"$ROOT_DIR/scripts/build-app.sh"
"$ROOT_DIR/build/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" --self-test

mkdir -p "$DIST_DIR"
STAGE_DIR="$(mktemp -d -t typezero_dmg_stage)"
trap '/usr/bin/trash "$STAGE_DIR" 2>/dev/null || true' EXIT

ditto "$ROOT_DIR/build/${APP_NAME}.app" "$STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/首次安装说明.txt" <<'EOF'
TypeZero (macOS 极速语音成稿工具) 快速安装指南
==============================================

1. 将「TypeZero.app」拖入右侧「Applications」文件夹；
2. 打开 TypeZero（若首次打开遇到 macOS 安全提示，前往「系统设置 → 隐私与安全性」底部点一次「仍要打开」，或在终端执行：xattr -cr /Applications/TypeZero.app）；
3. 按首次弹出的 3 步引导页：开启麦克风与辅助功能权限 -> 填入豆包语音与 DeepSeek 密钥 -> 选定快捷键即可在任意输入框开口成文。
EOF

if [ -f "$DMG_PATH" ]; then
    /usr/bin/trash "$DMG_PATH" 2>/dev/null || true
fi

echo "==> 2. Packaging compressed UDZO installer DMG..."
hdiutil create \
    -volname "${APP_NAME} v${VERSION}" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

SIGN_HASH="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ {print $2; exit}')"
if [ -n "$SIGN_HASH" ]; then
    codesign --force --timestamp --sign "$SIGN_HASH" "$DMG_PATH"
    echo "==> 3. Signed DMG with Developer ID certificate ($SIGN_HASH)"
fi

# Automatic Apple Cloud Notarization + Stapling (fail-fast unless ALLOW_UNNOTARIZED=1 for local test builds)
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "==> 4. Submitting DMG to Apple Notary Service (profile: $NOTARY_PROFILE)..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    echo "==> 5. Notarization & ticket stapling complete! Zero Gatekeeper warnings on any Mac."
elif [ "${ALLOW_UNNOTARIZED:-0}" = "1" ]; then
    echo "==> [Warn] ALLOW_UNNOTARIZED=1 set; skipping Apple Notarization for local test build."
else
    echo "==> [ERROR] Apple Notarization profile '$NOTARY_PROFILE' not found. Refusing to ship unnotarized DMG!" >&2
    echo "    Set ALLOW_UNNOTARIZED=1 only for local test builds." >&2
    exit 1
fi

ls -lh "$DMG_PATH"
