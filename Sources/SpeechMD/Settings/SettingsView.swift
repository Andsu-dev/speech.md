import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @State private var permissionsRefreshedAt = Date()
    @State private var inputDevices = AudioInputDevice.available


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
                        title: t("Tecla do ditado", "Dictation key"),
                        subtitle: t("Segure para falar: ao soltar, o texto é colado. Dois toques rápidos travam a gravação, e o toque seguinte encerra.", "Hold to speak: on release the text is pasted. Two quick taps keep it recording, and the next tap ends it.")
                    ) {
                        ShortcutRecorderView(binding: $settings.hotkey)
                    }

                }

                SettingsGroup(t("Aparência", "Appearance")) {
                    SettingsRow(
                        title: t("Tema", "Theme"),
                        subtitle: t("Sistema acompanha o ajuste do macOS.", "System follows the macOS setting.")
                    ) {
                        SettingsPicker(
                            selection: $settings.appearance,
                            options: AppAppearance.allCases.map { ($0, $0.label) }
                        )
                    }
                }

                SettingsGroup(t("Transcrição", "Transcription")) {
                    SettingsRow(
                        title: t("Idioma da fala", "Spoken language"),
                        subtitle: t("O idioma que você fala. Não traduz: falar português com inglês selecionado sai embaralhado. O modelo é baixado sob demanda e roda no dispositivo.", "The language you speak. It does not translate: speaking Portuguese with English selected comes out scrambled. The model downloads on demand and runs on device.")
                    ) {
                        SettingsPicker(
                            selection: $settings.localeIdentifier,
                            options: [
                                ("pt-BR", "Português (BR)"),
                                ("en-US", "English (US)"),
                                ("es-ES", "Español")
                            ]
                        )
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Microfone", "Microphone"),
                        subtitle: t("Vale para o ditado e para a sua trilha nas reuniões. Se o aparelho escolhido estiver desconectado, o padrão do sistema assume.", "Applies to dictation and to your track in meetings. If the chosen device is disconnected, the system default takes over.")
                    ) {
                        SettingsPicker(
                            selection: $settings.inputDeviceUID,
                            options: [("", t("Padrão do sistema", "System default"))]
                                + inputDevices.map { ($0.id, $0.name) }
                        )
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Modo", "Mode"),
                        subtitle: t("Latência menor ou transcrição mais precisa.", "Lower latency or more accurate transcription.")
                    ) {
                        SettingsPicker(
                            selection: $settings.recognitionMode,
                            options: RecognitionMode.allCases.map { ($0, $0.label) }
                        )
                    }
                }

                SettingsGroup(t("Formatação", "Formatting")) {
                    SettingsRow(
                        title: t("Escrever em Markdown", "Write in Markdown"),
                        subtitle: TranscriptFormatter.isAvailable
                            ? t("Enumerações viram lista e a pontuação é corrigida por um modelo no dispositivo.", "Enumerations become a list and punctuation is fixed by an on-device model.")
                            : t("Indisponível: requer Apple Intelligence ativa neste Mac.", "Unavailable: requires Apple Intelligence enabled on this Mac.")
                    ) {
                        Toggle("", isOn: $settings.formatAsMarkdown)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!TranscriptFormatter.isAvailable)
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Suavizar linguagem", "Soften language"),
                        subtitle: LanguageSoftener.isAvailable
                            ? t("Reescreve o que você falou em linguagem educada, mantendo o pedido e a urgência.", "Rewrites what you said in polite language, keeping the request and the urgency.")
                            : t("Indisponível: requer Apple Intelligence ativa neste Mac.", "Unavailable: requires Apple Intelligence enabled on this Mac.")
                    ) {
                        Toggle("", isOn: $settings.softenLanguage)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!LanguageSoftener.isAvailable)
                    }

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Corrigir termos", "Fix terms"),
                        subtitle: TermPolisher.isAvailable
                            ? t("Corrige palavras que o dicionário não reconhece.", "Fixes words the dictionary doesn't know.")
                            : t("Indisponível: requer Apple Intelligence ativa neste Mac.", "Unavailable: requires Apple Intelligence enabled on this Mac.")
                    ) {
                        Toggle("", isOn: $settings.polishTerms)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!TermPolisher.isAvailable)
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

                    Divider().overlay(Theme.border)

                    SettingsRow(
                        title: t("Deixar a ilha sempre na tela", "Keep the island on screen"),
                        subtitle: t("Parada ela fica na borda com um microfone: clicar começa a gravar. Arraste pra escolher a borda.", "At rest it sits on the edge with a microphone: click to start recording. Drag it to pick the edge.")
                    ) {
                        Toggle("", isOn: $settings.islandAlwaysVisible)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!settings.showIsland)
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsRefreshedAt = Date()
            inputDevices = AudioInputDevice.available
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
                        .background(Theme.contrastSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

/// `Picker` e `Menu` no macOS são controle AppKit por baixo: ignoram o
/// `.frame` e ficam do tamanho da opção mais longa, e o label virava só um
/// título — o fundo desenhado sumia. Então o botão é SwiftUI (largura, cor e
/// animação nossas) e a lista continua sendo um `NSMenu` de verdade, com
/// teclado e marca de selecionado de graça.
private struct SettingsPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    @State private var isHovering = false
    @State private var isOpen = false
    @State private var anchor = MenuAnchorView()

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(currentLabel)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .contentTransition(.opacity)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHovering || isOpen ? Theme.textPrimary : Theme.textTertiary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
        }
        .padding(.horizontal, 10)
        .frame(width: Theme.controlWidth, height: 28)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.surfaceHover)
                .brightness(isHovering && !isOpen ? 0.035 : 0)
                .shadow(color: .black.opacity(isOpen ? 0.22 : 0), radius: 6, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isOpen ? Theme.accent : Theme.border, lineWidth: 1)
        }
        .scaleEffect(isOpen ? 0.985 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .pointerStyle(.link)
        .onHover { isHovering = $0 }
        .onTapGesture { present() }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isOpen)
        .animation(.snappy(duration: 0.2), value: currentLabel)
        .background { MenuAnchor(view: anchor) }
    }

    private func present() {
        isOpen = true
        PopUpMenu.show(
            options.enumerated().map { index, option in
                PopUpMenu.Item(option.label, isOn: option.value == selection) {
                    selection = options[index].value
                }
            },
            from: anchor
        )
        // O menu trava a runloop enquanto está aberto, então isto só roda
        // quando ele fecha.
        DispatchQueue.main.async { isOpen = false }
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
                .frame(width: Theme.controlWidth, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}
