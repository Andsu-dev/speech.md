import AppKit
import SwiftUI

extension Notification.Name {
    static let speechMDNavigate = Notification.Name("SpeechMDNavigate")
    static let speechMDToggleDictation = Notification.Name("SpeechMDToggleDictation")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) weak var shared: AppDelegate?

    weak var mainWindow: NSWindow?
    private var statusBarController: StatusBarController?
    private var isTerminatingCompletely = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        statusBarController = StatusBarController(appDelegate: self)

        // Permite que o desligamento do sistema não seja bloqueado
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isTerminatingCompletely = true
            }
        }

        // Aguarda a janela ser instanciada pelo SwiftUI para capturá-la
        DispatchQueue.main.async { [weak self] in
            self?.findAndConfigureMainWindow()
            self?.updateActivationPolicy()
        }
    }

    func findAndConfigureMainWindow() {
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            self.mainWindow = window
            window.delegate = self
            window.isReleasedWhenClosed = false
        }
    }

    // Intercepta o fechamento da janela (botão vermelho "X" ou Cmd+W)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        updateActivationPolicy()
        return false
    }

    // Intercepta o "Encerrar" da Dock ou Cmd+Q para manter o app rodando se desejado
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isTerminatingCompletely {
            return .terminateNow
        }

        // Se o usuário fechar/encerrar pela Dock, apenas oculta a janela e retira da Dock,
        // mantendo o ditado, a ilha e a barra de menus funcionando em background.
        hideMainWindowAndDock()
        return .terminateCancel
    }

    // Ao clicar no app no Launchpad/Spotlight/Finder ou via terminal
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func showMainWindow() {
        if mainWindow == nil {
            findAndConfigureMainWindow()
        }

        let alwaysHide = UserDefaults.standard.bool(forKey: "alwaysHideFromDock")
        if !alwaysHide {
            NSApp.setActivationPolicy(.regular)
        }

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hideMainWindowAndDock() {
        mainWindow?.orderOut(nil)
        updateActivationPolicy()
    }

    func updateActivationPolicy() {
        let alwaysHide = UserDefaults.standard.bool(forKey: "alwaysHideFromDock")
        let hideWhenClosed = UserDefaults.standard.object(forKey: "hideFromDockWhenClosed") as? Bool ?? true

        let isWindowVisible = mainWindow?.isVisible ?? false

        if alwaysHide {
            NSApp.setActivationPolicy(.accessory)
        } else if !isWindowVisible && hideWhenClosed {
            // Janela fechada e opção de sair da Dock ativada -> remove da Dock
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Janela visível ou usuário quer manter na Dock
            NSApp.setActivationPolicy(.regular)
        }
    }

    func terminateCompletely() {
        isTerminatingCompletely = true
        NSApp.terminate(nil)
    }
}
