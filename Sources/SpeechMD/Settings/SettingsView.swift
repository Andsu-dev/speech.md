import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var permissionsRefreshedAt = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Configurações")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                SettingsGroup("Permissões") {
                    ForEach(Array(SystemPermission.allCases.enumerated()), id: \.element.id) { index, permission in
                        if index > 0 {
                            Divider().overlay(Theme.border)
                        }
                        PermissionRow(permission: permission)
                    }
                }
                .id(permissionsRefreshedAt)

                SettingsGroup("Atalho") {
                    SettingsRow(
                        title: "Iniciar e parar gravação",
                        subtitle: "Funciona com qualquer app em foco."
                    ) {
                        ShortcutRecorderView(binding: $settings.hotkey)
                    }
                }

                SettingsGroup("Transcrição") {
                    SettingsRow(
                        title: "Idioma",
                        subtitle: "Modelo baixado sob demanda, roda no dispositivo."
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
                        title: "Modo",
                        subtitle: "Latência menor ou transcrição mais precisa."
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

                SettingsGroup("Formatação") {
                    SettingsRow(
                        title: "Escrever em Markdown",
                        subtitle: TranscriptFormatter.isAvailable
                            ? "Enumerações viram lista e a pontuação é corrigida por um modelo no dispositivo. Adiciona cerca de 1s antes de colar."
                            : "Indisponível: requer Apple Intelligence ativa neste Mac."
                    ) {
                        Toggle("", isOn: $settings.formatAsMarkdown)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!TranscriptFormatter.isAvailable)
                    }
                }

                SettingsGroup("Retorno") {
                    SettingsRow(
                        title: "Som",
                        subtitle: "Um toque ao começar a ouvir e outro ao escrever."
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
                        title: "Retorno tátil",
                        subtitle: "Vibração no trackpad. Sem efeito em trackpad sem Force Touch."
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

                SettingsGroup("Captura") {
                    SettingsRow(
                        title: "Áudio dos outros participantes",
                        subtitle: "Grava o áudio do sistema num canal separado do seu microfone."
                    ) {
                        Toggle("", isOn: $settings.captureSystemAudio)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: "Mostrar ilha no topo da tela",
                        subtitle: "Indicador junto ao notch enquanto a reunião grava."
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
                Text("Concedida")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Button {
                    permission.requestIfPossible()
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
