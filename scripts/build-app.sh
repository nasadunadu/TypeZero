#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="TypeZero"
VERSION="0.4.2"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ENTITLEMENTS_FILE="$ROOT_DIR/Resources/TypeZero.entitlements"
SHERPA_LIB_DIR="$ROOT_DIR/Vendor/sherpa-onnx-v1.13.8-osx-arm64-shared-no-tts-lib/lib"

if [ ! -d "$SHERPA_LIB_DIR" ]; then
    echo "==> Fetching sherpa-onnx runtime first..."
    "$ROOT_DIR/scripts/setup-vendor.sh"
fi

echo "==> Building ${APP_NAME} v${VERSION} with SenseVoice-Small native C++ runtime..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$BIN_PATH" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"

# Embed sherpa-onnx & onnxruntime dylibs inside Contents/Frameworks
cp -f "$SHERPA_LIB_DIR/libsherpa-onnx-c-api.dylib" "$FRAMEWORKS_DIR/"
cp -f "$SHERPA_LIB_DIR/libonnxruntime.dylib" "$FRAMEWORKS_DIR/"
chmod 755 "$FRAMEWORKS_DIR/libsherpa-onnx-c-api.dylib" "$FRAMEWORKS_DIR/libonnxruntime.dylib"

ICONSET_TMP="$(mktemp -d -t typezero_iconset).iconset"
mkdir -p "$ICONSET_TMP"
swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICONSET_TMP"
iconutil -c icns "$ICONSET_TMP" -o "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/trash "$ICONSET_TMP" 2>/dev/null || mv "$ICONSET_TMP" ~/.Trash/ 2>/dev/null || true

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.typezero.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>TypeZero</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>8</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>TypeZero 需要访问麦克风以通过本地 SenseVoice-Small 模型实时语音转文字。</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>TypeZero 备用系统语音识别权限。</string>
</dict>
</plist>
EOF

SIGN_HASH="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ {print $2; exit}')"
if [ -z "$SIGN_HASH" ]; then
    SIGN_HASH="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development:/ {print $2; exit}')"
fi

if [ -n "$SIGN_HASH" ]; then
    # Sign embedded dylibs first with identical TeamID + secure Apple timestamp so Notarization & Hardened Runtime succeed!
    codesign --force --timestamp --options runtime --sign "$SIGN_HASH" "$FRAMEWORKS_DIR/libonnxruntime.dylib"
    codesign --force --timestamp --options runtime --sign "$SIGN_HASH" "$FRAMEWORKS_DIR/libsherpa-onnx-c-api.dylib"
    codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS_FILE" --sign "$SIGN_HASH" "$APP_BUNDLE"
    echo "==> Signed ${APP_NAME}.app + SenseVoice dylibs with Developer certificate & secure timestamp"
else
    codesign --force --sign - "$FRAMEWORKS_DIR/libonnxruntime.dylib"
    codesign --force --sign - "$FRAMEWORKS_DIR/libsherpa-onnx-c-api.dylib"
    codesign --force --entitlements "$ENTITLEMENTS_FILE" --sign - "$APP_BUNDLE"
    echo "==> Signed ${APP_NAME}.app with ad-hoc signature"
fi
