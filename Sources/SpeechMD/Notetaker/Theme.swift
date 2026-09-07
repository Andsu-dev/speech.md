import AppKit
import SwiftUI

/// Tokens visuais do notetaker. Trocar a paleta inteira acontece aqui.
enum Theme {
    static let sidebarBackground = color(light: (0.96, 0.95, 0.94), dark: (0.11, 0.11, 0.10))
    static let canvas = color(light: (0.99, 0.99, 0.98), dark: (0.075, 0.075, 0.07))
    static let surface = color(light: (1, 1, 1), dark: (0.145, 0.145, 0.14))
    static let surfaceHover = color(light: (0.97, 0.96, 0.95), dark: (0.19, 0.19, 0.18))

    static let textPrimary = color(light: (0.11, 0.10, 0.09), dark: (0.96, 0.95, 0.94))
    static let textSecondary = color(light: (0.42, 0.40, 0.38), dark: (0.68, 0.67, 0.65))
    static let textTertiary = color(light: (0.62, 0.60, 0.58), dark: (0.50, 0.49, 0.47))

    static let border = color(light: (0.89, 0.88, 0.86), dark: (0.25, 0.25, 0.24))
    static let accent = color(light: (0.45, 0.28, 0.83), dark: (0.64, 0.50, 0.96))
    static let highlight = color(light: (0.98, 0.72, 0.28), dark: (0.98, 0.76, 0.36))
    static let live = color(light: (0.90, 0.26, 0.24), dark: (0.95, 0.38, 0.35))

    /// Fundo dos cards pretos, com `.white` por cima nos dois temas.
    static let contrastSurface = color(light: (0.11, 0.10, 0.09), dark: (0.17, 0.17, 0.16))

    static let cornerRadius: CGFloat = 12
    static let cardRadius: CGFloat = 16

    private static func color(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let tone = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: tone.0, green: tone.1, blue: tone.2, alpha: 1)
        })
    }
}
