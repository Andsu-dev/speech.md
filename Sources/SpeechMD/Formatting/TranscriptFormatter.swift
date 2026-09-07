import FoundationModels
import Foundation

/// Passa a transcrição crua pelo modelo on-device para virar Markdown.
@MainActor
enum TranscriptFormatter {
    private static var session: LanguageModelSession?

    /// Abre a sessão quando a gravação começa: a primeira resposta do modelo
    /// custa o carregamento dele, e a fala é tempo de sobra para pagar isso.
    static func prewarm() {
        guard isAvailable else { return }
        let session = LanguageModelSession(instructions: instructions)
        session.prewarm()
        self.session = session
    }

    private static let instructions = """
    Você formata transcrições de ditado em Markdown.

    REGRAS ABSOLUTAS:
    - Nunca remova, resuma ou reescreva palavras. Todo conteúdo falado deve aparecer.
    - Nunca adicione informação que não foi dita.
    - Corrija apenas pontuação, capitalização e quebras de linha.

    FORMATAÇÃO:
    - Uma frase solta é um parágrafo. Nunca vire lista.
    - Só use lista, com "- ", quando houver dois ou mais itens enumerados.
    - Nunca use negrito, itálico, título ou numeração.

    Responda apenas com o texto formatado, sem comentários.
    """

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func format(_ raw: String) async -> String {
        guard isAvailable, raw.count > 12 else { return raw }

        do {
            let session = self.session ?? LanguageModelSession(instructions: instructions)
            self.session = nil
            let response = try await session.respond(
                to: raw,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: raw.count)
            )
            let formatted = sanitize(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
            return preservesContent(raw: raw, formatted: formatted) ? formatted : raw
        } catch {
            return raw
        }
    }

    private static func sanitize(_ formatted: String) -> String {
        let marker = /^[ \t]*(?:[-*+]|\d+[.)])[ \t]+/
        var lines = formatted.components(separatedBy: .newlines)
        if lines.count(where: { $0.contains(marker) }) < 2 {
            lines = lines.map { $0.replacing(marker, with: "") }
        }
        return lines
            .joined(separator: "\n")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
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
