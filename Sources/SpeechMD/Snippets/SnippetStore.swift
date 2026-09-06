import Foundation
import Observation

struct Snippet: Identifiable, Codable, Equatable {
    var id = UUID()
    var trigger: String
    var expansion: String

    var isValid: Bool {
        !trigger.trimmingCharacters(in: .whitespaces).isEmpty
            && !expansion.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

@MainActor
@Observable
final class SnippetStore {
    private(set) var snippets: [Snippet] = []

    private let defaults = UserDefaults.standard
    private let key = "snippets"

    init() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return
        }
        snippets = decoded
    }

    func save(_ snippet: Snippet) {
        guard snippet.isValid else { return }
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }
        persist()
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        persist()
    }

    /// Troca os gatilhos falados pelo texto salvo.
    ///
    /// Gatilhos mais longos primeiro: senão "meu email" consumiria o começo de
    /// "meu email pessoal" e o atalho mais específico nunca casaria.
    func expand(_ text: String) -> String {
        var result = text
        for snippet in snippets.sorted(by: { $0.trigger.count > $1.trigger.count }) {
            let trigger = snippet.trigger.trimmingCharacters(
                in: .whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)
            )
            guard !trigger.isEmpty else { continue }

            // Busca a partir de um índice que avança: reescanear do início
            // faria loop infinito quando a expansão contém o próprio gatilho.
            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result.range(
                      of: trigger,
                      options: [.caseInsensitive, .diacriticInsensitive],
                      range: searchStart..<result.endIndex
                  ) {
                result.replaceSubrange(range, with: snippet.expansion)
                guard let next = result.index(
                    range.lowerBound,
                    offsetBy: snippet.expansion.count,
                    limitedBy: result.endIndex
                ) else { break }
                searchStart = next
            }
        }
        return result
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        defaults.set(data, forKey: key)
    }
}
