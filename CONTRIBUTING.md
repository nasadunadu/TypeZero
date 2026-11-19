# Contributing to TypeZero

Thank you for your interest in contributing to **TypeZero**!

## Development Prerequisites

- macOS 14.0+ on Apple Silicon (`arm64`)
- Xcode Command Line Tools (`swift --version` >= 5.10 / Swift 6)

## Local Setup & Testing

```bash
git clone https://github.com/nasadunadu/TypeZero.git
cd TypeZero

# 1. Fetch sherpa-onnx native macOS arm64 C runtime
./scripts/setup-vendor.sh

# 2. Build & run deterministic regression suite (33 assertions, 0 warnings expected)
./scripts/run-tests.sh

# 3. Build macOS .app bundle
./scripts/build-app.sh
open ./build/TypeZero.app
```

## Contribution Guidelines

1. **Zero Warnings & Passing Tests**: All PRs must compile cleanly under `swift build -c release` with zero warnings and pass `./scripts/run-tests.sh` (`100%` pass).
2. **Privacy First**: Never commit API keys, `.env` files, personal lexicon JSON files, or machine-specific paths.
3. **Pure Native macOS Performance**: Keep MainActor free of synchronous CoreAudio / Accessibility IPC blocking so the floating voice capsule remains silky smooth at 60–120Hz.
4. **Focused Pull Requests**: One clear feature or bug fix per PR, with corresponding deterministic assertions added in `Sources/TypeZero/Core/SelfTestSuite.swift`.
