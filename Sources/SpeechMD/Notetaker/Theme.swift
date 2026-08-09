import SwiftUI

/// Tokens visuais do notetaker. Trocar a paleta inteira acontece aqui.
enum Theme {
    static let sidebarBackground = Color(red: 0.96, green: 0.95, blue: 0.94)
    static let canvas = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let surface = Color.white
    static let surfaceHover = Color(red: 0.97, green: 0.96, blue: 0.95)

    static let textPrimary = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let textSecondary = Color(red: 0.42, green: 0.40, blue: 0.38)
    static let textTertiary = Color(red: 0.62, green: 0.60, blue: 0.58)

    static let border = Color(red: 0.89, green: 0.88, blue: 0.86)
    static let accent = Color(red: 0.45, green: 0.28, blue: 0.83)
    static let highlight = Color(red: 0.98, green: 0.72, blue: 0.28)
    static let live = Color(red: 0.90, green: 0.26, blue: 0.24)

    static let cornerRadius: CGFloat = 12
    static let cardRadius: CGFloat = 16
}
