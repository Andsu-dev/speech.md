import AppKit
import SwiftUI

@MainActor
final class IslandController {
    var isVisible = false {
        didSet {
            guard isVisible != oldValue else { return }
            render()
        }
    }

    /// Some, ou volta pro estado parado se a ilha mora na tela. Quem chama de
    /// fora usa isto em vez de `isVisible = false`: era assim que ela sumia
    /// depois de cada ditado mesmo configurada pra ficar.
    func hide() {
        isVisible = staysVisible
    }

    var warning: String? {
        didSet {
            guard warning != oldValue else { return }
            render()
            scheduleWarningDismissal()
        }
    }

    var result: String? {
        didSet {
            guard result != oldValue else { return }
            if result != nil { stopTicker() }
            render()
            scheduleResultDismissal()
        }
    }

    var isProcessing = false {
        didSet {
            guard isProcessing != oldValue else { return }
            render()
        }
    }

    private var isClosing = false {
        didSet {
            guard isClosing != oldValue else { return }
            render()
        }
    }

    private var elapsed: TimeInterval = 0 {
        didSet { render() }
    }

    /// A vaga onde a ilha mora. Posição livre não existe: ou é o notch, ou é
    /// uma das laterais, ou é embaixo.
    private var placement: IslandPlacement = .notch {
        didSet {
            guard placement != oldValue else { return }
            UserDefaults.standard.set(placement.rawValue, forKey: Self.placementKey)
        }
    }

    /// Enquanto arrasta, o `render()` do tique do cronômetro não pode
    /// reposicionar o painel: puxaria a ilha de volta debaixo do cursor.
    private var isDragging = false
    /// Onde o mouse e o painel estavam quando o arrasto começou.
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?
    private var zonesPanel: NSPanel?

    private static let placementKey = "islandPlacement"

    /// O que o `render()` posicionou por último. Serve pra separar o que a
    /// gente moveu do que o usuário arrastou — sem isso o arrasto e o
    /// reposicionamento a cada tick ficariam se sobrescrevendo.

    private var panel: NSPanel?
    private var hostingView: NSHostingView<DynamicIslandView>?
    private var ticker: Timer?
    private var warningDismissal: Task<Void, Never>?
    private var resultDismissal: Task<Void, Never>?

    /// Quanto tempo um aviso fica na tela antes de sumir sozinho.
    private static let warningDuration: Duration = .seconds(3)
    private static let resultDuration: Duration = .seconds(15)

