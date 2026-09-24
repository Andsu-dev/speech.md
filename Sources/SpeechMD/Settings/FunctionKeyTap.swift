import AppKit
import ApplicationServices
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

    /// De quanto em quanto tempo se reconfere a Acessibilidade enquanto o tap
    /// não pôde nascer.
    private static let authorizationPollInterval = Duration.seconds(1)

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var authorizationTask: Task<Void, Never>?
    private var isFunctionKeyDown = false
    private var usedWithOtherKey = false

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }
        guard install() else {
            // `tapCreate` só devolve um tap com a Acessibilidade concedida, e a
            // permissão chega com o app já aberto: o painel de Ajustes é aberto
            // depois do launch. Desistir aqui deixa o fn morto até um relaunch,
            // que é o que acontecia com todo mundo na primeira execução.
            awaitAuthorization()
            return
        }
    }

    func stop() {
        authorizationTask?.cancel()
        authorizationTask = nil
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

    /// Cria e liga o tap. `false` quando o sistema recusa — na prática, quando a
    /// Acessibilidade ainda não foi concedida.
    private func install() -> Bool {
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
        ) else { return false }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Espera a Acessibilidade chegar e liga o tap sozinho. Uma sondagem a cada
    /// segundo é mais barata que a alternativa: `com.apple.accessibility.api`
    /// não é documentada e chega antes de `AXIsProcessTrusted` virar `true`.
    private func awaitAuthorization() {
        guard authorizationTask == nil else { return }

        authorizationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.authorizationPollInterval)
                guard let self, !Task.isCancelled else { return }
                guard tap == nil else { return }
                guard AXIsProcessTrusted(), install() else { continue }
                break
            }
            self?.authorizationTask = nil
        }
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
