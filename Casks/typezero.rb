cask "typezero" do
  version "0.4.10"
  sha256 "19ecad94a4b95f30a37de235a0f0cd5e978c0554f3b372845cf5666b7a46df6e"

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
