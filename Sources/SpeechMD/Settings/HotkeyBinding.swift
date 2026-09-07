import AppKit
import Carbon.HIToolbox

/// Combinação de teclas persistível. `keyCode` é o virtual key code do macOS.
struct HotkeyBinding: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt
    /// Opcional para não invalidar os atalhos já salvos em UserDefaults.
    var doubleTap: Bool?

    /// ⌥⌘R. Space com ⌘ é da busca do sistema e nunca chegaria ao app.
    static let `default` = HotkeyBinding(keyCode: 15, modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue)

    static let fnKeyCode: UInt32 = 63

    static let fn = HotkeyBinding(keyCode: fnKeyCode, modifiers: 0)

    /// Dois toques em fn, como o ditado do próprio macOS.
    static let fnDouble = HotkeyBinding(keyCode: fnKeyCode, modifiers: 0, doubleTap: true)

    var isFunctionKey: Bool { keyCode == Self.fnKeyCode }

    var isDoubleTap: Bool { doubleTap == true }

    /// Janela entre os dois toques, no gravador e no atalho global.
    static let doubleTapWindow: TimeInterval = 0.4

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    /// "⌥⌘Space" — ordem igual à dos menus do sistema.
    var displayString: String {
        if isFunctionKey { return isDoubleTap ? "fn fn" : "fn" }
        var result = ""
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }
        return result + Self.keyName(for: keyCode)
    }

    var isValid: Bool {
        if isFunctionKey { return true }
        return !modifierFlags.intersection([.control, .option, .shift, .command]).isEmpty
    }

    private static func keyName(for keyCode: UInt32) -> String {
        if let named = namedKeys[keyCode] { return named }
        // teclas com caractere: pergunta ao layout de teclado atual
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(-1)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }

        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }

    private static let namedKeys: [UInt32: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
}
