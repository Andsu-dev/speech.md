import AVFoundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Permissões do sistema que o app precisa, com status e atalho para o painel.
enum SystemPermission: String, CaseIterable, Identifiable {
    case microphone
    case screenRecording
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone: "Microfone"
        case .screenRecording: "Gravação de tela"
        case .accessibility: "Acessibilidade"
        }
    }

    var reason: String {
        switch self {
        case .microphone: "Transcrever a sua voz."
        case .screenRecording: "Capturar o áudio dos outros participantes da reunião."
        case .accessibility: "Colar o texto ditado no app em foco."
        }
    }

    var isGranted: Bool {
        switch self {
        case .microphone:
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .screenRecording:
            CGPreflightScreenCaptureAccess()
        case .accessibility:
            AXIsProcessTrusted()
        }
    }

    /// O prompt do sistema só aparece uma vez por app; depois disso, a única
    /// rota é o painel de Ajustes — por isso todo botão leva pra lá.
    func openSettings() {
        let anchor = switch self {
        case .microphone: "Privacy_Microphone"
        case .screenRecording: "Privacy_ScreenCapture"
        case .accessibility: "Privacy_Accessibility"
        }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Vale tentar antes de mandar o usuário pros Ajustes: se o app nunca pediu,
    /// isto resolve num clique.
    func requestIfPossible() {
        switch self {
        case .microphone:
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
                openSettings()
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        case .screenRecording:
            CGRequestScreenCaptureAccess()
        case .accessibility:
            let promptKey = "AXTrustedCheckOptionPrompt"
            _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
    }
}
