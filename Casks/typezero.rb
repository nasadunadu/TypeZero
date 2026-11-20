cask "typezero" do
  version "0.4.7"
  sha256 "a3c09bb79ef16649ba9c82be9818e4fe410b47e7d6ca14a608bf354d7be1ccb7"

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
