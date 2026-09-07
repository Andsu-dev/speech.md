import AVFoundation
import Foundation
import Observation

/// Grava uma reunião em dois canais independentes: microfone (você) e áudio do
/// sistema (os outros participantes).
@MainActor
@Observable
final class MeetingSession {
    enum Phase: Equatable {
        case idle
        case preparing
        case listening
        case calling
        case failed(String)

        var isRunning: Bool {
            switch self {
            case .preparing, .listening, .calling: true
            case .idle, .failed: false
            }
        }
    }

    var phase: Phase = .idle
    var youTranscript = ""
    var othersTranscript = ""
    var youMetrics = RunMetrics.empty
    var othersMetrics = RunMetrics.empty
    var localeIdentifier = "pt-BR"
    var recognitionMode: RecognitionMode = .lowLatency
    var inputDeviceUID = ""

    private var youPipeline: SpeechPipeline?
    private var othersPipeline: SpeechPipeline?
    private var systemAudioCapture: SystemAudioCapture?
    private var runTask: Task<Void, Never>?

    /// Microfone e áudio do sistema, cada um no seu analyzer — um SpeechAnalyzer
    /// processa uma sequência por vez.
    func startCall() {
        stop()
        phase = .preparing
        reset()

        runTask = Task(priority: .userInitiated) {
            let you = SpeechPipeline(
                localeIdentifier: localeIdentifier,
                mode: recognitionMode,
                inputDeviceUID: inputDeviceUID.isEmpty ? nil : inputDeviceUID
            )
            let others = SpeechPipeline(localeIdentifier: localeIdentifier, mode: recognitionMode)
            youPipeline = you
            othersPipeline = others

            do {
                try await you.startMicrophone { [weak self] event in
                    self?.youTranscript = event.accumulatedText
                    self?.youMetrics = event.metrics
                }

                guard let systemFormat = AVAudioFormat(
                    standardFormatWithSampleRate: SystemAudioCapture.sampleRate,
                    channels: SystemAudioCapture.channelCount
                ) else {
                    throw SystemAudioCaptureError.invalidAudioFormat
                }

                try await others.startAudioStream(sourceFormat: systemFormat) { [weak self] event in
                    self?.othersTranscript = event.accumulatedText
                    self?.othersMetrics = event.metrics
                }

                let capture = SystemAudioCapture { input in
                    Task(priority: .high) { await others.appendAudio(input.buffer) }
                }
                systemAudioCapture = capture
                try await capture.start()

                guard !Task.isCancelled else { return }
                phase = .calling
            } catch {
                await tearDown()
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Só o microfone: dispensa a permissão de gravação de tela.
    func startMicrophone() {
        stop()
        phase = .preparing
        reset()

        runTask = Task(priority: .userInitiated) {
            do {
                let you = SpeechPipeline(
                    localeIdentifier: localeIdentifier,
                    mode: recognitionMode,
                    inputDeviceUID: inputDeviceUID.isEmpty ? nil : inputDeviceUID
                )
                youPipeline = you
                try await you.startMicrophone { [weak self] event in
                    self?.youTranscript = event.accumulatedText
                    self?.youMetrics = event.metrics
                }
                guard !Task.isCancelled else { return }
                phase = .listening
            } catch {
                await tearDown()
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil

        let you = youPipeline
        let others = othersPipeline
        let capture = systemAudioCapture
        youPipeline = nil
        othersPipeline = nil
        systemAudioCapture = nil

        Task {
            await capture?.stop()
            await you?.stop()
            await others?.stop()
        }

        if phase.isRunning {
            phase = .idle
        }
    }

    private func tearDown() async {
        await systemAudioCapture?.stop()
        await youPipeline?.stop()
        await othersPipeline?.stop()
        systemAudioCapture = nil
        youPipeline = nil
        othersPipeline = nil
    }

    private func reset() {
        youTranscript = ""
        othersTranscript = ""
        youMetrics = .empty
        othersMetrics = .empty
    }
}
