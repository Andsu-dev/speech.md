import AppKit
import Foundation
import Observation

/// Preferências do app, persistidas em UserDefaults.
@MainActor
@Observable
final class AppSettings {
    var hotkey: HotkeyBinding {
        didSet { save(hotkey, forKey: Keys.hotkey) }
    }

    var localeIdentifier: String {
        didSet {
            defaults.set(localeIdentifier, forKey: Keys.locale)
            Language.isEnglish = Language.matches(localeIdentifier: localeIdentifier)
        }
    }

    var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            appearance.apply()
        }
    }

    /// UID do microfone escolhido; vazio significa o padrão do sistema.
    var inputDeviceUID: String {
        didSet { defaults.set(inputDeviceUID, forKey: Keys.inputDeviceUID) }
    }

    var recognitionMode: RecognitionMode {
        didSet { defaults.set(recognitionMode.rawValue, forKey: Keys.recognitionMode) }
    }

    var captureSystemAudio: Bool {
        didSet { defaults.set(captureSystemAudio, forKey: Keys.captureSystemAudio) }
    }

    var showIsland: Bool {
        didSet { defaults.set(showIsland, forKey: Keys.showIsland) }
    }

    /// Ilha parada na borda quando não há gravação, servindo de botão.
    var islandAlwaysVisible: Bool {
        didSet { defaults.set(islandAlwaysVisible, forKey: Keys.islandAlwaysVisible) }
    }

    var formatAsMarkdown: Bool {
        didSet { defaults.set(formatAsMarkdown, forKey: Keys.formatAsMarkdown) }
    }

    /// Troca palavrão por linguagem neutra antes de colar.
    var softenLanguage: Bool {
        didSet { defaults.set(softenLanguage, forKey: Keys.softenLanguage) }
    }

    var polishTerms: Bool {
        didSet { defaults.set(polishTerms, forKey: Keys.polishTerms) }
    }

    var soundFeedback: Bool {
        didSet { defaults.set(soundFeedback, forKey: Keys.soundFeedback) }
    }

    var hapticFeedback: Bool {
        didSet { defaults.set(hapticFeedback, forKey: Keys.hapticFeedback) }
    }

    private let defaults = UserDefaults.standard

    init() {
        hotkey = Self.load(HotkeyBinding.self, forKey: Keys.hotkey) ?? .fn
        localeIdentifier = defaults.string(forKey: Keys.locale) ?? "pt-BR"
        appearance = defaults.string(forKey: Keys.appearance)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        inputDeviceUID = defaults.string(forKey: Keys.inputDeviceUID) ?? ""
        recognitionMode = defaults.string(forKey: Keys.recognitionMode)
            .flatMap(RecognitionMode.init(rawValue:)) ?? .quality
        captureSystemAudio = defaults.object(forKey: Keys.captureSystemAudio) as? Bool ?? true
        showIsland = defaults.object(forKey: Keys.showIsland) as? Bool ?? true
        islandAlwaysVisible = defaults.object(forKey: Keys.islandAlwaysVisible) as? Bool ?? true
        formatAsMarkdown = defaults.object(forKey: Keys.formatAsMarkdown) as? Bool ?? true
        polishTerms = defaults.object(forKey: Keys.polishTerms) as? Bool ?? true
        softenLanguage = defaults.object(forKey: Keys.softenLanguage) as? Bool ?? false
        soundFeedback = defaults.object(forKey: Keys.soundFeedback) as? Bool ?? true
        hapticFeedback = defaults.object(forKey: Keys.hapticFeedback) as? Bool ?? true
        Language.isEnglish = Language.matches(localeIdentifier: localeIdentifier)
        appearance.apply()
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Keys {
        static let hotkey = "hotkey"
        static let locale = "localeIdentifier"
        static let appearance = "appearance"
        static let inputDeviceUID = "inputDeviceUID"
        static let recognitionMode = "recognitionMode"
        static let captureSystemAudio = "captureSystemAudio"
        static let showIsland = "showIsland"
        static let islandAlwaysVisible = "islandAlwaysVisible"
        static let formatAsMarkdown = "formatAsMarkdown"
        static let polishTerms = "polishTerms"
        static let softenLanguage = "softenLanguage"
        static let soundFeedback = "soundFeedback"
        static let hapticFeedback = "hapticFeedback"
    }
}
