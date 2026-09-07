import Foundation

enum Language {
    nonisolated(unsafe) static var isEnglish = false

    static func matches(localeIdentifier: String) -> Bool {
        localeIdentifier.hasPrefix("en")
    }
}

func t(_ portuguese: String, _ english: String) -> String {
    Language.isEnglish ? english : portuguese
}
