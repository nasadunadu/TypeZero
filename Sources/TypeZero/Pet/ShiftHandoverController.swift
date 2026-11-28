import Foundation
import AppKit
import AVFoundation

// MARK: - Low-Latency Polyphonic Mechanical Switch, Mouse & Shift-Handover Audio Engine

final class PetAudioBank {
    static let shared = PetAudioBank()

    private final class SamplePool {
        private var players: [AVAudioPlayer] = []
        private var cursor: Int = 0

        init?(wavData: Data, poolSize: Int = 8) {
            var built: [AVAudioPlayer] = []
            built.reserveCapacity(poolSize)
            for _ in 0..<poolSize {
                if let p = try? AVAudioPlayer(data: wavData) {
                    p.prepareToPlay()
                    built.append(p)
                }
            }
            guard !built.isEmpty else { return nil }
            self.players = built
        }

        func play(volume: Float) {
            guard !players.isEmpty, volume > 0.001 else { return }
            let p = players[cursor % players.count]
            cursor = (cursor + 1) % players.count
            if p.isPlaying {
                p.stop()
            }
            p.currentTime = 0
            p.volume = min(1.0, max(0.0, volume))
            p.play()
        }

        func stopAll() {
            for p in players where p.isPlaying {
                p.stop()
                p.currentTime = 0
            }
        }
    }

    private static let bickerClipNames = [
        "cat_bicker_01",
        "cat_bicker_02",
        "cat_bicker_03",
        "cat_bicker_04"
    ]

    private var keyboardPools: [PetKeyboardTone: SamplePool] = [:]
    private var mousePools: [PetMouseTone: SamplePool] = [:]
    private var duelLaoWuURL: URL?
    private var bickerURLs: [URL] = []
    private var bickerCursor: Int = 0
    private var duelPlayer: AVAudioPlayer?
    private(set) var lastOwnAudioDeadline: CFTimeInterval = 0

    private init() {
        reloadAssets()
    }

    func reloadAssets() {
        if keyboardPools.isEmpty {
            if let url = Self.locateResource(name: "kb_mx_clear", ext: "wav"),
               let data = try? Data(contentsOf: url),
               let pool = SamplePool(wavData: data) {
                keyboardPools[.mxClear] = pool
            }
            if let url = Self.locateResource(name: "kb_mx_blue", ext: "wav"),
               let data = try? Data(contentsOf: url),
               let pool = SamplePool(wavData: data) {
                keyboardPools[.mxBlue] = pool
            }
        }
        if mousePools.isEmpty {
            if let url = Self.locateResource(name: "mouse_crisp", ext: "wav"),
               let data = try? Data(contentsOf: url),
               let pool = SamplePool(wavData: data) {
                mousePools[.crisp] = pool
            }
            if let url = Self.locateResource(name: "mouse_g502", ext: "wav"),
               let data = try? Data(contentsOf: url),
               let pool = SamplePool(wavData: data) {
                mousePools[.g502] = pool
            }
        }
        if duelLaoWuURL == nil {
            duelLaoWuURL = Self.locateResource(name: "clack_duel", ext: "m4a")
        }
        if bickerURLs.isEmpty {
            bickerURLs = Self.bickerClipNames.compactMap { Self.locateResource(name: $0, ext: "m4a") }
        }
    }

    /// Used by `PetCompanionController.pollMusicStateIfNeeded` so our own keyboard clicks or duel audio
    /// never falsely trigger "sustained external music -> put on headphones".
    var isRecentlyPlayingOwnSound: Bool {
        CACurrentMediaTime() < lastOwnAudioDeadline
    }

    var availableClipCount: Int {
        reloadAssets()
        return (duelLaoWuURL != nil ? 1 : 0) + bickerURLs.count
    }

    var hasAllSwitchSamples: Bool {
        reloadAssets()
        return keyboardPools[.mxClear] != nil
            && keyboardPools[.mxBlue] != nil
            && mousePools[.crisp] != nil
            && mousePools[.g502] != nil
            && duelLaoWuURL != nil
    }

    func playKeyboardClick(isVoice: Bool = false) {
        let s = CatSettings.shared
        guard s.keyboardSound, !s.pauseInputSync, !s.isEffectivePrivacyActive else { return }
        if isVoice && !s.voiceTypingSound { return }
        let vol = Float(s.keyboardVolume) / 100.0
        guard vol > 0.005 else { return }
        reloadAssets()
        keyboardPools[s.keyboardTone]?.play(volume: vol)
        lastOwnAudioDeadline = max(lastOwnAudioDeadline, CACurrentMediaTime() + 0.35)
    }

    func playMouseClick() {
        let s = CatSettings.shared
        guard s.mouseSound, !s.pauseInputSync, !s.isEffectivePrivacyActive else { return }
        let vol = Float(s.mouseVolume) / 100.0
        guard vol > 0.005 else { return }
        reloadAssets()
        mousePools[s.mouseTone]?.play(volume: vol)
        lastOwnAudioDeadline = max(lastOwnAudioDeadline, CACurrentMediaTime() + 0.35)
    }

