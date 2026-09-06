import SwiftUI

struct DictationView: View {
    let session: DictationSession
    let hotkey: HotkeyBinding
    let onToggle: () -> Void

    @State private var needsPermission = !TextInserter.isTrusted

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if needsPermission {
                    permissionCard
                }

                header

                if session.isRunning {
                    liveCard
                }

                if session.history.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("HISTÓRICO")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .tracking(0.6)
                            Spacer()
                            Button("Limpar tudo") { session.clearHistory() }
                                .controlSize(.small)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(session.history.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Divider().overlay(Theme.border)
                                }
                                DictationRow(
                                    dictation: item,
                                    onDelete: { session.delete(item) }
                                )
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
        .onAppear { needsPermission = !TextInserter.isTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            needsPermission = !TextInserter.isTrusted
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Segure o atalho e fale — ao soltar, o texto é colado no app em foco. Um toque curto mantém ouvindo até o toque seguinte.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)

            Text(hotkey.displayString)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                }

            Button(action: onToggle) {
                HStack(spacing: 7) {
                    Image(systemName: session.isRunning ? "stop.fill" : "mic.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(session.isRunning ? "Parar" : "Falar")
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
        .padding(.vertical, 18)
        .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var headerTitle: String {
        guard session.isRunning else { return "Escrever falando" }
        return session.isLatched ? "Ouvindo (travado)" : "Ouvindo…"
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(Theme.live).frame(width: 6, height: 6)
                Text("Transcrevendo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.live)
                    .tracking(0.4)
            }
            Text(session.liveText.isEmpty ? "Fale algo…" : session.liveText)
                .font(.system(size: 14))
                .foregroundStyle(session.liveText.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.live.opacity(0.4), lineWidth: 1)
        }
    }

    private var permissionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 18))
                .foregroundStyle(Theme.highlight)
            VStack(alignment: .leading, spacing: 3) {
                Text("Falta permissão de Acessibilidade")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Sem ela o texto é transcrito mas não consegue ser colado no app em foco.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 12)
            Button {
                SystemPermission.accessibility.requestIfPossible()
            } label: {
                Text("Permitir")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        }
        .padding(16)
        .background(Theme.highlight.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.highlight.opacity(0.4), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Nada transcrito ainda")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Clique em Falar ou use \(hotkey.displayString) de qualquer app.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

private struct DictationRow: View {
    let dictation: Dictation
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(dictation.createdAt, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
                .frame(width: 52, alignment: .leading)

            Text(dictation.text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(dictation.text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(isHovering ? Theme.surfaceHover.opacity(0.6) : .clear)
        .onHover { isHovering = $0 }
    }
}
