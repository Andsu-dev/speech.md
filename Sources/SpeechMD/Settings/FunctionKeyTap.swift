import AppKit
@preconcurrency import CoreGraphics

/// Intercepta a tecla fn antes do sistema e engole o toque solto.
///
/// Depender de `AppleFnUsageType` não resolve: quem decide abrir o Emoji &
/// Símbolos é o WindowServer, e ele só não abre se o evento não chegar. Um tap
/// no nível do HID chega primeiro, e é o que permite usar fn como atalho.
///
/// Os dois lados do toque no fn são engolidos. Combinações não se perdem:
/// `flagsChanged` é só o aviso de mudança de modificador, e o keyDown de
/// fn+F3 chega ao sistema com `maskSecondaryFn` nas flags dele mesmo.
@MainActor
final class FunctionKeyTap {
    /// `isDown` do fn. Chamado antes de o evento seguir (ou ser engolido).
    var onChange: ((Bool) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isFunctionKeyDown = false
    private var usedWithOtherKey = false

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<FunctionKeyTap>.fromOpaque(userInfo).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    tap.handle(proxy: proxy, type: type, event: event)
                }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        isFunctionKeyDown = false
        usedWithOtherKey = false
    }

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // O sistema desliga o tap se ele demorar a responder; religar é o único
        // jeito de não perder a tecla no meio do uso.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            if isFunctionKeyDown { usedWithOtherKey = true }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(HotkeyBinding.fnKeyCode) else {
            return Unmanaged.passUnretained(event)
        }

        let isDown = event.flags.contains(.maskSecondaryFn)
        guard isDown != isFunctionKeyDown else { return Unmanaged.passUnretained(event) }
        isFunctionKeyDown = isDown

        // O WindowServer abre o Emoji & Símbolos já no press, então engolir só
        // o release não adianta: os dois lados do toque ficam com o app.
        //
        // As combinações seguem funcionando porque `flagsChanged` é apenas o
        // aviso de que o modificador mudou: o keyDown de fn+F3 continua
        // chegando ao sistema com `maskSecondaryFn` nas próprias flags.
        if isDown {
            usedWithOtherKey = false
            onChange?(true)
            return nil
        }

        onChange?(false)
        return nil
    }
}
