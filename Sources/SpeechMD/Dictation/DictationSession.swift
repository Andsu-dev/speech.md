import AppKit
import Foundation
import Observation

struct Dictation: Identifiable {
    let id = UUID()
    let text: String
    let createdAt: Date
}

/// Ditado estilo Wispr Flow: fala em qualquer app, o texto é colado lá.
@MainActor
@Observable
final class DictationSession {
    enum State: Equatable {
        case idle
        case starting
        case listening
        case failed(String)
    }

    var state: State = .idle
    var liveText = ""
    var history: [Dictation] = []

    func delete(_ dictation: Dictation) {
        history.removeAll { $0.id == dictation.id }
    }

    func clearHistory() {
        history.removeAll()
    }
    /// Ditado iniciado por toque curto no atalho fica "travado" ouvindo até o
    /// próximo toque; iniciado segurando, termina quando a tecla é solta.
    var isLatched = false

    var isRunning: Bool {
        state == .listening || state == .starting
    }

    enum TargetIssue: Equatable {
        case missingPermission
        case noTextField

        var islandWarning: String {
            switch self {
            case .missingPermission: "Sem permissão"
            case .noTextField: "Sem campo de texto"
            }
        }

        /// Checado ANTES de ligar o microfone: sem destino não faz sentido
        /// gravar, o texto não teria onde cair.
        static func current() -> TargetIssue? {
            if !TextInserter.isTrusted { return .missingPermission }
            if !TextInserter.focusedElementAcceptsText() { return .noTextField }
            return nil
        }
    }

    /// Por que o texto não teria onde cair; nil quando há destino válido.
    private(set) var targetIssue: TargetIssue?

    var hasEditableTarget: Bool { targetIssue == nil }

    private var pipeline: SpeechPipeline?
    private var startTask: Task<Void, Never>?
    private var targetApp: NSRunningApplication?
    private var expand: (String) -> String = { $0 }
    private var formatAsMarkdown = false

    func start(
        localeIdentifier: String,
        mode: RecognitionMode,
        formatAsMarkdown: Bool = false,
        expand: @escaping (String) -> String = { $0 }
    ) {
        guard !isRunning else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        targetApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost
        self.expand = expand
        self.formatAsMarkdown = formatAsMarkdown
        targetIssue = TargetIssue.current()

        state = .starting
        liveText = ""

        startTask = Task(priority: .userInitiated) {
            do {
                let pipeline = SpeechPipeline(localeIdentifier: localeIdentifier, mode: mode)
                self.pipeline = pipeline
                try await pipeline.startMicrophone { [weak self] event in
                    self?.liveText = event.accumulatedText
                }
                guard !Task.isCancelled else { return }
                state = .listening
            } catch {
                state = .failed(error.localizedDescription)
                pipeline = nil
            }
        }
    }

    /// Para de ouvir e entrega o texto ao app que estava em foco.
    func finish() {
        startTask?.cancel()
        startTask = nil
        isLatched = false

        let currentPipeline = pipeline
        let target = targetApp
        pipeline = nil
        targetApp = nil
        state = .idle

        Task {
            // ler o texto só DEPOIS do stop: é ele que descarrega o último
            // resultado do analyzer. Lendo antes, a frase final se perde.
            await currentPipeline?.stop()

            let raw = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
            liveText = ""
            guard !raw.isEmpty else { return }

            var text = expand(raw)
            if formatAsMarkdown {
                text = await TranscriptFormatter.format(text)
            }
            history.insert(Dictation(text: text, createdAt: Date()), at: 0)
            guard hasEditableTarget else { return }
            await TextInserter.insert(text, into: target)
        }
    }
}
