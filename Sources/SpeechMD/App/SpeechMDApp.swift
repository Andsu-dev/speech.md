import SwiftUI

@main
struct SpeechMDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var meetings = MeetingSession()

    var body: some Scene {
        Window("speech.md", id: "main") {
            NotetakerShell(model: meetings)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
