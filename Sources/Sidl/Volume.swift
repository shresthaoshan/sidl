import AudioToolbox  // VirtualMainVolume constant
import CoreAudio

/// System output volume through CoreAudio. No-op on devices without a main volume control.
enum Volume {
    /// Changes the volume by `delta` (0..1 scale) and returns the new value, or nil if not supported.
    @discardableResult
    static func change(by delta: Float) -> Float? {
        guard let device = defaultOutputDevice() else { return nil }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else { return nil }
        volume = min(max(volume + delta, 0), 1)
        guard AudioObjectSetPropertyData(device, &address, 0, nil, size, &volume) == noErr else { return nil }
        return volume
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }
}
