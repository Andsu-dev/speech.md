import AppKit

/// Som e retorno tátil para as ações de voz.
///
/// Existe porque o ditado costuma rodar com a janela escondida: sem um sinal
/// fora da tela, não dá pra saber se começou a ouvir.
enum Feedback {
    enum Kind {
        case start
        case finish
        case warning

        var soundName: String {
            switch self {
            case .start: "Tink"
            case .finish: "Pop"
            case .warning: "Basso"
            }
        }

        var pattern: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .start, .finish: .alignment
            case .warning: .levelChange
            }
        }
    }

    /// Os sons do sistema tocam em volume cheio, e o do ditado dispara com a
    /// janela escondida, colado no ouvido de quem está de headset.
    private static let volume: Float = 0.25

    static func play(_ kind: Kind, sound: Bool, haptic: Bool) {
        if sound, let effect = NSSound(named: kind.soundName) {
            effect.volume = volume
            effect.play()
        }
        if haptic {
            NSHapticFeedbackManager.defaultPerformer.perform(
                kind.pattern,
                performanceTime: .now
            )
        }
    }
}
