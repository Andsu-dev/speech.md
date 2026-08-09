import AppKit
import SwiftUI

@MainActor
final class IslandController {
    var isVisible = false {
        didSet {
            guard isVisible != oldValue else { return }
            if isVisible { startTicker() } else { stopTicker() }
            render()
        }
    }

    var warning: String? {
        didSet {
            guard warning != oldValue else { return }
            render()
            scheduleWarningDismissal()
        }
    }

    private var elapsed: TimeInterval = 0 {
        didSet { render() }
    }

    private var panel: NSPanel?
    private var hostingView: NSHostingView<DynamicIslandView>?
    private var ticker: Timer?
    private var warningDismissal: Task<Void, Never>?

    /// Quanto tempo um aviso fica na tela antes de sumir sozinho.
    private static let warningDuration: Duration = .seconds(3)


    /// Mostra um aviso que se apaga sozinho — usado quando não há nem sessão
    /// em andamento pra depois esconder a ilha.
    func flashWarning(_ text: String) {
        warning = text
        isVisible = true
    }

    /// Sem isto o aviso ficaria na tela pra sempre: nada mais o removia quando
    /// o ditado nem chegava a começar.
    private func scheduleWarningDismissal() {
        warningDismissal?.cancel()
        guard warning != nil else { return }

        warningDismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.warningDuration)
            guard !Task.isCancelled, let self else { return }
            warning = nil
            // ninguém está gravando: a ilha inteira sai junto
            if !isSessionActive {
                isVisible = false
            }
        }
    }

    /// Ligado por quem controla a sessão; enquanto true a ilha permanece.
    var isSessionActive = false

    private func startTicker() {
        elapsed = 0
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 1 }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func render() {
        guard isVisible else {
            panel?.orderOut(nil)
            // descarta a hosting view pra que o onAppear (animação de abertura)
            // dispare de novo na próxima vez que a ilha aparecer
            hostingView = nil
            return
        }

        let panel = self.panel ?? makePanel()
        self.panel = panel

        let notchWidth = notchWidth()
        let view = DynamicIslandView(
            elapsed: elapsed,
            notchWidth: notchWidth,
            warning: warning,
            warningDuration: TimeInterval(Self.warningDuration.components.seconds)
        )

        // painel sempre no tamanho máximo (com aviso); a pill cresce dentro dele
        let size = NSSize(
            width: notchWidth + DynamicIslandView.earWidth
                + DynamicIslandView.warningEarWidth + 24,
            height: DynamicIslandView.height + 24
        )

        if let existing = hostingView {
            // só troca o conteúdo. Reatribuir contentView e mexer no frame a
            // cada tick brigava com as constraints que o NSHostingView instala
            // — era isso que estourava exceção no updateConstraints.
            existing.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = .clear
            hostingView = hosting
            panel.setContentSize(size)
            panel.contentView = hosting
        }

        // Reposiciona SEMPRE. Condicionar à mudança de tamanho deixava a ilha
        // presa na coordenada de uma tela anterior quando o display mudava.
        let screen = notchScreen
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        let frame = NSRect(origin: origin, size: size)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }

        panel.orderFrontRegardless()
    }

    /// A tela do notch, não `NSScreen.main`: main é a que tem foco de teclado e
    /// muda de monitor, o que jogava a ilha pra fora do notch.
    private var notchScreen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Largura do notch físico; 0 em Mac sem notch.
    private func notchWidth() -> CGFloat {
        let screen = notchScreen
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return 0
        }
        return max(0, right.minX - left.maxX)
    }
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        return panel
    }
}
