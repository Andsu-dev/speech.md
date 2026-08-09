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

    static func play(_ kind: Kind, sound: Bool, haptic: Bool) {
        if sound {
            NSSound(named: kind.soundName)?.play()
        }
        if haptic {
            NSHapticFeedbackManager.defaultPerformer.perform(
                kind.pattern,
                performanceTime: .now
            )
        }
    }
}
