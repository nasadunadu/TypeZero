#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
MODEL_DIR="$HOME/Library/Application Support/TypeZero/Models"

mkdir -p "$VENDOR_DIR" "$MODEL_DIR"

if [ ! -d "$VENDOR_DIR/sherpa-onnx-v1.13.8-osx-arm64-shared-no-tts-lib" ]; then
    echo "==> Downloading sherpa-onnx v1.13.8 arm64 shared C runtime..."
    curl -L --fail -o "$VENDOR_DIR/sherpa-lib.tar.bz2" \
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-osx-arm64-shared-no-tts-lib.tar.bz2"
    tar -xjf "$VENDOR_DIR/sherpa-lib.tar.bz2" -C "$VENDOR_DIR/"
    /usr/bin/trash "$VENDOR_DIR/sherpa-lib.tar.bz2" 2>/dev/null || true
fi

if [ ! -f "$MODEL_DIR/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09/model.onnx" ]; then
    echo "==> Downloading Alibaba SenseVoice-Small Full-Precision FP32 (845MB)..."
    curl -L --fail --retry 3 -o "$MODEL_DIR/sensevoice-fp32.tar.bz2" \
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09.tar.bz2"
    tar -xjf "$MODEL_DIR/sensevoice-fp32.tar.bz2" -C "$MODEL_DIR/"
    /usr/bin/trash "$MODEL_DIR/sensevoice-fp32.tar.bz2" 2>/dev/null || true
fi

echo "==> SenseVoice-Small Full-Precision FP32 runtime and model ready."
