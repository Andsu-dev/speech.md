import Foundation

/// Termos que o reconhecedor recebe como pista antes de ouvir.
///
/// É o caminho barato para os estrangeirismos: o `SpeechAnalyzer` enviesa o
/// reconhecimento com essa lista durante a própria transcrição, então "function"
/// sai certo sem nenhuma passada de correção depois — custo zero de latência.
enum SpokenTerms {
    /// Vocabulário de quem fala de trabalho e de código misturando inglês.
    static let technical = [
        "briefing", "deadline", "feedback", "meeting", "call", "budget",
        "insight", "kickoff", "follow-up", "onboarding", "review", "sprint",
        "backlog", "roadmap", "milestone", "stakeholder", "board",
        "function", "class", "array", "string", "boolean", "cache", "commit",
        "merge", "branch", "pull request", "deploy", "build", "release",
        "bug", "feature", "refactor", "endpoint", "payload", "token",
        "framework", "library", "package", "runtime", "backend", "frontend",
        "design", "layout", "dashboard", "landing page", "template",
        "workspace", "pipeline", "workflow", "dropdown", "checkbox", "toggle"
    ]

    /// A lista final: os termos fixos mais o que a pessoa cadastrou no
    /// dicionário de voz, que é onde moram os nomes próprios dela.
    static func all(with custom: [String] = []) -> [String] {
        let extra = custom
            .flatMap { $0.split(separator: " ").map(String.init) }
            .filter { $0.count >= 3 }
        return Array(Set(technical + extra))
    }
}
