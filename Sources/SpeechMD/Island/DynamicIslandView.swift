import SwiftUI

struct DynamicIslandView: View {
    var isListening: Bool = true
    var elapsed: TimeInterval = 0
    var notchWidth: CGFloat = 0
    /// Texto de alerta; quando presente a ilha estica pra mostrá-lo.
    var warning: String?
    /// Segundos até o aviso sumir — a barra drena nesse tempo.
    var warningDuration: TimeInterval = 3

    static let earWidth: CGFloat = 46
    static let warningEarWidth: CGFloat = 150
    static let height: CGFloat = 34

    @State private var isOpen = false
    @State private var drain: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            leftEar
                .frame(width: Self.earWidth, height: 16, alignment: .leading)

            Color.clear
                .frame(width: notchWidth)

            rightEar
                .frame(width: rightEarWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .opacity(isOpen ? 1 : 0)
        .frame(width: isOpen ? nil : notchWidth, height: isOpen ? Self.height : 0)
        .background(.black, in: shape)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                isOpen = true
            }
        }
    }

    /// Com aviso, o lugar da waveform vira o anel de contagem regressiva —
    /// o mesmo ponto da tela conta quanto falta pra ilha fechar.
    @ViewBuilder
    private var leftEar: some View {
        if warning != nil {
            CountdownRing(progress: drain)
                .frame(width: 15, height: 15)
                .onAppear {
                    drain = 1
                    withAnimation(.linear(duration: warningDuration)) { drain = 0 }
                }
        } else {
            WaveformBars(isAnimating: isListening, barCount: 4, maxHeight: 14)
                .frame(height: 14)
        }
    }

    private var rightEarWidth: CGFloat {
        warning == nil ? Self.earWidth : Self.warningEarWidth
    }

    @ViewBuilder
    private var rightEar: some View {
        if let warning {
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
        } else {
            Text(formattedElapsed)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.28), value: elapsed)
        }
    }
    private var shape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 0,
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(.yellow, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90)) // começa no topo
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
