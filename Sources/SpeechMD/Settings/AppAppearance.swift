import AppKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var label: String {
        switch self {
        case .system: t("Sistema", "System")
        case .light: t("Claro", "Light")
        case .dark: t("Escuro", "Dark")
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum HotkeyMode: String, CaseIterable, Identifiable {
    case toggle
    case hold

    var id: Self { self }

    var label: String {
        switch self {
        case .toggle: t("Clicar e gravar", "Click and record")
        case .hold: t("Pressione para falar", "Push to talk")
        }
    }
}
