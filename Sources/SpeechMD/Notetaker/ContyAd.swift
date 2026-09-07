import AppKit
import SwiftUI

/// Anúncio da Conty no rodapé da barra lateral.
struct ContyAd: View {
    @State private var isHovering = false

    var body: some View {
        Link(destination: Links.conty) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    logo
                        .frame(height: 16)

                    Spacer(minLength: 0)

                    HStack(spacing: 3) {
                        Text(t("Anúncio", "Ad"))
                        Image(systemName: "arrow.up.right")
                            .imageScale(.small)
                            .offset(x: isHovering ? 1 : 0, y: isHovering ? -1 : 0)
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                }

                Text(t(
                    "Escale e cresça as vendas do seu app com criadores de conteúdo.",
                    "Scale and grow your app's sales with content creators."
                ))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovering ? Theme.surfaceHover : Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    /// O SVG da marca vai no bundle: 6 KB de path embutidos no fonte seria pior
    /// de ler e de trocar quando a marca mudar.
    private var logo: some View {
        Group {
            if let url = Bundle.main.url(forResource: "conty-logo", withExtension: "svg"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("conty")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}
