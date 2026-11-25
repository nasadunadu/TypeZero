cask "typezero" do
  version "0.6.0"
  sha256 "9bd60773f2bc0de6c1823e94ba52bccc13e05cd210a08bb8f103926fc419edf1"

  url "https://github.com/nasadunadu/TypeZero/releases/download/v#{version}/TypeZero-v#{version}-macOS-arm64.dmg"
  name "TypeZero"
  desc "Ultra-low-latency native macOS AI voice dictation with Seed-ASR 2.0, OpenAI/Groq ASR & offline SenseVoice FP32 failover"
  homepage "https://github.com/nasadunadu/TypeZero"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "TypeZero.app"

  zap trash: [
    "~/Library/Application Support/TypeZero",
    "~/Library/Preferences/io.github.typezero.macos.plist",
  ]
end
