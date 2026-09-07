import AppKit
import SwiftUI

/// Campo que captura a próxima combinação de teclas pressionada.
///
/// A captura mora num NSView, não num Button: botão focado no macOS é acionado
/// por Space/Return, então essas teclas nunca chegariam ao gravador.
struct ShortcutRecorderView: View {
    @Binding var binding: HotkeyBinding

    @State private var isRecording = false

    var body: some View {
        KeyCaptureView(isRecording: $isRecording, binding: $binding)
            .frame(width: 150, height: 34)
            .background(isRecording ? Theme.accent.opacity(0.08) : Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isRecording ? Theme.accent : Theme.border, lineWidth: isRecording ? 1.5 : 1)
            }
            .overlay {
                HStack(spacing: 7) {
                    Text(isRecording ? t("Pressione as teclas", "Press the keys") : binding.displayString)
                        .font(.system(size: 13, weight: .medium, design: isRecording ? .default : .rounded))
                        .foregroundStyle(isRecording ? Theme.accent : Theme.textPrimary)
                    if !isRecording {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .allowsHitTesting(false)
            }
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var binding: HotkeyBinding

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onRecordingChange = { isRecording = $0 }
        view.onCapture = { binding = $0 }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}
}

final class KeyCaptureNSView: NSView {
    var onRecordingChange: ((Bool) -> Void)?
    var onCapture: ((HotkeyBinding) -> Void)?

    private var isRecording = false {
        didSet { onRecordingChange?(isRecording) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording.toggle()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording, event.keyCode == HotkeyBinding.fnKeyCode else {
            super.flagsChanged(with: event)
            return
        }
        guard event.modifierFlags.contains(.function) else { return }
        onCapture?(.fn)
        isRecording = false
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // esc cancela
            isRecording = false
            return
        }

        let candidate = HotkeyBinding(
            keyCode: UInt32(event.keyCode),
            modifiers: event.modifierFlags
                .intersection([.control, .option, .shift, .command]).rawValue
        )
        guard candidate.isValid else { return }

        onCapture?(candidate)
        isRecording = false
    }

    /// Combinação com ⌘ vira key equivalent e seria consumida pelo menu antes
    /// de chegar no keyDown — interceptar aqui é o que deixa ⌘ gravável.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        keyDown(with: event)
        return true
    }
}
