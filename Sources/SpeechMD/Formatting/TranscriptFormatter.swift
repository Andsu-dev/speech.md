import FoundationModels
import Foundation

/// Passa a transcrição crua pelo modelo on-device para virar Markdown.
enum TranscriptFormatter {
    private static let instructions = """
    Você formata transcrições de ditado em Markdown.

    REGRAS ABSOLUTAS:
    - Nunca remova, resuma ou reescreva palavras. Todo conteúdo falado deve aparecer.
    - Nunca adicione informação que não foi dita.
    - Corrija apenas pontuação, capitalização e quebras de linha.

    FORMATAÇÃO:
    - Se o texto enumerar itens, transforme-os em lista com "- ".
    - Mantenha como parágrafo comum o texto que não é enumeração.
    - Use **negrito** apenas onde o autor pedir ênfase explicitamente.

    Responda apenas com o texto formatado, sem comentários.
    """

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func format(_ raw: String) async -> String {
        guard isAvailable, raw.count > 12 else { return raw }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: raw)
            let formatted = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return preservesContent(raw: raw, formatted: formatted) ? formatted : raw
        } catch {
            return raw
        }
    }

    /// O modelo às vezes engole frases inteiras ao reformatar. Se muita palavra
    /// sumiu, o texto original vale mais do que a formatação.
    private static func preservesContent(raw: String, formatted: String) -> Bool {
        let rawWords = significantWords(raw)
        guard !rawWords.isEmpty else { return true }

        let formattedWords = Set(significantWords(formatted))
        let kept = rawWords.filter(formattedWords.contains).count
        return Double(kept) / Double(rawWords.count) >= 0.85
    }

    private static func significantWords(_ text: String) -> [String] {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 3 }
    }
}
