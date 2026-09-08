import AppKit
import SwiftUI

/// Menu nativo disparado por uma view SwiftUI.
///
/// `Menu` e `Picker` no macOS são controle AppKit por baixo: ignoram o
/// `.frame` e descartam o label desenhado, sobrando só o título. Então o botão
/// é sempre nosso e só a lista é do sistema — de lá vêm teclado, marca de
/// selecionado e a aparência de menu do macOS.
@MainActor
enum PopUpMenu {
    struct Item {
        let title: String
        let isOn: Bool
        let isEnabled: Bool
        let action: () -> Void

        init(_ title: String, isOn: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.title = title
            self.isOn = isOn
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    static func show(_ items: [Item], from anchor: NSView) {
        let target = MenuTarget { items[$0].action() }
        let menu = NSMenu()
        // Sem isto o AppKit pergunta pro target se cada item vale e, como
        // MenuTarget não responde, desenha tudo cinza e desabilitado.
        menu.autoenablesItems = false

        for (index, item) in items.enumerated() {
            let entry = NSMenuItem(
                title: item.title,
                action: #selector(MenuTarget.pick(_:)),
                keyEquivalent: ""
            )
            entry.target = target
            entry.tag = index
            entry.state = item.isOn ? .on : .off
            entry.isEnabled = item.isEnabled
            menu.addItem(entry)
        }

        // `popUp` trava a runloop até fechar, então quem chamou precisa de um
        // turno pra pintar o estado aberto antes.
        DispatchQueue.main.async {
            // `NSMenuItem.target` é weak: sem segurar o MenuTarget aqui ele
            // morre e a escolha não chega em ninguém.
            _ = withExtendedLifetime(target) {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: anchor)
            }
        }
    }
}

/// View invisível só pra dar um ponto de ancoragem AppKit ao menu. Não pega
/// clique nenhum: quem trata o toque é o SwiftUI por cima.
final class MenuAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct MenuAnchor: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
private final class MenuTarget: NSObject {
    private let handler: (Int) -> Void

    init(handler: @escaping (Int) -> Void) {
        self.handler = handler
    }

    @objc func pick(_ sender: NSMenuItem) {
        handler(sender.tag)
    }
}
