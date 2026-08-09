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
        didSet { defaults.set(localeIdentifier, forKey: Keys.locale) }
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

    var formatAsMarkdown: Bool {
        didSet { defaults.set(formatAsMarkdown, forKey: Keys.formatAsMarkdown) }
    }

    var soundFeedback: Bool {
        didSet { defaults.set(soundFeedback, forKey: Keys.soundFeedback) }
    }

    var hapticFeedback: Bool {
        didSet { defaults.set(hapticFeedback, forKey: Keys.hapticFeedback) }
    }

    private let defaults = UserDefaults.standard

    init() {
        hotkey = Self.load(HotkeyBinding.self, forKey: Keys.hotkey) ?? .default
        localeIdentifier = defaults.string(forKey: Keys.locale) ?? "pt-BR"
        recognitionMode = defaults.string(forKey: Keys.recognitionMode)
            .flatMap(RecognitionMode.init(rawValue:)) ?? .lowLatency
        captureSystemAudio = defaults.object(forKey: Keys.captureSystemAudio) as? Bool ?? true
        showIsland = defaults.object(forKey: Keys.showIsland) as? Bool ?? true
        formatAsMarkdown = defaults.object(forKey: Keys.formatAsMarkdown) as? Bool ?? false
        soundFeedback = defaults.object(forKey: Keys.soundFeedback) as? Bool ?? true
        hapticFeedback = defaults.object(forKey: Keys.hapticFeedback) as? Bool ?? true
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
        static let recognitionMode = "recognitionMode"
        static let captureSystemAudio = "captureSystemAudio"
        static let showIsland = "showIsland"
        static let formatAsMarkdown = "formatAsMarkdown"
        static let soundFeedback = "soundFeedback"
        static let hapticFeedback = "hapticFeedback"
    }
}
