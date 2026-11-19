#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/TypeZero"

DYLD_LIBRARY_PATH="$ROOT_DIR/Vendor/sherpa-onnx-v1.13.8-osx-arm64-shared-no-tts-lib/lib" \
    "$BIN_PATH" --self-test
