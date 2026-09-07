import Foundation

/// A ação da tecla 🌐 é resolvida pelo sistema antes de qualquer app ver o
/// evento — nem um `CGEventTap` em `.cghidEventTap` segura, ele engole press e
/// release e o painel abre mesmo assim. Só desligando a ação nos ajustes.
enum GlobeKeyAction {
    private static var key: CFString { "AppleFnUsageType" as CFString }

    /// O domínio que a UI de Ajustes grava. O valor no domínio global é legado:
    /// estava em 0 desde sempre e o painel abria assim mesmo.
    private static var domain: CFString { "com.apple.HIToolbox" as CFString }

    /// "Não Fazer Nada" em "Pressione a tecla 🌐 para".
    private static let doNothing = 0

    static func disableIfNeeded() {
        CFPreferencesSetValue(key, doNothing as CFNumber, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.keyboard.fnstatedidchange"),
            object: nil, userInfo: nil, deliverImmediately: true
        )
    }
}
