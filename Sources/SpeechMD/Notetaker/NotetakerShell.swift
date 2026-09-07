import SwiftUI

/// Layout raiz: sidebar · conteúdo · coluna de stats.
struct NotetakerShell: View {
    let model: MeetingSession

    @State private var selection: NavSection = .dictation
    @State private var settings = AppSettings()
    @State private var island = IslandController()
    @State private var toggleHotkey = GlobalHotkey(id: 1)
    @State private var pushToTalkHotkey = GlobalHotkey(id: 2)
    @State private var dictation = DictationSession()
    @State private var files = FileTranscriptionModel()
    @State private var snippets = SnippetStore()
    @State private var isSidebarCollapsed = false
    @State private var meetings: [Meeting] = []
    @State private var meetingStartedAt: Date?
    @State private var elapsed: TimeInterval = 0
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
        .onAppear {
            registerHotkeys()
            dictation.onFinish = handleDictationOutcome
            dictation.onFailure = handleDictationFailure
        }
        .onChange(of: settings.hotkey) { _, _ in registerHotkeys() }
        .onChange(of: settings.pushToTalkHotkey) { _, _ in registerHotkeys() }
        .onChange(of: HotkeyCapture.shared.isCapturing) { _, isCapturing in
            if isCapturing {
                toggleHotkey.unregister()
                pushToTalkHotkey.unregister()
            } else {
                registerHotkeys()
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
                pushToTalkHotkey: settings.pushToTalkHotkey,
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

    private func handleDictationFailure(_ message: String) {
        island.isSessionActive = false
        island.isProcessing = false
        island.flashWarning(String(message.prefix(28)))
        playFeedback(.warning)
    }

    private func handleDictationOutcome(_ outcome: DictationOutcome) {
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

    private func registerHotkeys() {
        if settings.hotkey.isFunctionKey || settings.pushToTalkHotkey.isFunctionKey {
            GlobeKeyAction.disableIfNeeded()
        }

        guard !HotkeyCapture.shared.isCapturing else { return }

        // Dois bindings na mesma tecla fn brigam pelo mesmo evento: o toque que
        // começa o "segura pra falar" seria o mesmo que fecha o duplo toque.
        let shareFunctionKey = settings.hotkey.isFunctionKey && settings.pushToTalkHotkey.isFunctionKey
        if settings.hotkey != settings.pushToTalkHotkey, !shareFunctionKey {
            toggleHotkey.register(
                settings.hotkey,
                onPress: { toggleDictation() },
                onRelease: {}
            )
        }
        pushToTalkHotkey.register(
            settings.pushToTalkHotkey,
            onPress: { pushToTalkPressed() },
            onRelease: { pushToTalkReleased() }
        )
    }

    private func pushToTalkPressed() {
        guard !model.phase.isRunning else { return }
        // Duplo toque não tem "solta": vira liga/desliga, como o outro atalho.
        guard !settings.pushToTalkHotkey.isDoubleTap else {
            toggleDictation()
            return
        }
        guard !dictation.isRunning else { return }
        startDictation()
    }

    private func pushToTalkReleased() {
        guard dictation.isRunning, !settings.pushToTalkHotkey.isDoubleTap else { return }
        finishDictation()
    }

    private func toggleDictation() {
        guard !model.phase.isRunning else { return }
        dictation.isRunning ? finishDictation() : startDictation()
    }

    private func startDictation() {
        dictation.start(
            localeIdentifier: settings.localeIdentifier,
            mode: settings.recognitionMode,
            inputDeviceUID: settings.inputDeviceUID,
            contextualTerms: SpokenTerms.all(with: snippets.snippets.map(\.expansion)),
            formatAsMarkdown: settings.formatAsMarkdown,
            polishTerms: settings.polishTerms,
            expand: { snippets.expand($0) }
        )
        island.isSessionActive = true
        island.isVisible = settings.showIsland
        playFeedback(.start)
    }

    private func finishDictation() {
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
            model.inputDeviceUID = settings.inputDeviceUID
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
