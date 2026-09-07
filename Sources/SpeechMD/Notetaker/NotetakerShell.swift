import SwiftUI

/// Layout raiz: sidebar · conteúdo · coluna de stats.
struct NotetakerShell: View {
    let model: MeetingSession

    @State private var selection: NavSection = .dictation
    @State private var settings = AppSettings()
    @State private var island = IslandController()
    @State private var hotkey = GlobalHotkey()
    @State private var dictation = DictationSession()
    @State private var files = FileTranscriptionModel()
    @State private var snippets = SnippetStore()
    @State private var isSidebarCollapsed = false
    @State private var meetings: [Meeting] = []
    @State private var meetingStartedAt: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var pressedAt: Date?
    @State private var isLatched = false
    @State private var secondTapWindow: Task<Void, Never>?

    /// Acima disso o atalho conta como "segurar", não como toque.
    private static let tapThreshold: TimeInterval = 0.35
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection, isCollapsed: $isSidebarCollapsed)

            HStack(alignment: .top, spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selection == .notetaker, !meetings.isEmpty, !model.phase.isRunning {
                    StatsRailView(stats: UsageStats(meetings: meetings))
                        .padding(.top, 30)
                        .padding(.trailing, 30)
                }
            }
            .background(Theme.canvas)
        }
        .id(settings.localeIdentifier)
        .frame(minWidth: 1_060, minHeight: 700)
        .background(Theme.canvas)
        .onAppear { registerHotkey() }
        .onChange(of: settings.hotkey) { _, _ in registerHotkey() }
        .onChange(of: dictation.state) { _, state in
            guard case .failed(let message) = state else { return }
            island.isSessionActive = false
            island.flashWarning(String(message.prefix(28)))
            playFeedback(.warning)
        }
        .onChange(of: dictation.outcome) { _, outcome in
            guard let outcome else { return }
            island.isProcessing = false
            if outcome.needsCopy {
                island.showResult(outcome.text)
                playFeedback(.warning)
            } else {
                island.isVisible = false
                if !outcome.text.isEmpty {
                    playFeedback(.finish)
                }
            }
        }
        .onChange(of: model.phase) { _, phase in
            guard case .failed = phase else { return }
            island.isSessionActive = false
            island.isVisible = false
            meetingStartedAt = nil
        }
        .task(id: meetingStartedAt) {
            guard let startedAt = meetingStartedAt else { return }
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .dictation:
            DictationView(
                session: dictation,
                hotkey: settings.hotkey,
                onToggle: toggleDictation
            )
        case .notetaker:
            MeetingFeedView(
                days: MeetingDay.group(meetings),
                model: model,
                elapsed: elapsed,
                capturesSystemAudio: settings.captureSystemAudio,
                onStartMeeting: toggleMeeting,
                onUseMicrophoneOnly: {
                    settings.captureSystemAudio = false
                    toggleMeeting()
                }
            )
        case .files:
            FileTranscriptionView(
                model: files,
                onChooseFile: {
                    files.chooseFile(
                        localeIdentifier: settings.localeIdentifier,
                        mode: settings.recognitionMode
                    )
                },
                onDrop: { url in
                    files.transcribe(
                        url: url,
                        localeIdentifier: settings.localeIdentifier,
                        mode: settings.recognitionMode
                    )
                }
            )
        case .dictionary:
            SnippetsView(store: snippets)
        case .settings:
            SettingsView(settings: settings)
        }
    }

    private func registerHotkey() {
        hotkey.register(
            settings.hotkey,
            onPress: { hotkeyPressed() },
            onRelease: { hotkeyReleased() }
        )
    }

    /// Atalho global = ditado: é o único que precisa funcionar de dentro de
    /// outro app. Reunião e arquivo são acionados pela própria janela.
    private func hotkeyPressed() {
        guard !model.phase.isRunning else { return }

        if isLatched {
            isLatched = false
            secondTapWindow?.cancel()
            secondTapWindow = nil
            finishDictation()
            return
        }

        if dictation.isRunning, secondTapWindow != nil {
            secondTapWindow?.cancel()
            secondTapWindow = nil
            isLatched = true
            return
        }

        pressedAt = Date()
        startDictation()
    }

    /// Soltar rápido não encerra na hora: é preciso dar tempo do segundo toque
    /// chegar, senão o duplo toque nunca aconteceria.
    private func hotkeyReleased() {
        guard dictation.isRunning, let pressedAt else { return }
        let held = Date().timeIntervalSince(pressedAt)
        self.pressedAt = nil

        guard held < Self.tapThreshold else {
            finishDictation()
            return
        }

        secondTapWindow = Task {
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled else { return }
            secondTapWindow = nil
            guard !isLatched else { return }
            finishDictation()
        }
    }

    private func toggleDictation() {
        guard !model.phase.isRunning else { return }
        dictation.isRunning ? finishDictation() : startDictation()
    }

    private func startDictation() {
        dictation.start(
            localeIdentifier: settings.localeIdentifier,
            mode: settings.recognitionMode,
            formatAsMarkdown: settings.formatAsMarkdown,
            expand: { snippets.expand($0) }
        )
        island.isSessionActive = true
        island.isVisible = settings.showIsland
        playFeedback(.start)
    }

    private func finishDictation() {
        isLatched = false
        dictation.finish()
        island.isSessionActive = false
        island.warning = nil
        island.isProcessing = true
    }

    private func playFeedback(_ kind: Feedback.Kind) {
        Feedback.play(
            kind,
            sound: settings.soundFeedback,
            haptic: settings.hapticFeedback
        )
    }

    private func toggleMeeting() {
        if model.phase.isRunning {
            finishMeeting()
        } else {
            model.localeIdentifier = settings.localeIdentifier
            model.recognitionMode = settings.recognitionMode
            if settings.captureSystemAudio {
                model.startCall()
            } else {
                model.startMicrophone()
            }
            meetingStartedAt = Date()
            elapsed = 0
            island.isSessionActive = true
            island.isVisible = settings.showIsland
        }
    }

    private func finishMeeting() {
        let startedAt = meetingStartedAt ?? Date()
        let duration = Date().timeIntervalSince(startedAt)
        let you = model.youTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let others = model.othersTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        model.stop()
        island.isSessionActive = false
        island.isVisible = false
        meetingStartedAt = nil
        elapsed = 0
        guard !you.isEmpty || !others.isEmpty else { return }

        let excerpt = [you, others].first { !$0.isEmpty } ?? ""
        meetings.insert(
            Meeting(
                title: t(
                    "Reunião de \(Meeting.titleFormatter.string(from: startedAt))",
                    "Meeting at \(Meeting.titleFormatter.string(from: startedAt))"
                ),
                startedAt: startedAt,
                duration: duration,
                participants: others.isEmpty ? 1 : 2,
                excerpt: excerpt,
                wordCount: (you + " " + others).split(separator: " ").count
            ),
            at: 0
        )
    }
}
