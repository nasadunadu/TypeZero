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
    private struct MutedDeviceSnapshot {
        let deviceID: AudioDeviceID
        let didSetHardwareMute: Bool
        let savedVirtualMainVolume: Float32?
        let savedChannelVolumes: [AudioObjectPropertyElement: Float32]
    }

    private let lock = NSLock()
    private var didAutoMute: Bool = false
    private var primarySnapshot: MutedDeviceSnapshot?
    private var secondarySnapshot: MutedDeviceSnapshot?
    private var sessionGeneration: UInt64 = 0

    public init() {}

    deinit {
        restoreIfNeeded(scheduleBluetoothRecheck: false)
    }

    /// Pure helper: chooses either Master mute (`0`) or ALL settable stereo output channels (`[1, 2]`),
    /// preventing half-muted USB/Bluetooth/HDMI interfaces where channel 2 was previously skipped.
    public static func muteElementsToUpdate(hasMainSettable: Bool, settableChannels: [AudioObjectPropertyElement]) -> [AudioObjectPropertyElement] {
        if hasMainSettable {
            return [kAudioObjectPropertyElementMain]
        }
        return settableChannels
    }

    /// Pure helper: Bluetooth AVRCP / USB / external audio devices frequently accept `kAudioDevicePropertyMute = 1`
    /// in CoreAudio HAL metadata while their firmware continues playing full-volume A2DP audio unless volume scalar
    /// (`VirtualMainVolume` / `kAudioDevicePropertyVolumeScalar`) is ALSO ducked to `0.0`!
    public static func shouldAlsoDuckVolumeScalar(outputTransport: UInt32, didSetHardwareMute: Bool) -> Bool {
        return !didSetHardwareMute || outputTransport != kAudioDeviceTransportTypeBuiltIn
    }

    /// Pure helper: returns deduplicated output devices to unmute (both the originally muted device AND the
    /// current default output device in case Bluetooth HFP<->A2DP or output routing changed during dictation).
    public static func devicesToRestore(mutedDeviceID: AudioDeviceID, currentDefaultDeviceID: AudioDeviceID) -> [AudioDeviceID] {
        var result: [AudioDeviceID] = []
        if mutedDeviceID != kAudioObjectUnknown {
            result.append(mutedDeviceID)
        }
        if currentDefaultDeviceID != kAudioObjectUnknown && currentDefaultDeviceID != mutedDeviceID {
            result.append(currentDefaultDeviceID)
        }
        return result
    }

    public func muteIfNeeded() {
        lock.lock()
        guard !didAutoMute else {
            lock.unlock()
            return
        }

        let deviceID = Self.defaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown,
              let snap = Self.silenceDevice(deviceID) else {
            lock.unlock()
            return
        }

        sessionGeneration &+= 1
        let gen = sessionGeneration
        didAutoMute = true
        primarySnapshot = snap
        secondarySnapshot = nil
        lock.unlock()

        // Closed-clamshell / Mac mini Bluetooth fallback guard:
        // If no Built-In mic exists and Bluetooth switches from A2DP (`deviceID`) to a separate HFP output
        // `AudioDeviceID` ~150–250ms into dictation, silence that newly activated HFP output device too!
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .milliseconds(240)) { [weak self] in
            guard let self else { return }
            let curID = Self.defaultOutputDeviceID()
            guard curID != kAudioObjectUnknown, curID != deviceID else { return }
            self.lock.lock()
            guard self.didAutoMute, self.sessionGeneration == gen, self.secondarySnapshot == nil else {
                self.lock.unlock()
                return
            }
            if let secondSnap = Self.silenceDevice(curID) {
                self.secondarySnapshot = secondSnap
            }
            self.lock.unlock()
        }
    }

    public func restoreIfNeeded(scheduleBluetoothRecheck: Bool = true) {
        lock.lock()
        guard didAutoMute else {
            lock.unlock()
            return
        }
        let primary = primarySnapshot
        let secondary = secondarySnapshot
        let gen = sessionGeneration
        didAutoMute = false
        primarySnapshot = nil
        secondarySnapshot = nil
        lock.unlock()

        Self.applyRestore(primary: primary, secondary: secondary)

        // When Bluetooth headphones switch back ~300–1100ms after teardown, CoreAudio can transiently drop
        // an early unmute/volume restore. Re-verify at +450ms and +1200ms ONLY if no new session started.
        if scheduleBluetoothRecheck {
            for delayMs in [450, 1200] {
                DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                    guard let self else { return }
                    self.lock.lock()
                    let stillSameSession = (!self.didAutoMute && self.sessionGeneration == gen)
                    self.lock.unlock()
                    guard stillSameSession else { return }
                    Self.applyRestoreIfStillSilenced(primary: primary, secondary: secondary)
                }
            }
        }
    }

    private static func silenceDevice(_ deviceID: AudioDeviceID) -> MutedDeviceSnapshot? {
        if let currentMute = getMuteState(deviceID: deviceID), currentMute != 0 {
            // Already muted by user — do nothing and never unmute later!
            return nil
        }

        let origVirtualVol = getVirtualMainVolume(deviceID: deviceID)
        let origChannelVols = getSettableChannelVolumes(deviceID: deviceID)

        if getMuteState(deviceID: deviceID) == nil {
            let maxVol = max(origVirtualVol ?? 0.0, origChannelVols.values.max() ?? 0.0)
            if maxVol <= 0.001 {
                // Already at 0 volume by user — do nothing and never raise volume later!
                return nil
            }
        }

        let didMute = setMuteState(deviceID: deviceID, muted: true)
        let transport = outputTransportType(deviceID: deviceID)

        var savedVirtual: Float32? = nil
        var savedChannels: [AudioObjectPropertyElement: Float32] = [:]

        if shouldAlsoDuckVolumeScalar(outputTransport: transport, didSetHardwareMute: didMute) {
            if let v = origVirtualVol, v > 0.001, setVirtualMainVolume(deviceID: deviceID, volume: 0.0) {
                savedVirtual = v
            }
            for (elem, vol) in origChannelVols where vol > 0.001 {
                if setChannelVolumeScalar(deviceID: deviceID, element: elem, volume: 0.0) {
                    savedChannels[elem] = vol
                }
            }
        }

        guard didMute || savedVirtual != nil || !savedChannels.isEmpty else {
            return nil
        }
        return MutedDeviceSnapshot(
            deviceID: deviceID,
            didSetHardwareMute: didMute,
            savedVirtualMainVolume: savedVirtual,
            savedChannelVolumes: savedChannels
        )
    }

    private static func restoreSingleSnapshot(_ snap: MutedDeviceSnapshot, on targetID: AudioDeviceID) {
        for (elem, vol) in snap.savedChannelVolumes {
            _ = setChannelVolumeScalar(deviceID: targetID, element: elem, volume: vol)
        }
        if let v = snap.savedVirtualMainVolume {
            _ = setVirtualMainVolume(deviceID: targetID, volume: v)
        }
        if snap.didSetHardwareMute {
            _ = setMuteState(deviceID: targetID, muted: false)
        }
    }

    private static func applyRestore(primary: MutedDeviceSnapshot?, secondary: MutedDeviceSnapshot?) {
        let currentDefault = defaultOutputDeviceID()
        if let p = primary {
            for target in devicesToRestore(mutedDeviceID: p.deviceID, currentDefaultDeviceID: currentDefault) {
                restoreSingleSnapshot(p, on: target)
            }
        }
        if let s = secondary, s.deviceID != primary?.deviceID {
            restoreSingleSnapshot(s, on: s.deviceID)
        }
    }

    private static func applyRestoreIfStillSilenced(primary: MutedDeviceSnapshot?, secondary: MutedDeviceSnapshot?) {
        let currentDefault = defaultOutputDeviceID()
        let snapshots = [primary, secondary].compactMap { $0 }
        for snap in snapshots {
            for target in devicesToRestore(mutedDeviceID: snap.deviceID, currentDefaultDeviceID: currentDefault) {
                for (elem, savedVol) in snap.savedChannelVolumes {
                    if let cur = getChannelVolumeScalar(deviceID: target, element: elem), cur < 0.005 {
                        _ = setChannelVolumeScalar(deviceID: target, element: elem, volume: savedVol)
                    }
                }
                if let savedVol = snap.savedVirtualMainVolume,
                   let cur = getVirtualMainVolume(deviceID: target), cur < 0.005 {
                    _ = setVirtualMainVolume(deviceID: target, volume: savedVol)
                }
                if snap.didSetHardwareMute, let curMute = getMuteState(deviceID: target), curMute != 0 {
                    _ = setMuteState(deviceID: target, muted: false)
                }
            }
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

    private static func outputTransportType(deviceID: AudioDeviceID) -> UInt32 {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport) == noErr else {
            return 0
        }
        return transport
    }

    private static func mutePropertyAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private static func volumeScalarAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private static func isMuteSettable(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var addr = mutePropertyAddress(element: element)
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr && settable.boolValue
    }

    private static func getMuteState(deviceID: AudioDeviceID) -> UInt32? {
        var mainAddr = mutePropertyAddress(element: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(deviceID, &mainAddr) {
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &mainAddr, 0, nil, &size, &muted) == noErr {
                return muted
            }
        }
        var foundChannel = false
        var anyUnmuted = false
        for elem: AudioObjectPropertyElement in [1, 2] {
            var addr = mutePropertyAddress(element: elem)
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr {
                foundChannel = true
                if muted == 0 { anyUnmuted = true }
            }
        }
        guard foundChannel else { return nil }
        return anyUnmuted ? 0 : 1
    }

    private static func setMuteState(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        let hasMain = isMuteSettable(deviceID: deviceID, element: kAudioObjectPropertyElementMain)
        let channels = hasMain ? [] : ([1, 2] as [AudioObjectPropertyElement]).filter {
            isMuteSettable(deviceID: deviceID, element: $0)
        }
        let elements = muteElementsToUpdate(hasMainSettable: hasMain, settableChannels: channels)
        guard !elements.isEmpty else { return false }

        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var anySucceeded = false
        for elem in elements {
            var addr = mutePropertyAddress(element: elem)
            if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &value) == noErr {
                anySucceeded = true
            }
        }
        return anySucceeded
    }

    private static func getChannelVolumeScalar(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float32? {
        var addr = volumeScalarAddress(element: element)
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        var vol: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr ? vol : nil
    }

    private static func getSettableChannelVolumes(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement: Float32] {
        var result: [AudioObjectPropertyElement: Float32] = [:]
        for elem: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = volumeScalarAddress(element: elem)
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr, settable.boolValue else { continue }
            if let v = getChannelVolumeScalar(deviceID: deviceID, element: elem) {
                result[elem] = v
                if elem == kAudioObjectPropertyElementMain {
                    break
                }
            }
        }
        return result
    }

    private static func setChannelVolumeScalar(deviceID: AudioDeviceID, element: AudioObjectPropertyElement, volume: Float32) -> Bool {
        var addr = volumeScalarAddress(element: element)
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr, settable.boolValue else { return false }
        var v = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &v) == noErr
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
