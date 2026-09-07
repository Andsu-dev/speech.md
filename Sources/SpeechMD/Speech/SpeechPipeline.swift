import AVFoundation
import AudioToolbox
import CoreMedia
import Foundation
import Speech

enum RecognitionMode: String, CaseIterable, Identifiable, Sendable {
    case lowLatency
    case quality

    var id: Self { self }

    var label: String {
        switch self {
        case .lowLatency: t("Baixa latência", "Low latency")
        case .quality: t("Maior precisão", "Higher accuracy")
        }
    }
}

struct RunMetrics: Sendable {
    var firstPartialMilliseconds: Double?
    var latestPipelineLagMilliseconds: Double?
    var partialCount: Int
    var finalCount: Int

    static let empty = RunMetrics(
        firstPartialMilliseconds: nil,
        latestPipelineLagMilliseconds: nil,
        partialCount: 0,
        finalCount: 0
    )
}

struct TranscriptEvent: Sendable {
    let accumulatedText: String
    let metrics: RunMetrics
}

struct BenchmarkResult: Sendable {
    let audioDurationSeconds: Double
    let processingSeconds: Double

    var realtimeFactor: Double {
        guard processingSeconds > 0 else { return 0 }
        return audioDurationSeconds / processingSeconds
    }
}

enum SpeechPipelineError: LocalizedError {
    case unavailable
    case unsupportedLocale(String)
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .unavailable:
            t("SpeechTranscriber não está disponível neste Mac.", "SpeechTranscriber is not available on this Mac.")
        case .unsupportedLocale(let locale):
            t("O locale \(locale) não é suportado pelo SpeechTranscriber.", "The locale \(locale) is not supported by SpeechTranscriber.")
        case .noMicrophone:
            t("Nenhum microfone foi encontrado.", "No microphone was found.")
        }
    }
}