    init() {
        placement = UserDefaults.standard.string(forKey: Self.placementKey)
            .flatMap(IslandPlacement.init(rawValue:)) ?? .notch
    }


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
            // ninguém está gravando: a ilha volta a ficar parada, ou sai
            if !isSessionActive {
                isVisible = staysVisible
            }
        }
    }

    func showResult(_ text: String) {
        warning = nil
        isClosing = false
        result = text
        isVisible = true
    }

    private func scheduleResultDismissal() {
        resultDismissal?.cancel()
        guard result != nil else { return }

        resultDismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.resultDuration)
            guard !Task.isCancelled, let self else { return }
            dismissResult()
        }
    }

    private func dismissResult() {
        resultDismissal?.cancel()
        isClosing = true
        resultDismissal = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, let self else { return }
            result = nil
            isClosing = false
            if !isSessionActive {
                isVisible = staysVisible
            }
        }
    }

    /// Clique na ilha: quem liga isso é o shell, com a mesma ação do atalho.
    var onActivate: (() -> Void)?

    /// Com isto ligado a ilha nunca se esconde sozinha: acabada a gravação
    /// ela volta pro estado parado em vez de sumir.
    var staysVisible = false {
        didSet {
            guard staysVisible != oldValue else { return }
            if staysVisible { isVisible = true } else if !isSessionActive, result == nil {
                isVisible = false
            }
        }
    }

    /// Ligado por quem controla a sessão; enquanto true a ilha permanece.
    var isSessionActive = false {
        didSet {
            guard isSessionActive != oldValue else { return }
            // O cronômetro é da gravação, não da ilha: parada na tela ela não
            // pode contar, senão o ditado já começava com segundos rodados.
            isSessionActive ? startTicker() : stopTicker()
            render()
        }
    }

    private func startTicker() {
        elapsed = 0
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 1 }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        elapsed = 0
    }

    private func render(animated: Bool = false) {
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
            isListening: isSessionActive,
            elapsed: elapsed,
            notchWidth: notchWidth,
            warning: warning,
            countdownDuration: TimeInterval(
                (result == nil ? Self.warningDuration : Self.resultDuration).components.seconds
            ),
            result: result,
            isProcessing: isProcessing,
            isClosing: isClosing,
            placement: placement,
            isVertical: isVertical(at: placement),
            onCopy: { [weak self] in
                guard let self, let text = result else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                resultDismissal?.cancel()
                resultDismissal = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(420))
                    guard !Task.isCancelled else { return }
                    self?.dismissResult()
                }
            },
            onActivate: { [weak self] in self?.onActivate?() },
            onDragChange: { [weak self] in self?.dragChanged() },
            onDragEnd: { [weak self] moved in self?.dragEnded(moved: moved) }
        )

        let size = contentSize(for: placement)

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
        let screen = panel.screen ?? notchScreen
        let frame = NSRect(origin: origin(of: size, at: placement, on: screen), size: size)
        if !isDragging, panel.frame != frame {
            panel.setFrame(frame, display: true, animate: animated)
        }

        // Aceita mouse sempre: é o que permite arrastar. No lugar de casa ela
        // cobre o notch, onde não há nada pra clicar mesmo.
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
    }

    /// Em pé só enquanto ela é o indicador; com aviso ou resultado tem texto
    /// pra mostrar e ela volta a deitar, ainda encostada na mesma borda.
    private func isVertical(at placement: IslandPlacement) -> Bool {
        placement.isVertical && warning == nil && result == nil
    }

    /// O tamanho do painel em cada vaga. Sai daqui tanto o que a ilha ocupa
    /// quanto o alvo desenhado no arrasto, senão a vaga mentiria o formato.
    private func contentSize(for placement: IslandPlacement) -> NSSize {
        if isVertical(at: placement) {
            return NSSize(
                width: DynamicIslandView.verticalWidth + 24,
                height: DynamicIslandView.verticalHeight + 24
            )
        }
        // painel sempre no tamanho máximo (com aviso); a pill cresce dentro dele
        let notchWidth = notchWidth()
        let pillWidth = notchWidth + DynamicIslandView.earWidth
            + DynamicIslandView.warningEarWidth + 24
        let bubbleHeight = result.map {
            DynamicIslandView.resultHeight(for: $0, notchWidth: notchWidth)
        } ?? 0
        return NSSize(
            width: max(pillWidth, DynamicIslandView.resultWidth(notchWidth: notchWidth) + 24),
            height: DynamicIslandView.height + 24 + bubbleHeight
        )
    }

    /// Onde a ilha encosta em cada vaga. A visível (o alvo do arrasto) e a
    /// final saem daqui, então elas nunca discordam.
    private func origin(of size: NSSize, at placement: IslandPlacement, on screen: NSScreen)
        -> NSPoint {
        // Sempre encostada: a ilha sai da borda, não flutua perto dela.
        let area = screen.frame
        switch placement {
        case .notch:
            return NSPoint(x: area.midX - size.width / 2, y: area.maxY - size.height)
        case .left:
            return NSPoint(x: area.minX, y: area.midY - size.height / 2)
        case .right:
            return NSPoint(x: area.maxX - size.width, y: area.midY - size.height / 2)
        case .bottom:
            return NSPoint(x: area.midX - size.width / 2, y: area.minY)
        }
    }

    /// Cada quadro do arrasto. A posição vem do mouse na tela, não da
    /// translação do gesto: a janela anda junto com o cursor e a translação
    /// zeraria a cada quadro.
    private func dragChanged() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let start = dragStart ?? (mouse: mouse, origin: panel.frame.origin)
        dragStart = start
        isDragging = true

        panel.setFrameOrigin(NSPoint(
            x: start.origin.x + mouse.x - start.mouse.x,
            y: start.origin.y + mouse.y - start.mouse.y
        ))

        let screen = panel.screen ?? notchScreen
        showZones(on: screen, active: nearestPlacement(to: panel.frame, on: screen))
    }

    /// Soltou. Arrastou de verdade? Encaixa na vaga acesa. Foi clique? O
    /// gesto na view já chamou `onActivate`.
    private func dragEnded(moved: Bool) {
        defer {
            dragStart = nil
            isDragging = false
            hideZones()
        }
        guard moved, let panel else { return }
        let screen = panel.screen ?? notchScreen
        placement = nearestPlacement(to: panel.frame, on: screen)
        isDragging = false
        render(animated: true)
    }

    private func nearestPlacement(to frame: NSRect, on screen: NSScreen) -> IslandPlacement {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return IslandPlacement.allCases.min { first, second in
            distance(from: center, toZoneOf: first, on: screen)
                < distance(from: center, toZoneOf: second, on: screen)
        } ?? .notch
    }

    private func distance(
        from point: NSPoint,
        toZoneOf placement: IslandPlacement,
        on screen: NSScreen
    ) -> CGFloat {
        let size = contentSize(for: placement)
        let origin = origin(of: size, at: placement, on: screen)
        return hypot(point.x - (origin.x + size.width / 2), point.y - (origin.y + size.height / 2))
    }

    private func showZones(on screen: NSScreen, active: IslandPlacement) {
        let panel = zonesPanel ?? makeZonesPanel(on: screen)
        zonesPanel = panel

        // O overlay cobre a tela inteira; o SwiftUI conta y de cima pra baixo
        // e a tela de baixo pra cima, daí a virada.
        var zones: [IslandPlacement: CGRect] = [:]
        for candidate in IslandPlacement.allCases {
            let size = contentSize(for: candidate)
            let origin = origin(of: size, at: candidate, on: screen)
            zones[candidate] = CGRect(
                x: origin.x - screen.frame.minX - 8,
                y: screen.frame.maxY - origin.y - size.height - 8,
                width: size.width + 16,
                height: size.height + 16
            )
        }

        let view = IslandDropZonesView(zones: zones, active: active)
        if let hosting = panel.contentView as? NSHostingView<IslandDropZonesView> {
            hosting.rootView = view
        } else {
            panel.contentView = NSHostingView(rootView: view)
        }
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        // A ilha continua por cima do overlay enquanto é arrastada.
        self.panel?.orderFrontRegardless()
    }

    private func hideZones() {
        zonesPanel?.orderOut(nil)
        zonesPanel?.contentView = nil
    }

    private func makeZonesPanel(on screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
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
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        return panel
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
        // O arrasto é do gesto no SwiftUI, não do AppKit: é o que deixa
        // separar um clique de um arrasto na mesma superfície.
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        return panel
    }
}
