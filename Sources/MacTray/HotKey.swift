import AppKit
import Carbon.HIToolbox

/// Atalho global via Carbon. Escolhido de proposito no lugar de um monitor global de
/// teclado do NSEvent: aquele exige permissao de Acessibilidade, este nao exige nada.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature = OSType(0x4d545259) // 'MTRY'

    private init() {}

    func reload() {
        unregister()
        let code = Defaults.hotKeyCode
        let mods = Defaults.hotKeyModifiers
        guard code >= 0, mods != 0 else { return }
        register(keyCode: UInt32(code), carbonModifiers: UInt32(mods))
    }

    private func register(keyCode: UInt32, carbonModifiers: UInt32) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        if eventHandler == nil {
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                DispatchQueue.main.async { HotKeyManager.shared.onTrigger?() }
                return noErr
            }, 1, &eventType, nil, &eventHandler)
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Conversao NSEvent <-> Carbon

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    /// Texto do atalho no formato que o usuario ve: ⌥⌘T.
    static func describe(keyCode: Int, carbonModifiers: Int) -> String? {
        guard keyCode >= 0, carbonModifiers != 0 else { return nil }
        var text = ""
        if carbonModifiers & controlKey != 0 { text += "⌃" }
        if carbonModifiers & optionKey != 0 { text += "⌥" }
        if carbonModifiers & shiftKey != 0 { text += "⇧" }
        if carbonModifiers & cmdKey != 0 { text += "⌘" }
        text += keyName(for: keyCode)
        return text
    }

    static func keyName(for keyCode: Int) -> String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
            kVK_Delete: "⌫", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[keyCode] { return name }
        return characterForKeyCode(keyCode)?.uppercased() ?? "?"
    }

    /// Le o layout de teclado atual — num teclado ABNT ou AZERTY o mesmo codigo
    /// de tecla da outra letra.
    private static func characterForKeyCode(_ keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }
            var deadKeyState: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeyState, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
