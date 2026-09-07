import AVFoundation
import CoreAudio
import Foundation

/// Um microfone disponível no sistema.
///
/// O identificador guardado é o UID do dispositivo, não o `AudioDeviceID`: o
/// número muda a cada reconexão ou reboot, o UID não.
struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    static var available: [AudioInputDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        .devices
        .map { AudioInputDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    /// Traduz o UID para o identificador que o AudioUnit entende.
    static func coreAudioID(for uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfUID = uid as CFString
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = withUnsafeMutablePointer(to: &cfUID) { uidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                uidPointer,
                &size,
                &deviceID
            )
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
}
