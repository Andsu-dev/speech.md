import SwiftUI

@main
struct SpeechMDApp: App {
    @State private var meetings = MeetingSession()

    var body: some Scene {
        WindowGroup {
            NotetakerShell(model: meetings)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