actor SpeechPipeline {
    typealias EventHandler = @MainActor @Sendable (TranscriptEvent) -> Void

    private let requestedLocale: Locale
    private let mode: RecognitionMode
    private let inputDeviceUID: String?
    private let contextualTerms: [String]
    private var analyzer: SpeechAnalyzer?
    private var resultTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var audioBridge: AudioInputBridge?
    private var startedAt: ContinuousClock.Instant?
    private var metrics = RunMetrics.empty
    private var finalizedSegments: [String] = []
    private var volatileSegment = ""
    private var resetClockOnNextAudio = false

    init(
        localeIdentifier: String,
        mode: RecognitionMode,
        inputDeviceUID: String? = nil,
        contextualTerms: [String] = SpokenTerms.all()
    ) {
        requestedLocale = Locale(identifier: localeIdentifier)
        self.mode = mode
        self.inputDeviceUID = inputDeviceUID
        self.contextualTerms = contextualTerms
    }

    /// Pista de vocabulário para o reconhecedor: os estrangeirismos saem
    /// escritos certo já na transcrição, sem custar nada depois.
    private func analysisContext() -> AnalysisContext {
        let context = AnalysisContext()
        context.contextualStrings = [.general: contextualTerms]
        return context
    }

    /// Aponta o engine para o microfone escolhido nos ajustes. Sem escolha, ou
    /// com o dispositivo desconectado, fica o padrão do sistema.
    private func selectInputDevice(on input: AVAudioInputNode) {
        guard let inputDeviceUID,
              let audioUnit = input.audioUnit,
              var deviceID = AudioInputDevice.coreAudioID(for: inputDeviceUID)
        else { return }

        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    func startMicrophone(onEvent: @escaping EventHandler) async throws {
        let prepared = try await preparePipeline()
        let analyzer = prepared.analyzer
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw SpeechPipelineError.noMicrophone
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        // Antes de ler o formato: trocar o dispositivo depois disso deixaria o
        // tap com a taxa de amostragem do microfone antigo.
        selectInputDevice(on: input)
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            throw SpeechPipelineError.noMicrophone
        }
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: prepared.modules,
            considering: inputFormat
        ) else {
            throw SpeechPipelineError.unavailable
        }

        let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let bridge = try AudioInputBridge(
            sourceFormat: inputFormat,
            analyzerFormat: analyzerFormat,
            continuation: inputBuilder
        )
        input.installTap(onBus: 0, bufferSize: 256, format: inputFormat) { buffer, _ in
            bridge.receive(buffer)
        }

        self.analyzer = analyzer
        audioEngine = engine
        audioBridge = bridge
        startConsumingResults(from: prepared, onEvent: onEvent)

        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try await analyzer.start(inputSequence: inputSequence)
        engine.prepare()
        try engine.start()
        // SpeechAnalyzer time-codes begin with the audio stream, not when model
        // preparation starts. Anchor the wall clock only after capture is live.
        resetRunState()
    }

    func startAudioStream(
        sourceFormat: AVAudioFormat,
        onEvent: @escaping EventHandler
    ) async throws {
        let prepared = try await preparePipeline()
        let analyzer = prepared.analyzer
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: prepared.modules,
            considering: sourceFormat
        ) else {
            throw SpeechPipelineError.unavailable
        }

        let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let bridge = try AudioInputBridge(
            sourceFormat: sourceFormat,
            analyzerFormat: analyzerFormat,
            continuation: inputBuilder
        )

        self.analyzer = analyzer
        audioBridge = bridge
        startConsumingResults(from: prepared, onEvent: onEvent)
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try await analyzer.start(inputSequence: inputSequence)
        resetClockOnNextAudio = true
        resetRunState()
    }

    func appendAudio(_ buffer: AVAudioPCMBuffer) {
        if resetClockOnNextAudio {
            resetRunState()
            resetClockOnNextAudio = false
        }
        audioBridge?.receive(buffer)
    }

    func benchmarkFile(
        at url: URL,
        onEvent: @escaping EventHandler
    ) async throws -> BenchmarkResult {
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let prepared = try await preparePipeline()
        let analyzer = prepared.analyzer

        self.analyzer = analyzer
        startConsumingResults(from: prepared, onEvent: onEvent)
        try await analyzer.prepareToAnalyze(in: file.processingFormat)

        let clock = ContinuousClock()
        let start = clock.now
        resetRunState(at: start)
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        let elapsed = start.duration(to: clock.now).seconds
        await resultTask?.value

        return BenchmarkResult(
            audioDurationSeconds: duration,
            processingSeconds: elapsed
        )
    }

    func stop() async {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioBridge?.finish()
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            await analyzer?.cancelAndFinishNow()
        }
        await resultTask?.value
        resultTask = nil
        audioBridge = nil
        audioEngine = nil
        analyzer = nil
        resetClockOnNextAudio = false
    }

    private func preparePipeline() async throws -> PreparedPipeline {
        let options = SpeechAnalyzer.Options(
            priority: .high,
            modelRetention: .lingering
        )

        switch mode {
        case .lowLatency:
            guard let locale = await DictationTranscriber.supportedLocale(
                equivalentTo: requestedLocale
            ) else {
                throw SpeechPipelineError.unsupportedLocale(requestedLocale.identifier)
            }
            let transcriber = DictationTranscriber(
                locale: locale,
                preset: .progressiveShortDictation
            )
            try await ensureAssets(for: [transcriber])
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: options)
            try await analyzer.setContext(analysisContext())
            return .dictation(analyzer, transcriber)

        case .quality:
            guard SpeechTranscriber.isAvailable else {
                throw SpeechPipelineError.unavailable
            }
            guard let locale = await SpeechTranscriber.supportedLocale(
                equivalentTo: requestedLocale
            ) else {
                throw SpeechPipelineError.unsupportedLocale(requestedLocale.identifier)
            }
            let transcriber = SpeechTranscriber(
                locale: locale,
                preset: .progressiveTranscription
            )
            try await ensureAssets(for: [transcriber])
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: options)
            try await analyzer.setContext(analysisContext())
            return .speech(analyzer, transcriber)
        }
    }

    private func ensureAssets(for modules: [any SpeechModule]) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            try await request.downloadAndInstall()
        }
    }

    private func resetRunState(at instant: ContinuousClock.Instant = ContinuousClock().now) {
        startedAt = instant
        metrics = .empty
        finalizedSegments = []
        volatileSegment = ""
    }

    private func startConsumingResults(
        from prepared: PreparedPipeline,
        onEvent: @escaping EventHandler
    ) {
        resultTask = Task(priority: .high) { [weak self] in
            do {
                switch prepared {
                case .speech(_, let transcriber):
                    for try await result in transcriber.results {
                        guard !Task.isCancelled else { return }
                        await self?.consume(
                            text: result.text,
                            isFinal: result.isFinal,
                            range: result.range,
                            onEvent: onEvent
                        )
                    }
                case .dictation(_, let transcriber):
                    for try await result in transcriber.results {
                        guard !Task.isCancelled else { return }
                        await self?.consume(
                            text: result.text,
                            isFinal: result.isFinal,
                            range: result.range,
                            onEvent: onEvent
                        )
                    }
                }
            } catch {
                // Analyzer cancellation terminates the result stream with an error.
            }
        }
    }

    private func consume(
        text attributedText: AttributedString,
        isFinal: Bool,
        range: CMTimeRange,
        onEvent: @escaping EventHandler
    ) async {
        let text = String(attributedText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let clock = ContinuousClock()
        let wallSeconds = startedAt.map { $0.duration(to: clock.now).seconds }
        if metrics.firstPartialMilliseconds == nil,
           let wallSeconds {
            let speechStartSeconds = CMTimeGetSeconds(range.start)
            if speechStartSeconds.isFinite {
                // Exclude silence before the first recognized phrase. This is
                // the latency a dictation UI actually makes the user feel.
                metrics.firstPartialMilliseconds = max(
                    0,
                    wallSeconds - speechStartSeconds
                ) * 1_000
            }
        }

        if isFinal {
            metrics.finalCount += 1
            finalizedSegments.append(text)
            volatileSegment = ""
        } else {
            metrics.partialCount += 1
            volatileSegment = text
        }

        if let wallSeconds {
            let audioEndSeconds = CMTimeGetSeconds(range.end)
            if audioEndSeconds.isFinite {
                metrics.latestPipelineLagMilliseconds = max(0, wallSeconds - audioEndSeconds) * 1_000
            }
        }

        let combined = (finalizedSegments + [volatileSegment])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        await onEvent(TranscriptEvent(accumulatedText: combined, metrics: metrics))
    }
}

