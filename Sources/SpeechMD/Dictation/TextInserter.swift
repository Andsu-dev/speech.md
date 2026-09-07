import AppKit
import ApplicationServices

/// Escreve texto no app que está em foco.
///
/// Cola via pasteboard + ⌘V em vez de sintetizar caractere por caractere:
/// digitar 300 caracteres com CGEvent leva segundos e embaralha acentuação.
enum TextInserter {
    /// Postar eventos de teclado exige Acessibilidade. Sem isso a colagem é
    /// silenciosamente ignorada pelo sistema.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// `target` é o app que estava na frente quando o ditado começou. Sem
    /// devolver o foco a ele, o ⌘V cairia na janela do speech.md — que é o que
    /// acontece sempre que o ditado é iniciado pelo botão da interface.
    static func insert(_ text: String, into target: NSRunningApplication?) async {
        guard !text.isEmpty else { return }

        if let target, !target.isActive {
            target.activate()
            try? await Task.sleep(for: .milliseconds(180))
        }

        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        paste()
        guard let previous else { return }
        try? await Task.sleep(for: .milliseconds(400))
        pasteboard.clearContents()
        pasteboard.setString(previous, forType: .string)
    }

    private static func paste() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode: CGKeyCode = 9 // kVK_ANSI_V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
