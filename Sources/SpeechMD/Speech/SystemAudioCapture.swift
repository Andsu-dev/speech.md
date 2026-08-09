import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

enum SystemAudioCaptureError: LocalizedError {
    case noDisplay
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            "Nenhuma tela disponível para capturar o áudio da call."
        case .invalidAudioFormat:
            "O formato do áudio do sistema não pôde ser preparado."
        }
    }
}

struct CapturedAudioBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let sampleRate = 48_000.0
    static let channelCount: AVAudioChannelCount = 1

    private let audioQueue = DispatchQueue(
        label: "dev.anderson.speech-md.system-audio",
        qos: .userInteractive
    )
    private let onAudio: @Sendable (CapturedAudioBuffer) -> Void
    private var stream: SCStream?

    init(onAudio: @escaping @Sendable (CapturedAudioBuffer) -> Void) {
        self.onAudio = onAudio
        super.init()
    }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplay
        }

        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let excludedApplications = content.applications.filter {
            $0.bundleIdentifier == ownBundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = Int(Self.sampleRate)
        configuration.channelCount = Int(Self.channelCount)
        configuration.width = 2
        configuration.height = 2
        configuration.queueDepth = 1
        configuration.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 600)
        configuration.showsCursor = false

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        self.stream = stream
        try await stream.startCapture()
    }

    func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        try? stream.removeStreamOutput(self, type: .audio)
        self.stream = nil
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio,
              sampleBuffer.isValid,
              sampleBuffer.dataReadiness == .ready,
              let buffer = Self.copyPCMBuffer(from: sampleBuffer) else {
            return
        }
        onAudio(CapturedAudioBuffer(buffer: buffer))
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        // The owner observes the stopped session when the user ends the call.
    }

    private static func copyPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sampleBuffer.formatDescription,
              let streamDescription = description.audioStreamBasicDescription,
              let format = AVAudioFormat(
                standardFormatWithSampleRate: streamDescription.mSampleRate,
                channels: AVAudioChannelCount(streamDescription.mChannelsPerFrame)
              ) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frameCount > 0,
              let destination = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
              ) else {
            return nil
        }
        destination.frameLength = frameCount

        do {
            try sampleBuffer.withAudioBufferList { source, _ in
                let target = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
                guard source.count == target.count else {
                    throw SystemAudioCaptureError.invalidAudioFormat
                }

                for index in 0..<source.count {
                    guard let sourceData = source[index].mData,
                          let targetData = target[index].mData else {
                        continue
                    }
                    let byteCount = min(
                        Int(source[index].mDataByteSize),
                        Int(target[index].mDataByteSize)
                    )
                    targetData.copyMemory(from: sourceData, byteCount: byteCount)
                    target[index].mDataByteSize = UInt32(byteCount)
                }
            }
            return destination
        } catch {
            return nil
        }
    }
}
