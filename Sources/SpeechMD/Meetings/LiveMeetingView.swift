import SwiftUI

/// O que faltava: enquanto a reunião grava, mostrar a transcrição chegando.
struct LiveMeetingView: View {
    let model: MeetingSession
    let elapsed: TimeInterval
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if case .failed(let message) = model.phase {
                errorCard(message)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    channel(
                        title: "Você",
                        systemImage: "person.fill",
                        accent: Theme.accent,
                        text: model.youTranscript,
                        metrics: model.youMetrics
                    )
                    channel(
                        title: "Outros",
                        systemImage: "person.2.fill",
                        accent: Theme.live,
                        text: model.othersTranscript,
                        metrics: model.othersMetrics
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle().fill(Theme.live).frame(width: 7, height: 7)
                Text(model.phase == .preparing ? "Preparando modelo…" : "Gravando")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(formattedElapsed)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()

            Spacer(minLength: 12)

            Button(action: onStop) {
                HStack(spacing: 7) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Encerrar")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func channel(
        title: String,
        systemImage: String,
        accent: Color,
        text: String,
        metrics: RunMetrics
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.12), in: Circle())
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                if let lag = metrics.latestPipelineLagMilliseconds {
                    Text("\(Int(lag)) ms")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            ScrollView {
                Text(text.isEmpty ? "Aguardando áudio…" : text)
                    .font(.system(size: 13))
                    .foregroundStyle(text.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 180)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.live)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.live.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var formattedElapsed: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
