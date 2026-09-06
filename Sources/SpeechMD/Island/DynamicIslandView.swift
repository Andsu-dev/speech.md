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
    var onCopy: (() -> Void)?

    static let earWidth: CGFloat = 46
    static let warningEarWidth: CGFloat = 150
    static let height: CGFloat = 34
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

    @State private var isOpen = false
    @State private var drain: CGFloat = 1
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 0) {
            pill
            if let result {
                resultBubble(result)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var pill: some View {
        HStack(spacing: 0) {
            leftEar
                .frame(width: Self.earWidth, height: 16, alignment: .leading)

            Color.clear
                .frame(width: notchWidth)

            rightEar
                .frame(width: rightEarWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .opacity(isShown ? 1 : 0)
        .frame(width: isShown ? nil : notchWidth, height: isShown ? Self.height : 0)
        .background(.black, in: shape)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: isClosing)
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
        if isProcessing {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.white)
                .scaleEffect(0.62)
                .frame(width: 15, height: 15)
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
                    Text(didCopy ? "Copiado" : "Copiar")
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
            bottomLeadingRadius: result == nil ? 18 : 0,
            bottomTrailingRadius: result == nil ? 18 : 0,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var bubbleShape: some Shape {
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
    var tint: Color = .yellow
    var track: Color = .white.opacity(0.18)

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
