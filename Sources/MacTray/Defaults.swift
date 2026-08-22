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

    /// (fechado, aberto) — nomes de SF Symbols. Apontam para baixo porque é para baixo
    /// que a bandeja abre; para cima quando ela já está aberta.
    var symbols: (collapsed: String, expanded: String) {
        switch self {
        case .chevron: return ("chevron.down", "chevron.up")
        case .chevronDouble: return ("chevron.down.2", "chevron.up.2")
        case .triangle: return ("arrowtriangle.down.fill", "arrowtriangle.up.fill")
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
            Key.clickOpensPanel: true,
            Key.animateToggle: true,
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
        static let clickOpensPanel = "clickOpensPanel"
        static let animateToggle = "animateToggle"
        static let boundaryPosition = "boundaryPosition"
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

    static var clickOpensPanel: Bool {
        get { d.bool(forKey: Key.clickOpensPanel) }
        set { d.set(newValue, forKey: Key.clickOpensPanel) }
    }

    static var animateToggle: Bool {
        get { d.bool(forKey: Key.animateToggle) }
        set { d.set(newValue, forKey: Key.animateToggle) }
    }

    /// Onde o separador deve nascer, em pontos a partir da borda direita da barra.
    /// Guardado por fora porque o macOS apaga a chave dele quando o app fecha: sem isto,
    /// toda reinicialização devolvia a fronteira para a ponta direita.
    static var boundaryPosition: Double? {
        get {
            guard d.object(forKey: Key.boundaryPosition) != nil else { return nil }
            return d.double(forKey: Key.boundaryPosition)
        }
        set {
            if let newValue { d.set(newValue, forKey: Key.boundaryPosition) }
            else { d.removeObject(forKey: Key.boundaryPosition) }
        }
    }

    static var didShowOnboarding: Bool {
        get { d.bool(forKey: Key.didShowOnboarding) }
        set { d.set(newValue, forKey: Key.didShowOnboarding) }
    }
}
