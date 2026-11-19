cask "typezero" do
  version "0.4.1"
  sha256 "bbf61a557d6d0a4b6d2a20db8127d7ad37d71b25e189fb4dfd1c5d04f5a831bd"

  url "https://github.com/nasadunadu/TypeZero/releases/download/v#{version}/TypeZero-v#{version}-macOS-arm64.dmg"
  name "TypeZero"
  desc "Ultra-low-latency native macOS AI voice dictation with Seed-ASR 2.0 + offline SenseVoice FP32 failover"
  homepage "https://github.com/nasadunadu/TypeZero"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "TypeZero.app"

  zap trash: [
    "~/Library/Application Support/TypeZero",
    "~/Library/Preferences/io.github.typezero.macos.plist",
  ]
end
