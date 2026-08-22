import Foundation

/// Icone usado no botao da seta.
enum TrayIcon: String, CaseIterable, Identifiable {
    case chevron
    case chevronDouble
    case triangle
    case dot

    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .chevron: return "prefs.icon.chevron"
        case .chevronDouble: return "prefs.icon.chevronDouble"
        case .triangle: return "prefs.icon.triangle"
        case .dot: return "prefs.icon.dot"
        }
    }

    /// (fechado, aberto) — nomes de SF Symbols.
    var symbols: (collapsed: String, expanded: String) {
        switch self {
        case .chevron: return ("chevron.left", "chevron.right")
        case .chevronDouble: return ("chevron.left.2", "chevron.right.2")
        case .triangle: return ("arrowtriangle.left.fill", "arrowtriangle.right.fill")
        case .dot: return ("circle.fill", "circle")
        }
    }
}

/// Acesso tipado ao UserDefaults. Um lugar so para nao espalhar string de chave.
enum Defaults {
    private static let d = UserDefaults.standard

    static func registerDefaults() {
        d.register(defaults: [
            Key.autoHideEnabled: false,
            Key.autoHideDelay: 10.0,
            Key.hideOnOutsideClick: false,
            Key.alwaysHiddenEnabled: false,
            Key.showSeparator: true,
            Key.icon: TrayIcon.chevron.rawValue,
            Key.language: Language.system.rawValue,
            Key.hotKeyCode: -1,
            Key.hotKeyModifiers: 0,
            Key.didShowOnboarding: false,
        ])
    }

    enum Key {
        static let autoHideEnabled = "autoHideEnabled"
        static let autoHideDelay = "autoHideDelay"
        static let hideOnOutsideClick = "hideOnOutsideClick"
        static let alwaysHiddenEnabled = "alwaysHiddenEnabled"
        static let showSeparator = "showSeparator"
        static let icon = "icon"
        static let language = "language"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let didShowOnboarding = "didShowOnboarding"
    }

    static var autoHideEnabled: Bool {
        get { d.bool(forKey: Key.autoHideEnabled) }
        set { d.set(newValue, forKey: Key.autoHideEnabled) }
    }

    static var autoHideDelay: Double {
        get { max(1, d.double(forKey: Key.autoHideDelay)) }
        set { d.set(newValue, forKey: Key.autoHideDelay) }
    }

    static var hideOnOutsideClick: Bool {
        get { d.bool(forKey: Key.hideOnOutsideClick) }
        set { d.set(newValue, forKey: Key.hideOnOutsideClick) }
    }

    static var alwaysHiddenEnabled: Bool {
        get { d.bool(forKey: Key.alwaysHiddenEnabled) }
        set { d.set(newValue, forKey: Key.alwaysHiddenEnabled) }
    }

    static var showSeparator: Bool {
        get { d.bool(forKey: Key.showSeparator) }
        set { d.set(newValue, forKey: Key.showSeparator) }
    }

    static var icon: TrayIcon {
        get { TrayIcon(rawValue: d.string(forKey: Key.icon) ?? "") ?? .chevron }
        set { d.set(newValue.rawValue, forKey: Key.icon) }
    }

    static var language: Language {
        get { Language(rawValue: d.string(forKey: Key.language) ?? "") ?? .system }
        set { d.set(newValue.rawValue, forKey: Key.language) }
    }

    static var hotKeyCode: Int {
        get { d.integer(forKey: Key.hotKeyCode) }
        set { d.set(newValue, forKey: Key.hotKeyCode) }
    }

    static var hotKeyModifiers: Int {
        get { d.integer(forKey: Key.hotKeyModifiers) }
        set { d.set(newValue, forKey: Key.hotKeyModifiers) }
    }

    static var didShowOnboarding: Bool {
        get { d.bool(forKey: Key.didShowOnboarding) }
        set { d.set(newValue, forKey: Key.didShowOnboarding) }
    }
}
