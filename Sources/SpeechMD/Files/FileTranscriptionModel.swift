import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class FileTranscriptionModel {
    enum State: Equatable {
        case idle
        case transcribing(String)
        case done(String)
        case failed(String)
    }

    var state: State = .idle
    var transcript = ""
    var result: BenchmarkResult?

    var isBusy: Bool {
        if case .transcribing = state { return true }
        return false
    }

    private var pipeline: SpeechPipeline?
    private var task: Task<Void, Never>?

    func chooseFile(localeIdentifier: String, mode: RecognitionMode) {
        let panel = NSOpenPanel()
        panel.title = "Escolha um áudio para transcrever"
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        transcribe(url: url, localeIdentifier: localeIdentifier, mode: mode)
    }

    func transcribe(url: URL, localeIdentifier: String, mode: RecognitionMode) {
        task?.cancel()
        transcript = ""
        result = nil
        state = .transcribing(url.lastPathComponent)

        task = Task(priority: .userInitiated) {
            do {
                let pipeline = SpeechPipeline(localeIdentifier: localeIdentifier, mode: mode)
                self.pipeline = pipeline
                let outcome = try await pipeline.benchmarkFile(at: url) { [weak self] event in
                    self?.transcript = event.accumulatedText
                }
                guard !Task.isCancelled else { return }
                result = outcome
                state = .done(url.lastPathComponent)
                self.pipeline = nil
            } catch {
                state = .failed(error.localizedDescription)
                pipeline = nil
            }
        }
    }

    func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
    }

    func saveTranscript(suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(suggestedName).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? transcript.write(to: url, atomically: true, encoding: .utf8)
    }

}