private enum PreparedPipeline: Sendable {
    case speech(SpeechAnalyzer, SpeechTranscriber)
    case dictation(SpeechAnalyzer, DictationTranscriber)

    var analyzer: SpeechAnalyzer {
        switch self {
        case .speech(let analyzer, _), .dictation(let analyzer, _): analyzer
        }
    }

    var modules: [any SpeechModule] {
        switch self {
        case .speech(_, let transcriber): [transcriber]
        case .dictation(_, let transcriber): [transcriber]
        }
    }
}

private final class AudioInputBridge: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let analyzerFormat: AVAudioFormat
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let lock = NSLock()

    init(
        sourceFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        guard let converter = AVAudioConverter(from: sourceFormat, to: analyzerFormat) else {
            throw SpeechPipelineError.unavailable
        }
        self.converter = converter
        self.analyzerFormat = analyzerFormat
        self.continuation = continuation
    }

    func receive(_ source: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        let ratio = analyzerFormat.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(source.frameLength) * ratio)) + 1
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: analyzerFormat,
            frameCapacity: capacity
        ) else { return }

        let input = ConverterInput(source)
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outputStatus in
            if input.wasSupplied {
                outputStatus.pointee = .noDataNow
                return nil
            }
            input.wasSupplied = true
            outputStatus.pointee = .haveData
            return input.buffer
        }

        guard status == .haveData, conversionError == nil else { return }
        continuation.yield(AnalyzerInput(buffer: converted))
    }

    func finish() {
        continuation.finish()
    }
}

private final class ConverterInput: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var wasSupplied = false

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

private extension Duration {
    var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    var milliseconds: Double {
        seconds * 1_000
    }
}
