import Foundation

/// Decide, a partir do jeito que a tecla foi usada, se o ditado segue enquanto
/// ela estiver pressionada ou se fica travado até o próximo toque.
///
/// Uma tecla só, dois gestos: segurar grava e solta entrega; dois toques rápidos
/// travam a gravação, e o toque seguinte encerra. Gravar começa sempre no
/// press — decidir depois é o que permite não perder o começo da fala.
@MainActor
final class DictationGesture {
    /// Abaixo disso o toque conta como "tap", acima disso como "segurar".
    static let tapWindow: TimeInterval = 0.35

    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    private enum State {
        case idle
        /// Gravando com a tecla pressionada; ainda não se sabe o gesto.
        case holding(since: Date)
        /// Tecla solta rápido: gravando à espera do segundo toque.
        case awaitingSecondTap(Task<Void, Never>)
        /// Dois toques: grava até o próximo toque.
        case locked
    }

    private var state: State = .idle

    func keyDown() {
        switch state {
        case .idle:
            state = .holding(since: Date())
            onStart?()
        case .awaitingSecondTap(let timeout):
            timeout.cancel()
            state = .locked
        case .locked:
            state = .idle
            onFinish?()
        case .holding:
            break
        }
    }

    func keyUp() {
        guard case .holding(let since) = state else { return }

        guard Date().timeIntervalSince(since) < Self.tapWindow else {
            state = .idle
            onFinish?()
            return
        }

        state = .awaitingSecondTap(Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.tapWindow))
            guard !Task.isCancelled, let self else { return }
            state = .idle
            onFinish?()
        })
    }

    /// Para quando a gravação termina por fora do teclado, como o botão Falar.
    func reset() {
        if case .awaitingSecondTap(let timeout) = state { timeout.cancel() }
        state = .idle
    }

    var isRecording: Bool {
        if case .idle = state { return false }
        return true
    }
}
