# Security & Privacy Policy

## Privacy Architecture

- **BYOK (Bring Your Own Key)**: All API keys (`Volcengine Seed-ASR`, `DeepSeek`, `Volcengine Ark`, `Alibaba DashScope`, or custom OpenAI-compatible endpoints) are stored exclusively in your **macOS System Keychain (`SecItem`)** under isolated per-provider slots and are never transmitted to any third-party TypeZero server.
- **100% Local Personal Lexicon & History**: Your personal dictionary (`lexicon.json`) and dictation history (`history.json`) reside solely in `~/Library/Application Support/TypeZero/`.
- **Optional 100% Offline Mode**: Selecting **Local SenseVoice FP32** + **Verbatim Output** (or a local **Ollama / LM Studio** endpoint) guarantees zero external network traffic.
- **Clipboard Snapshot Safety**: When injecting polished text via clipboard paste, TypeZero snapshots your existing clipboard items and restores them immediately after paste.

## Reporting a Vulnerability

If you discover a security or privacy issue, please open a private security advisory via GitHub Security Advisories or report it directly to the maintainers rather than posting exploit details publicly.
