import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var permissionsRefreshedAt = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(t("Configurações", "Settings"))
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                SettingsGroup(t("Permissões", "Permissions")) {
                    ForEach(Array(SystemPermission.allCases.enumerated()), id: \.element.id) { index, permission in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        PermissionRow(permission: permission)
                    }
                }
                .id(permissionsRefreshedAt)

                SettingsGroup(t("Atalho", "Shortcut")) {
                    SettingsRow(
                        title: t("Iniciar e parar gravação", "Start and stop recording"),
                        subtitle: t("Funciona com qualquer app em foco.", "Works with any focused app.")
                    ) {
                        ShortcutRecorderView(binding: $settings.hotkey)
                    }
                }

                SettingsGroup(t("Transcrição", "Transcription")) {
                    SettingsRow(
                        title: t("Idioma da fala", "Spoken language"),
                        subtitle: t("O idioma que você fala. Não traduz: falar português com inglês selecionado sai embaralhado. O modelo é baixado sob demanda e roda no dispositivo.", "The language you speak. It does not translate: speaking Portuguese with English selected comes out scrambled. The model downloads on demand and runs on device.")
                    ) {
                        Picker("", selection: $settings.localeIdentifier) {
                            Text("Português (BR)").tag("pt-BR")
                            Text("English (US)").tag("en-US")
                            Text("Español").tag("es-ES")
                        }
                        .labelsHidden()
                        .frame(width: 168)
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Modo", "Mode"),
                        subtitle: t("Latência menor ou transcrição mais precisa.", "Lower latency or more accurate transcription.")
                    ) {
                        Picker("", selection: $settings.recognitionMode) {
                            ForEach(RecognitionMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 168)
                    }
                }

                SettingsGroup(t("Formatação", "Formatting")) {
                    SettingsRow(
                        title: t("Escrever em Markdown", "Write in Markdown"),
                        subtitle: TranscriptFormatter.isAvailable
                            ? t("Enumerações viram lista e a pontuação é corrigida por um modelo no dispositivo. Adiciona cerca de 1s antes de colar.", "Enumerations become a list and punctuation is fixed by an on-device model. Adds about 1s before pasting.")
                            : t("Indisponível: requer Apple Intelligence ativa neste Mac.", "Unavailable: requires Apple Intelligence enabled on this Mac.")
                    ) {
                        Toggle("", isOn: $settings.formatAsMarkdown)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!TranscriptFormatter.isAvailable)
                    }
                }

                SettingsGroup(t("Retorno", "Feedback")) {
                    SettingsRow(
                        title: t("Som", "Sound"),
                        subtitle: t("Um toque ao começar a ouvir e outro ao escrever.", "A tick when it starts listening and another when it writes.")
                    ) {
                        Toggle("", isOn: $settings.soundFeedback)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: settings.soundFeedback) { _, isOn in
                                guard isOn else { return }
                                Feedback.play(.start, sound: true, haptic: false)
                            }
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Retorno tátil", "Haptics"),
                        subtitle: t("Vibração no trackpad. Sem efeito em trackpad sem Force Touch.", "Trackpad vibration. No effect on trackpads without Force Touch.")
                    ) {
                        Toggle("", isOn: $settings.hapticFeedback)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: settings.hapticFeedback) { _, isOn in
                                guard isOn else { return }
                                Feedback.play(.start, sound: false, haptic: true)
                            }
                    }
                }

                SettingsGroup(t("Captura", "Capture")) {
                    SettingsRow(
                        title: t("Áudio dos outros participantes", "Audio from the other participants"),
                        subtitle: t("Grava o áudio do sistema num canal separado do seu microfone.", "Records system audio on a channel separate from your microphone.")
                    ) {
                        Toggle("", isOn: $settings.captureSystemAudio)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Mostrar ilha no topo da tela", "Show the island at the top of the screen"),
                        subtitle: t("Indicador junto ao notch enquanto a reunião grava.", "Indicator next to the notch while recording.")
                    ) {
                        Toggle("", isOn: $settings.showIsland)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsRefreshedAt = Date()
        }
    }
}

private struct PermissionRow: View {
    let permission: SystemPermission

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: permission.isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.system(size: 15))
                .foregroundStyle(permission.isGranted ? Color.green : Theme.highlight)

            VStack(alignment: .leading, spacing: 3) {
                Text(permission.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(permission.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if permission.isGranted {
                Text(t("Concedida", "Granted"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Button {
                    permission.requestIfPossible()
                } label: {
                    Text(t("Permitir", "Allow"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.6)

            VStack(spacing: 0) {
                content
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    init(title: String, subtitle: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}
