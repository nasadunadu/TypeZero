cask "typezero" do
  version "0.5.3"
  sha256 "49ece100d7728c2a228781a2c3fb323c7f59094e113573d6fca8e92bd1297c6e"

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
