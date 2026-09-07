import AppKit
import Carbon.HIToolbox

/// Atalho global via Carbon. É a única rota que dispensa a permissão de
/// Acessibilidade — `NSEvent.addGlobalMonitorForEvents` exigiria, e é por isso
/// que a tecla fn, que o Carbon não registra, depende dela.
@MainActor
final class GlobalHotkey {
    private let id: UInt32

    init(id: UInt32) {
        self.id = id
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var flagsMonitors: [Any] = []
    private var isFunctionKeyDown = false
    private var lastFunctionTapAt: Date?
    private var onPress: (() -> Void)?
    private var onRelease: (() -> Void)?

    fileprivate static let signature = OSType(0x53504348) // 'SPCH'

    func register(
        _ binding: HotkeyBinding,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        unregister()
        guard binding.isValid else { return }
        self.onPress = onPress
        self.onRelease = onRelease

        guard !binding.isFunctionKey else {
            observeFunctionKey(doubleTap: binding.isDoubleTap)
            return
        }

        installHandlerIfNeeded()

        RegisterEventHotKey(
            binding.keyCode,
            carbonModifiers(from: binding.modifierFlags),
            EventHotKeyID(signature: Self.signature, id: id),
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
        flagsMonitors.forEach(NSEvent.removeMonitor)
        flagsMonitors = []
        isFunctionKeyDown = false
        lastFunctionTapAt = nil
    }

    /// No duplo toque não existe "segurar": o segundo toque dispara e pronto,
    /// então quem usa esse binding trata como liga/desliga.
    private func observeFunctionKey(doubleTap: Bool) {
        let handle: (NSEvent) -> Void = { [weak self] event in
            guard let self, event.keyCode == HotkeyBinding.fnKeyCode else { return }
            let isDown = event.modifierFlags.contains(.function)
            guard isDown != isFunctionKeyDown else { return }
            isFunctionKeyDown = isDown

            guard doubleTap else {
                isDown ? onPress?() : onRelease?()
                return
            }
            guard isDown else { return }

            let now = Date()
            if let last = lastFunctionTapAt,
               now.timeIntervalSince(last) <= HotkeyBinding.doubleTapWindow {
                lastFunctionTapAt = nil
                onPress?()
            } else {
                lastFunctionTapAt = now
            }
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handle) {
            flagsMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handle(event)
            return event
        }) {
            flagsMonitors.append(local)
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

                var fired = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &fired
                )
                guard fired.signature == GlobalHotkey.signature, fired.id == hotkey.id else {
                    return OSStatus(eventNotHandledErr)
                }

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
