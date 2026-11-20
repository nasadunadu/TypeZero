import Foundation
import CoreAudio
import AudioToolbox

/// Thread-safe, zero-permission macOS CoreAudio output muter for dictation sessions.
/// - Mutes the current default system output device in <1ms when dictation starts so speakers /
///   videos / music never bleed into the microphone.
/// - Respects existing user mute state: if the user already muted their Mac, `restoreIfNeeded()`
///   never unmutes it.
/// - Supports both hardware `kAudioDevicePropertyMute` and fallback volume ducking for USB DACs
///   that omit a master mute property.
public final class SystemAudioDucker: @unchecked Sendable {
    private let lock = NSLock()
    private var didAutoMute: Bool = false
    private var mutedDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var usedVolumeFallback: Bool = false
    private var savedVolumeScalar: Float32 = 0.0

    public init() {}

    deinit {
        restoreIfNeeded()
    }

    public func muteIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didAutoMute else { return }

        let deviceID = Self.defaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        // Path 1: Standard hardware mute property (works on built-in speakers, AirPods, Bluetooth, most USB audio)
        if let currentMute = Self.getMuteState(deviceID: deviceID) {
            if currentMute != 0 {
                // Already muted by user — do nothing and never unmute later!
                return
            }
            if Self.setMuteState(deviceID: deviceID, muted: true) {
                didAutoMute = true
                mutedDeviceID = deviceID
                usedVolumeFallback = false
                return
            }
        }

        // Path 2: Fallback for rare USB DACs / HDMI monitors without a mute property — duck virtual main volume to 0
        if let currentVol = Self.getVirtualMainVolume(deviceID: deviceID), currentVol > 0.001 {
            if Self.setVirtualMainVolume(deviceID: deviceID, volume: 0.0) {
                didAutoMute = true
                mutedDeviceID = deviceID
                usedVolumeFallback = true
                savedVolumeScalar = currentVol
            }
        }
    }

    public func restoreIfNeeded() {
        lock.lock()
        guard didAutoMute else {
            lock.unlock()
            return
        }
        let devID = mutedDeviceID
        let fallback = usedVolumeFallback
        let prevVol = savedVolumeScalar
        didAutoMute = false
        mutedDeviceID = kAudioObjectUnknown
        usedVolumeFallback = false
        savedVolumeScalar = 0.0
        lock.unlock()

        guard devID != kAudioObjectUnknown else { return }
        if fallback {
            _ = Self.setVirtualMainVolume(deviceID: devID, volume: prevVol)
        } else {
            _ = Self.setMuteState(deviceID: devID, muted: false)
        }
    }

    // MARK: - CoreAudio Property Helpers

    private static func defaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : AudioDeviceID(kAudioObjectUnknown)
    }

    private static func mutePropertyAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private static func getMuteState(deviceID: AudioDeviceID) -> UInt32? {
        for elem: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1] {
            var addr = mutePropertyAddress(element: elem)
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr {
                return muted
            }
        }
        return nil
    }

    private static func setMuteState(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        for elem: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1] {
            var addr = mutePropertyAddress(element: elem)
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr, settable.boolValue else { continue }
            if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &value) == noErr {
                return true
            }
        }
        return false
    }

    private static func getVirtualMainVolume(deviceID: AudioDeviceID) -> Float32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume) == noErr ? volume : nil
    }

    private static func setVirtualMainVolume(deviceID: AudioDeviceID, volume: Float32) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr, settable.boolValue else { return false }
        var v = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &v) == noErr
    }
}
