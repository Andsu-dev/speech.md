import SwiftUI

struct MeetingFeedView: View {
    let days: [MeetingDay]
    let model: MeetingSession
    let elapsed: TimeInterval
    let capturesSystemAudio: Bool
    let onStartMeeting: () -> Void
    let onUseMicrophoneOnly: () -> Void

    private var isRecording: Bool { model.phase.isRunning }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if isRecording {
                    LiveMeetingView(model: model, elapsed: elapsed, onStop: onStartMeeting)
                } else {
                    startBar
                }
                if case .failed(let message) = model.phase {
                    failureCard(message)
                }

                if days.isEmpty, !isRecording {
                    emptyState
                }

                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(day.label.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .tracking(0.6)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(day.meetings.enumerated()), id: \.element.id) { index, meeting in
                                if index > 0 {
                                    Divider().overlay(Theme.border)
                                }
                                MeetingRow(meeting: meeting)
                            }
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
        }
    }

    private func failureCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.live)
            VStack(alignment: .leading, spacing: 6) {
                Text("A gravação não começou")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if capturesSystemAudio {
                    HStack(spacing: 8) {
                        Button {
                            SystemPermission.screenRecording.openSettings()
                        } label: {
                            Text("Abrir Ajustes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button("Gravar só meu microfone", action: onUseMicrophoneOnly)
                            .font(.system(size: 12))
                            .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.live.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.live.opacity(0.3), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Nenhuma reunião gravada")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Clique em Começar para gravar sua primeira reunião.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var startBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isRecording ? "Gravando reunião" : "Gravar reunião")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Sua voz e a dos outros participantes, separadas e no seu Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 12)

            Button(action: onStartMeeting) {
                HStack(spacing: 7) {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isRecording ? "Parar" : "Começar")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(meeting.formattedTime)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                if meeting.isLive {
                    LiveBadge()
                }
            }
            .frame(width: 66, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(meeting.excerpt)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    MetaLabel(systemImage: "clock", text: meeting.formattedDuration)
                    MetaLabel(systemImage: "person.2", text: "\(meeting.participants)")
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                RowAction(systemImage: "play.fill")
                RowAction(systemImage: "doc.on.doc")
                RowAction(systemImage: "sparkles")
                RowAction(systemImage: "ellipsis")
            }
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(isHovering ? Theme.surfaceHover.opacity(0.6) : .clear)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Theme.live)
                .frame(width: 5, height: 5)
            Text("AO VIVO")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
        }
        .foregroundStyle(Theme.live)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.live.opacity(0.1), in: Capsule())
    }
}

private struct MetaLabel: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(Theme.textTertiary)
    }
}

private struct RowAction: View {
    let systemImage: String

    @State private var isHovering = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovering ? Theme.border.opacity(0.6) : .clear)
            }
            .onHover { isHovering = $0 }
    }
}
