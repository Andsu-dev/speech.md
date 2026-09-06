import SwiftUI
import UniformTypeIdentifiers

struct FileTranscriptionView: View {
    let model: FileTranscriptionModel
    let onChooseFile: () -> Void
    let onDrop: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                dropZone

                if !model.transcript.isEmpty {
                    transcriptCard
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: model.isBusy ? "waveform" : "waveform.badge.plus")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.textTertiary)

            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text(statusSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if !model.isBusy {
                Button("Escolher arquivo…", action: onChooseFile)
                    .controlSize(.large)
                    .pointerStyle(.link)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .background(isTargeted ? Theme.accent.opacity(0.06) : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(
                    isTargeted ? Theme.accent : Theme.border,
                    style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: [6, 4])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in onDrop(url) }
            }
            return true
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRANSCRIÇÃO")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(0.6)
                Spacer()
                if let result = model.result {
                    Text(String(format: "%.1f× realtime", result.realtimeFactor))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
                Button("Copiar") { model.copyTranscript() }
                    .controlSize(.small)
                    .pointerStyle(.link)
                Button("Salvar…") { model.saveTranscript(suggestedName: fileName) }
                    .controlSize(.small)
                    .pointerStyle(.link)
            }

            Text(model.transcript)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private var fileName: String {
        switch model.state {
        case .transcribing(let name), .done(let name):
            (name as NSString).deletingPathExtension
        default:
            "transcricao"
        }
    }

    private var statusTitle: String {
        switch model.state {
        case .idle: "Transcrever um arquivo"
        case .transcribing(let name): "Transcrevendo \(name)"
        case .done(let name): name
        case .failed: "Não deu para transcrever"
        }
    }

    private var statusSubtitle: String {
        switch model.state {
        case .idle: "Arraste um áudio aqui ou escolha do disco. Tudo roda no seu Mac."
        case .transcribing: "Processando no dispositivo…"
        case .done: "Pronto. Arraste outro arquivo para transcrever de novo."
        case .failed(let message): message
        }
    }
}
