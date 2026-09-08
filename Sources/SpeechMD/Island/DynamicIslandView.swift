import AppKit
import SwiftUI

struct DynamicIslandView: View {
    var isListening: Bool = true
    var elapsed: TimeInterval = 0
    var notchWidth: CGFloat = 0
    /// Texto de alerta; quando presente a ilha estica pra mostrá-lo.
    var warning: String?
    /// Segundos até o aviso sumir — a barra drena nesse tempo.
    var countdownDuration: TimeInterval = 3
    var result: String?
    var isProcessing = false
    var isClosing = false
    /// A borda de onde a ilha sai. Ela sempre encosta numa: o lado colado
    /// fica reto e o resto arredonda.
    var placement: IslandPlacement = .notch
    /// Na lateral ela fica em pé: a onda em cima, o cronômetro embaixo.
    var isVertical = false
    var onCopy: (() -> Void)?
    /// Clique sem arrasto: começa ou encerra o ditado.
    var onActivate: (() -> Void)?
    /// Cada quadro do arrasto. Quem move o painel é o controller, que lê a
    /// posição do mouse na tela — a translação do gesto zeraria a cada
    /// movimento porque a janela anda junto com o cursor.
    var onDragChange: (() -> Void)?
    var onDragEnd: ((Bool) -> Void)?

    static let earWidth: CGFloat = 46
    static let warningEarWidth: CGFloat = 150
    static let height: CGFloat = 34
    /// Em pé ela mantém a espessura da pill deitada (`height`) e cresce só no
    /// comprimento — fina e comprida, não um bloco.
    static let verticalWidth: CGFloat = height
    static let verticalHeight: CGFloat = 140
    private static let resultFontSize: CGFloat = 12.5
    private static let resultInset: CGFloat = 13

    static func resultWidth(notchWidth: CGFloat) -> CGFloat {
        max(288, notchWidth + earWidth * 2 + 24)
    }

    static func resultHeight(for text: String, notchWidth: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: resultFontSize)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(
                width: resultWidth(notchWidth: notchWidth) - resultInset * 2,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let line = ceil(font.boundingRectForFont.height)
        return resultInset * 2 + min(ceil(bounds.height), line * 4) + 10 + 26
    }

    /// Abaixo disso o movimento é tremida de clique, não arrasto.
    private static let dragSlop: CGFloat = 4

