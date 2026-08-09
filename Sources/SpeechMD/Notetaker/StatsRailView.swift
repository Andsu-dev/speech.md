import SwiftUI

struct StatsRailView: View {
    let stats: UsageStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatLine(value: "\(stats.meetingsThisWeek)", label: "reuniões na semana")
            StatLine(value: String(format: "%.1f", stats.hoursTranscribed), label: "horas transcritas")
            StatLine(value: stats.wordsTranscribed.formatted(.number.grouping(.automatic)), label: "palavras")
        }
        .padding(22)
        .frame(width: 292, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }
}

private struct StatLine: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(.system(size: 27, weight: .regular, design: .serif))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
