import SwiftUI

/// Os lugares onde a ilha pode parar. Não existe posição livre: soltar em
/// qualquer ponto deixava ela no meio do caminho, atravessando conteúdo.
enum IslandPlacement: String, CaseIterable, Sendable {
    case notch
    case left
    case right
    case bottom

    /// Só no notch ela encosta na borda de cima e mantém o formato colado.
    var isDetached: Bool { self != .notch }

    /// Na lateral a ilha fica em pé — deitada ela comeria meia tela.
    var isVertical: Bool { self == .left || self == .right }
}

/// Overlay que aparece enquanto a ilha está sendo arrastada: desenha as vagas
/// e acende a que vai receber. Sem isso o arrasto é adivinhação.
struct IslandDropZonesView: View {
    /// Retângulos já em coordenada da tela, com origem no topo à esquerda.
    let zones: [IslandPlacement: CGRect]
    let active: IslandPlacement?

    @State private var isShown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(IslandPlacement.allCases, id: \.self) { placement in
                if let rect = zones[placement] {
                    zone(placement, rect: rect)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(isShown ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: isShown)
        .onAppear { isShown = true }
    }

    private func zone(_ placement: IslandPlacement, rect: CGRect) -> some View {
        let isActive = active == placement
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(isActive ? 0.16 : 0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        .white.opacity(isActive ? 0.85 : 0.3),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            dash: isActive ? [] : [7, 6]
                        )
                    )
            }
            .frame(width: rect.width, height: rect.height)
            .scaleEffect(isActive ? 1.05 : 1)
            .shadow(color: .black.opacity(isActive ? 0.3 : 0), radius: 12, y: 4)
            .offset(x: rect.minX, y: rect.minY)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isActive)
    }
}