    @State private var isDraggingSelf = false
    @State private var isOpen = false
    @State private var drain: CGFloat = 1
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 0) {
            // Embaixo a bolha sai por cima da pill, senão ela cresceria pra
            // fora da tela.
            if placement == .bottom, let result {
                resultBubble(result)
            }
            pill
            if placement != .bottom, let result {
                resultBubble(result)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edgeAlignment)
    }

    /// A ilha é empurrada contra a borda de onde ela sai.
    private var edgeAlignment: Alignment {
        switch placement {
        case .notch: .top
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var pill: some View {
        pillContent
            .opacity(isShown ? 1 : 0)
            .background(.black, in: shape)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            // Parada ela é botão, então mãozinha; gravando ela é só algo que
            // dá pra arrastar.
            .pointerStyle(isDraggingSelf ? .grabActive : (isListening ? .grabIdle : .link))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard hypot(value.translation.width, value.translation.height)
                            > Self.dragSlop else { return }
                        isDraggingSelf = true
                        onDragChange?()
                    }
                    .onEnded { _ in
                        let moved = isDraggingSelf
                        isDraggingSelf = false
                        onDragEnd?(moved)
                        if !moved { onActivate?() }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.84), value: isClosing)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: placement)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isVertical)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    isOpen = true
                }
            }
    }

    @ViewBuilder
    private var pillContent: some View {
        if isVertical {
            // Onda numa ponta, microfone/cronômetro na outra: o meio fica
            // vazio de propósito.
            VStack(spacing: 0) {
                leftEar
                    .frame(height: 24)
                Spacer(minLength: 16)
                rightEar
            }
            .padding(.vertical, 18)
            // Sem isto o cronômetro encosta na parede da pill: 34pt de
            // espessura não sobra nada pra "0:07".
            .padding(.horizontal, 5)
            .frame(width: Self.verticalWidth, height: isShown ? Self.verticalHeight : 0)
        } else {
            HStack(spacing: 0) {
                leftEar
                    .frame(width: Self.earWidth, height: 16, alignment: .leading)

                // Deitada ela mantém a largura do topo em qualquer borda:
                // encolher embaixo fazia parecer outro componente.
                Color.clear
                    .frame(width: notchWidth)

                rightEar
                    .frame(width: rightEarWidth, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .frame(
                width: isShown ? nil : notchWidth,
                height: isShown ? Self.height : 0
            )
        }
    }

    /// Com aviso, o lugar da waveform vira o anel de contagem regressiva —
    /// o mesmo ponto da tela conta quanto falta pra ilha fechar.
    @ViewBuilder
    private var leftEar: some View {
        if isProcessing {
            CountdownRing(progress: 0.3, tint: .white, spinning: true)
                .frame(width: 14, height: 14)
        } else if warning != nil {
            CountdownRing(progress: drain)
                .frame(width: 15, height: 15)
                .onAppear {
                    drain = 1
                    withAnimation(.linear(duration: countdownDuration)) { drain = 0 }
                }
        } else {
            WaveformBars(isAnimating: isListening, barCount: 4, maxHeight: 14)
                .frame(height: 14)
        }
    }

    private var rightEarWidth: CGFloat {
        warning == nil ? Self.earWidth : Self.warningEarWidth
    }

    private func resultBubble(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: Self.resultFontSize))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard !didCopy else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { didCopy = true }
                onCopy?()
            } label: {
                HStack(spacing: 6) {
                    if didCopy {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        CountdownRing(progress: drain, tint: .black, track: .black.opacity(0.16))
                            .frame(width: 11, height: 11)
                            .onAppear {
                                drain = 1
                                withAnimation(.linear(duration: countdownDuration)) { drain = 0 }
                            }
                    }
                    Text(didCopy ? t("Copiado", "Copied") : t("Copiar", "Copy"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .scaleEffect(didCopy ? 0.94 : 1)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(Self.resultInset)
        .frame(width: Self.resultWidth(notchWidth: notchWidth), alignment: .topLeading)
        .background(.black, in: bubbleShape)
        .opacity(isShown ? 1 : 0)
        .scaleEffect(isShown ? 1 : 0.94, anchor: .top)
        .blur(radius: isShown ? 0 : 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: isClosing)
    }

    private var isShown: Bool { isOpen && !isClosing }

    @ViewBuilder
    private var rightEar: some View {
        if result != nil {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        } else if let warning {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                Text(warning)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else if !isListening {
            // Parada, ela é um botão: o microfone diz que dá pra clicar.
            Image(systemName: "mic.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        } else {
            Text(formattedElapsed)
                .font(.system(size: isVertical ? 10 : 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.28), value: elapsed)
        }
    }
    private var shape: some Shape {
        let radius: CGFloat = isVertical ? Self.verticalWidth / 2 : 18
        var corners = (top: radius, bottom: radius, leading: radius, trailing: radius)
        // O lado colado na borda da tela é reto.
        switch placement {
        case .notch: corners.top = 0
        case .bottom: corners.bottom = 0
        case .left: corners.leading = 0
        case .right: corners.trailing = 0
        }
        // E o lado por onde a bolha de resultado sai também.
        if result != nil {
            if placement == .bottom { corners.top = 0 } else { corners.bottom = 0 }
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: min(corners.top, corners.leading),
            bottomLeadingRadius: min(corners.bottom, corners.leading),
            bottomTrailingRadius: min(corners.bottom, corners.trailing),
            topTrailingRadius: min(corners.top, corners.trailing),
            style: .continuous
        )
    }

    private var bubbleShape: some Shape {
        // Embaixo a bolha fica acima da pill, então é ela que encosta na borda.
        let sitsAbove = placement == .bottom
        return UnevenRoundedRectangle(
            topLeadingRadius: sitsAbove ? 18 : 0,
            bottomLeadingRadius: sitsAbove ? 0 : 18,
            bottomTrailingRadius: sitsAbove ? 0 : 18,
            topTrailingRadius: sitsAbove ? 18 : 0,
            style: .continuous
        )
    }

    private var formattedElapsed: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Anel que esvazia — quanto resta até a ilha se fechar sozinha.
private struct CountdownRing: View {
    var progress: CGFloat
    var tint: Color = .yellow
    var track: Color = .white.opacity(0.18)
    var spinning = false

    @State private var turn = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90)) // começa no topo
                .rotationEffect(.degrees(turn ? 360 : 0))
                .animation(
                    spinning ? .linear(duration: 0.75).repeatForever(autoreverses: false) : nil,
                    value: turn
                )
        }
        .onAppear {
            guard spinning else { return }
            turn = true
        }
    }
}

/// Onda contínua: cada barra é uma senoide defasada, então o movimento
/// "viaja" em vez de piscar aleatoriamente. TimelineView anima por frame.
private struct WaveformBars: View {
    var isAnimating: Bool
    var barCount: Int
    var maxHeight: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(width: 2.5, height: barHeight(index: index, time: t))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isAnimating else { return maxHeight * 0.16 }
        let phase = Double(index) * 0.55
        let wave = sin(time * 5.2 - phase) * 0.5 + sin(time * 2.7 - phase * 0.7) * 0.32
        let normalized = (wave + 0.82) / 1.64
        return max(2.5, maxHeight * (0.18 + 0.82 * normalized))
    }
}

#Preview {
    DynamicIslandView(elapsed: 42, notchWidth: 180)
        .frame(width: 320, height: 60)
        .background(Color.gray.opacity(0.2))
}
