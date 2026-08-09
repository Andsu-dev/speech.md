import AppKit
import Carbon.HIToolbox

/// Atalho global via Carbon. É a única rota que dispensa a permissão de
/// Acessibilidade — `NSEvent.addGlobalMonitorForEvents` exigiria.
@MainActor
final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onPress: (() -> Void)?
    private var onRelease: (() -> Void)?

    private static let signature = OSType(0x53504348) // 'SPCH'

    func register(
        _ binding: HotkeyBinding,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        unregister()
        guard binding.isValid else { return }
        self.onPress = onPress
        self.onRelease = onRelease

        installHandlerIfNeeded()

        RegisterEventHotKey(
            binding.keyCode,
            carbonModifiers(from: binding.modifierFlags),
            EventHotKeyID(signature: Self.signature, id: 1),
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    /// Press E release: é o release que permite o "segura pra falar".
    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                let isRelease = GetEventKind(event) == UInt32(kEventHotKeyReleased)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        isRelease ? hotkey.onRelease?() : hotkey.onPress?()
                    }
                }
                return noErr
            },
            2,
            &eventTypes,
            context,
            &eventHandler
        )
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    // ponytail: sem deinit — o objeto vive enquanto a janela existir, e Swift 6
    // não deixa deinit nonisolated tocar EventHotKeyRef. register() já
    // desregistra o anterior, que é o caso real (usuário trocar o atalho).
}
