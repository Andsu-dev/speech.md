import Foundation

enum NavSection: String, CaseIterable, Identifiable {
    case dictation = "Falar"
    case notetaker = "Reuniões"
    case files = "Arquivos"
    case dictionary = "Dicionário"
    case settings = "Configurações"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: t("Falar", "Speak")
        case .notetaker: t("Reuniões", "Meetings")
        case .files: t("Arquivos", "Files")
        case .dictionary: t("Dicionário", "Dictionary")
        case .settings: t("Configurações", "Settings")
        }
    }

    /// Configurações mora no rodapé da sidebar, junto dos links.
    static var primary: [NavSection] {
        allCases.filter { $0 != .settings }
    }

    var systemImage: String {
        switch self {
        case .dictation: "mic"
        case .notetaker: "record.circle"
        case .files: "waveform.badge.plus"
        case .dictionary: "text.book.closed"
        case .settings: "gearshape"
        }
    }
}

enum Links {
    static let repository = URL(string: "https://github.com/andersonbrdev/speech-md")!
    static let profile = URL(string: "https://x.com/andersonbrdev")!
}

struct Meeting: Identifiable {
    let id = UUID()
    let title: String
    let startedAt: Date
    let duration: TimeInterval
    let participants: Int
    let excerpt: String
    let wordCount: Int
    var isLive = false

    var formattedTime: String {
        Meeting.timeFormatter.string(from: startedAt)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        guard minutes >= 60 else { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)min"
    }

    static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// Reuniões agrupadas por dia, na ordem em que aparecem no feed.
struct MeetingDay: Identifiable {
    let id = UUID()
    let label: String
    let meetings: [Meeting]

    static func group(_ meetings: [Meeting]) -> [MeetingDay] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: meetings) {
            calendar.startOfDay(for: $0.startedAt)
        }
        return byDay.keys.sorted(by: >).map { day in
            MeetingDay(
                label: label(for: day, calendar: calendar),
                meetings: (byDay[day] ?? []).sorted { $0.startedAt > $1.startedAt }
            )
        }
    }

    private static func label(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return t("Hoje", "Today") }
        if calendar.isDateInYesterday(day) { return t("Ontem", "Yesterday") }
        return dayFormatter.string(from: day)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = t("d 'de' MMMM", "MMMM d")
        return formatter
    }()
}

struct UsageStats {
    let meetingsThisWeek: Int
    let hoursTranscribed: Double
    let wordsTranscribed: Int

    init(meetings: [Meeting]) {
        meetingsThisWeek = meetings.count
        hoursTranscribed = meetings.reduce(0) { $0 + $1.duration } / 3_600
        wordsTranscribed = meetings.reduce(0) { $0 + $1.wordCount }
    }
}
