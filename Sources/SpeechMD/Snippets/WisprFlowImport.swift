import Foundation

/// Traz o dicionário do Wispr Flow pra cá, pra ninguém ter que recadastrar
/// tudo na mão. Ele guarda em um SQLite local, na tabela `Dictionary`.
enum WisprFlowImport {
    /// Onde o app dele mora. Nada é escrito nesse arquivo: a leitura é
    /// readonly e num processo separado.
    static var databaseURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Wispr Flow/flow.sqlite", directoryHint: .notDirectory)
    }

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: databaseURL.path(percentEncoded: false))
    }

    /// Lê os atalhos. Linha com `replacement` é substituição de texto e vira
    /// atalho igual; linha sem é só vocabulário (nome próprio, termo técnico),
    /// e entra apontando pra si mesma — assim ela chega no `contextualStrings`
    /// e enviesa o reconhecimento sem trocar nada no texto.
    static func read(from url: URL? = nil) throws -> [Snippet] {
        let source = url ?? databaseURL
        switch source.pathExtension.lowercased() {
        case "json": return try readJSON(source)
        case "csv", "tsv", "txt": return try readCSV(source)
        default: return try readSQLite(source)
        }
    }

    private static func readSQLite(_ url: URL) throws -> [Snippet] {
        let query = """
        select phrase, replacement from Dictionary
        where isDeleted = 0 and phrase is not null and trim(phrase) <> ''
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-json", "-readonly", url.path(percentEncoded: false), query
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()

        // Ler antes do wait: um dicionário grande enche o buffer do pipe e o
        // processo fica travado esperando alguém consumir.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ImportError.unreadable
        }

        return rows.compactMap { row in
            guard let phrase = (row["phrase"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !phrase.isEmpty else {
                return nil
            }
            let replacement = (row["replacement"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Snippet(trigger: phrase, expansion: replacement?.isEmpty == false
                ? replacement!
                : phrase)
        }
    }

    /// Export de outro app: lista de objetos com nomes variados pro par
    /// gatilho/texto. Aceita os que aparecem na prática.
    private static func readJSON(_ url: URL) throws -> [Snippet] {
        let data = try Data(contentsOf: url)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ImportError.unreadable
        }
        return rows.compactMap { row in
            let trigger = ["trigger", "phrase", "word", "key", "from"]
                .compactMap { row[$0] as? String }.first
            let expansion = ["expansion", "replacement", "value", "to"]
                .compactMap { row[$0] as? String }.first
            return snippet(trigger: trigger, expansion: expansion)
        }
    }

    /// Duas colunas: gatilho e texto. Uma coluna só é vocabulário.
    private static func readCSV(_ url: URL) throws -> [Snippet] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n").compactMap { line in
            let columns = line.split(separator: line.contains("\t") ? "\t" : ",", maxSplits: 1)
            let unquote: (Substring) -> String = {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            return snippet(
                trigger: columns.first.map(unquote),
                expansion: columns.count > 1 ? unquote(columns[1]) : nil
            )
        }
    }

    /// Sem texto de troca a linha é só vocabulário: entra apontando pra si
    /// mesma, o que não muda nada no ditado mas enviesa o reconhecimento.
    private static func snippet(trigger: String?, expansion: String?) -> Snippet? {
        guard let trigger = trigger?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trigger.isEmpty else { return nil }
        let expansion = expansion?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Snippet(trigger: trigger, expansion: expansion?.isEmpty == false ? expansion! : trigger)
    }

    enum ImportError: LocalizedError {
        case unreadable

        var errorDescription: String? {
            t("Não deu pra ler o dicionário do Wispr Flow.",
              "Could not read the Wispr Flow dictionary.")
        }
    }
}
