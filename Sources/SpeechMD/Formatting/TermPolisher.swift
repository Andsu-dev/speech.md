import AppKit
import FoundationModels
import Foundation

/// Corrige a grafia de estrangeirismos que o transcritor ouve errado
/// ("brifing" -> "briefing"), sem tocar na transcrição em si.
///
/// Só as palavras que o corretor do sistema não reconhece vão ao modelo, e o
/// modelo responde palavra por palavra: a frase nunca é reescrita, então o
/// custo é proporcional ao número de termos suspeitos, não ao tamanho do texto.
@MainActor
enum TermPolisher {
    private static let instructions = """
    Você corrige a grafia de palavras estrangeiras ditadas em voz alta.

    Recebe uma palavra por linha, como o transcritor ouviu.
    Responda uma linha por palavra, na mesma ordem, com a grafia correta no
    idioma de origem. Exemplo: "brifing" vira "briefing".

    Se a palavra já estiver correta, se for nome próprio ou se você não
    reconhecer o termo, repita exatamente a palavra recebida.

    Responda só as palavras, uma por linha, sem numeração e sem comentário.
    """

    /// No máximo isso de palavra por ditado: cada palavra a mais é token a
    /// mais, e o custo aparece direto na espera antes de colar.
    private static let wordLimit = 3

    private static var cache: [String: String] = [:]
    private static var session: LanguageModelSession?

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Abre a sessão enquanto a pessoa ainda está falando, para o modelo já
    /// estar quente na hora de colar.
    static func prewarm() {
        guard isAvailable else { return }
        let session = LanguageModelSession(instructions: instructions)
        session.prewarm()
        self.session = session
    }

    static func polish(_ text: String, localeIdentifier: String) async -> String {
        guard isAvailable else { return text }

        let suspects = suspectWords(in: text, localeIdentifier: localeIdentifier)
        guard !suspects.isEmpty else { return text }

        let known = suspects.filter { cache[$0.lowercased()] != nil }
        let unknown = Array(suspects.filter { cache[$0.lowercased()] == nil }.prefix(wordLimit))

        if !unknown.isEmpty {
            await learn(unknown)
        }

        var result = text
        for word in known + unknown {
            guard let correction = cache[word.lowercased()], correction != word.lowercased() else { continue }
            result = replace(word, with: correction, in: result)
        }
        return result
    }

    private static func learn(_ words: [String]) async {
        // A sessão do prewarm serve uma vez só: reusá-la acumularia o histórico
        // das correções anteriores no contexto de cada ditado seguinte.
        let session = self.session ?? LanguageModelSession(instructions: instructions)
        self.session = nil

        let options = GenerationOptions(
            sampling: .greedy,
            maximumResponseTokens: words.count * 8
        )

        guard let response = try? await session.respond(
            to: words.joined(separator: "\n"),
            options: options
        ) else { return }

        let corrections = response.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard corrections.count == words.count else { return }

        for (word, correction) in zip(words, corrections) where accepts(correction, for: word) {
            cache[word.lowercased()] = correction.lowercased()
        }
    }

    /// O modelo às vezes responde uma frase, uma tradução ou uma palavra sem
    /// relação nenhuma. Só passa o que ainda parece a mesma palavra.
    private static func accepts(_ correction: String, for word: String) -> Bool {
        guard correction.count >= 2,
              correction.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" }),
              abs(correction.count - word.count) <= 4
        else { return false }

        return correction.first?.lowercased() == word.first?.lowercased()
    }

    /// Palavras que o dicionário do idioma não conhece. Nome próprio e gíria
    /// caem aqui também, mas para esses o modelo devolve a mesma palavra.
    private static func suspectWords(in text: String, localeIdentifier: String) -> [String] {
        let checker = NSSpellChecker.shared
        let language = localeIdentifier.replacingOccurrences(of: "-", with: "_")
        var found: [String] = []
        var offset = 0

        while offset < text.utf16.count {
            let range = checker.checkSpelling(
                of: text,
                startingAt: offset,
                language: language,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            guard range.location != NSNotFound, range.length > 0 else { break }
            offset = range.location + range.length

            guard let swiftRange = Range(range, in: text) else { continue }
            let word = String(text[swiftRange])
            guard word.count >= 4,
                  word.allSatisfy(\.isLetter),
                  !found.contains(where: { $0.lowercased() == word.lowercased() })
            else { continue }
            found.append(word)
        }
        return found
    }

    private static func replace(_ word: String, with correction: String, in text: String) -> String {
        let cased = word.first?.isUppercase == true ? correction.capitalized : correction
        guard let pattern = try? Regex("\\b\(NSRegularExpression.escapedPattern(for: word))\\b") else {
            return text
        }
        return text.replacing(pattern, with: cased)
    }
}