    func playHandoverDuelSound() {
        let s = CatSettings.shared
        guard s.enableHandoverSound else { return }
        let vol = Float(s.duelVolume) / 100.0
        guard vol > 0.005 else { return }
        playDuelClip(style: s.duelVoiceStyle, volume: vol)
    }

    func previewKeyboardTone(_ tone: PetKeyboardTone, volume: Int) {
        reloadAssets()
        let vol = max(0.08, Float(volume) / 100.0)
        keyboardPools[tone]?.play(volume: vol)
        lastOwnAudioDeadline = max(lastOwnAudioDeadline, CACurrentMediaTime() + 0.35)
    }

    func previewMouseTone(_ tone: PetMouseTone, volume: Int) {
        reloadAssets()
        let vol = max(0.08, Float(volume) / 100.0)
        mousePools[tone]?.play(volume: vol)
        lastOwnAudioDeadline = max(lastOwnAudioDeadline, CACurrentMediaTime() + 0.35)
    }

    func previewDuelVoice(_ style: PetDuelVoiceStyle, volume: Int) {
        let vol = max(0.10, Float(volume) / 100.0)
        playDuelClip(style: style, volume: vol)
    }

    func stopAll() {
        for pool in keyboardPools.values { pool.stopAll() }
        for pool in mousePools.values { pool.stopAll() }
        if duelPlayer?.isPlaying == true {
            duelPlayer?.stop()
        }
        duelPlayer = nil
    }

    private func playDuelClip(style: PetDuelVoiceStyle, volume: Float) {
        reloadAssets()
        let chosenURL: URL?
        switch style {
        case .clackLaoWu:
            chosenURL = duelLaoWuURL ?? bickerURLs.first
        case .douyinBicker:
            if !bickerURLs.isEmpty {
                chosenURL = bickerURLs[bickerCursor % bickerURLs.count]
                bickerCursor += 1
            } else {
                chosenURL = duelLaoWuURL
            }
        }
        guard let url = chosenURL else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = min(1.0, max(0.0, volume))
            p.prepareToPlay()
            p.play()
            duelPlayer = p
            lastOwnAudioDeadline = max(lastOwnAudioDeadline, CACurrentMediaTime() + max(0.5, p.duration + 0.25))
        } catch {
            // Non-fatal if output audio device is unavailable
        }
    }

    private static func locateResource(name: String, ext: String) -> URL? {
        if let bundled = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "PetAudio") {
            return bundled
        }
        if let flat = Bundle.main.url(forResource: name, withExtension: ext) {
            return flat
        }
        let cwd = FileManager.default.currentDirectoryPath
        let devPath = (cwd as NSString).appendingPathComponent("Resources/PetAudio/\(name).\(ext)")
        if FileManager.default.fileExists(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }
        let execDir = (Bundle.main.executablePath as NSString?)?.deletingLastPathComponent ?? ""
        if !execDir.isEmpty {
            let siblingRes = (execDir as NSString).appendingPathComponent("../Resources/PetAudio/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: siblingRes) {
                return URL(fileURLWithPath: siblingRes)
            }
        }
        return nil
    }
}

// MARK: - Subtle Wireless Cloud-Dictation Aura Pill for KuroCat Mode

enum ShiftHandoverRenderer {
    static func drawCloudVoiceAura(in ctx: CGContext, physics: CatPhysics, skin: SkinSpec) {
        let headCenter = CatRenderer.headPosition(physics, skin: skin)
        let pulse = 0.5 + 0.5 * sin(physics.time * 6.4)
        let badgeCenter = CGPoint(x: headCenter.x + 42 * skin.shape.headScale, y: headCenter.y - 34 * skin.shape.headScale)

        ctx.saveGState()
        let pillRect = CGRect(x: badgeCenter.x - 16, y: badgeCenter.y - 10, width: 32, height: 20)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.setShadow(offset: .zero, blur: 8, color: NSColor(calibratedRed: 0.38, green: 0.34, blue: 0.98, alpha: 0.55).cgColor)
        ctx.setFillColor(NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.18, alpha: 0.88).cgColor)
        ctx.addPath(pillPath)
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.52, green: 0.48, blue: 1.0, alpha: 0.72).cgColor)
        ctx.setLineWidth(1.1)
        ctx.addPath(pillPath)
        ctx.strokePath()

        let heights: [CGFloat] = [
            5.0 + 6.0 * abs(sin(physics.time * 9.5)),
            7.0 + 7.5 * pulse,
            4.5 + 6.5 * abs(cos(physics.time * 8.2))
        ]
        ctx.setFillColor(NSColor(calibratedRed: 0.78, green: 0.95, blue: 0.28, alpha: 0.96).cgColor)
        for i in 0..<3 {
            let bh = heights[i]
            let bx = badgeCenter.x - 7.5 + CGFloat(i) * 6.0
            let bar = CGRect(x: bx, y: badgeCenter.y - bh * 0.5, width: 3.0, height: bh)
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            ctx.fillPath()
        }
        ctx.restoreGState()
    }
}
