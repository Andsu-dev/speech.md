import AppKit
import Foundation
import Observation

struct Dictation: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let createdAt: Date
}

struct DictationOutcome {
    let text: String
    let needsCopy: Bool
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
    var isRunning: Bool {
        state == .listening || state == .starting
    }

    enum TargetIssue: Equatable {
        case missingPermission
        case noTarget

        static func current(target: NSRunningApplication?) -> TargetIssue? {
            if !TextInserter.isTrusted { return .missingPermission }
            if target == nil { return .noTarget }
            return nil
        }
    }

    /// Por que o texto não teria onde cair; nil quando há destino válido.
    private(set) var targetIssue: TargetIssue?

    var hasEditableTarget: Bool { targetIssue == nil }

    /// Entregue direto por callback, não por `onChange` no SwiftUI: com a
    /// janela ocluída o body para de ser avaliado e a ilha ficava girando pra
    /// sempre mesmo com o texto já colado.
    var onFinish: ((DictationOutcome) -> Void)?
    var onFailure: ((String) -> Void)?

    private var pipeline: SpeechPipeline?
    private var startTask: Task<Void, Never>?
    private var targetApp: NSRunningApplication?
    private var expand: (String) -> String = { $0 }
    private var formatAsMarkdown = false
    private var polishTerms = false
    private var localeIdentifier = "pt-BR"

    func start(
        localeIdentifier: String,
        mode: RecognitionMode,
        inputDeviceUID: String = "",
        contextualTerms: [String] = SpokenTerms.all(),
        formatAsMarkdown: Bool = false,
        polishTerms: Bool = false,
        expand: @escaping (String) -> String = { $0 }
    ) {
        guard !isRunning else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        targetApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost
        self.expand = expand
        self.formatAsMarkdown = formatAsMarkdown
        self.polishTerms = polishTerms
        self.localeIdentifier = localeIdentifier
        targetIssue = TargetIssue.current(target: targetApp)

        if polishTerms { TermPolisher.prewarm() }

        state = .starting
        liveText = ""

        startTask = Task(priority: .userInitiated) {
            do {
                let pipeline = SpeechPipeline(
                    localeIdentifier: localeIdentifier,
                    mode: mode,
                    inputDeviceUID: inputDeviceUID.isEmpty ? nil : inputDeviceUID,
                    contextualTerms: contextualTerms
                )
                self.pipeline = pipeline
                try await pipeline.startMicrophone { [weak self] event in
                    self?.liveText = event.accumulatedText
                }
                guard !Task.isCancelled else { return }
                state = .listening
            } catch {
                state = .failed(error.localizedDescription)
                pipeline = nil
                onFailure?(error.localizedDescription)
            }
        }
    }

    /// Para de ouvir e entrega o texto ao app que estava em foco.
    func finish() {
        startTask?.cancel()
        startTask = nil

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
            guard !raw.isEmpty else {
                onFinish?(DictationOutcome(text: "", needsCopy: false))
                return
            }

            var text = expand(raw)
            if polishTerms {
                text = await TermPolisher.polish(text, localeIdentifier: localeIdentifier)
            }
            if formatAsMarkdown {
                text = await TranscriptFormatter.format(text)
            }
            history.insert(Dictation(text: text, createdAt: Date()), at: 0)
            guard hasEditableTarget else {
                onFinish?(DictationOutcome(text: text, needsCopy: true))
                return
            }
            await TextInserter.insert(text, into: target)
            onFinish?(DictationOutcome(text: text, needsCopy: false))
        }
    }
}
