# TypeZero for Windows (v0.5.0)

**纯原生 Rust + Win32 + Tauri v2 打造的 Windows 10/11 超低延迟 AI 语音成稿与结构化排版工具**

## 普通 Windows 用户安装与使用

1. **一键安装（推荐）**：下载 **`TypeZero-v0.5.0-Windows-x64-setup.exe`** 双击安装（无需管理员权限，自动创建桌面快捷方式，Windows 10/11 内置 WebView2 零额外依赖）。
   - 若首次运行弹出 Windows SmartScreen 蓝色提示框（开源项目暂未购买商业签名证书），点击 **「更多信息」→「仍要运行」** 即可。
2. **绿色便携版**：也可直接下载 **`TypeZero-v0.5.0-Windows-x64-portable.zip`** 解压即用。
3. **60 秒上手**：
   - 确认麦克风已连接（Windows 版免 macOS 辅助功能繁琐授权，开箱即用）。
   - 粘贴 **豆包 Seed-ASR 2.0** 或 **OpenAI / Groq** 语音 Key（或一键后台下载 **886MB SenseVoice FP32** 离线满血模型）与排版大模型 Key（推荐 **DeepSeek 4 Flash**，所有密钥均加密存于 **Windows 凭据管理器**）。
   - 在任意软件（微信 / 飞书 / 钉钉 / QQ / Word / WPS / Chrome / Edge / VS Code / Cursor）聚焦输入框，按一下 **`右侧 Alt`** 开始说话，再按一下瞬间结构化上屏；录音中按 **`Esc`** 一键取消。

## Windows 原生工程特性

- **零焦点悬浮音波胶囊**：原生 Win32 `WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_TRANSPARENT` 透明窗 + 3 级智能光标锚定（`GetGUIThreadInfo` → UI Automation → 窗口底中，自动避开任务栏），绝不抢夺焦点。
- **全局低级快捷键防误触**：`WH_KEYBOARD_LL` 精准区分左右修饰键；单独点按 `右 Alt` 自动屏蔽 Windows 菜单栏误激活；左侧键在按住模式下内置 `140ms` 防误触保护（`Ctrl+C`/`Alt+Tab` 零干扰）。
- **全场景多行安全粘贴**：剪贴板快照无损原子粘贴（`Ctrl+V`，终端自动切换 `Shift+Insert`），微信/飞书/QQ 多行自动框内换行不误发，粘贴后自动还原原剪贴板。
- **听写自动静音外放**：基于 Windows Core Audio `IAudioEndpointVolume`，开口自动静音、松手瞬间还原。
- **右下角托盘常驻 & 开机自启**：点右上角 × 自动隐藏到系统托盘，支持一键开启登录自启。

## 从源码构建（Windows 10/11 x64）

环境要求：Rust 1.78+ (MSVC)、Node.js 20+、`pnpm` 10+。

```powershell
cd windows
pnpm install
pnpm build
cargo test --manifest-path src-tauri/Cargo.toml
./scripts/fetch-sherpa-win64.ps1
pnpm tauri build --bundles nsis
```

也可在 GitHub 仓库的 **Actions → Build TypeZero Windows (x64) → Run workflow** 一键云端自动编译出 `.exe` 安装包与 `.zip` 便携版。
