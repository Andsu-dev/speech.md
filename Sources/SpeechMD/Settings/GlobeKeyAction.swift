import Foundation

/// A ação da tecla 🌐 é resolvida pelo sistema antes de qualquer app ver o
/// evento, então usar fn como atalho exige desligá-la nos ajustes globais.
enum GlobeKeyAction {
    static var isDisabled: Bool {
        let value = CFPreferencesCopyValue(
            "AppleFnUsageType" as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? Int
        return value == 0
    }

    static func disable() {
        CFPreferencesSetValue(
            "AppleFnUsageType" as CFString,
            0 as CFNumber,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}
