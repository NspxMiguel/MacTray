import Foundation
import Combine

/// Idiomas suportados. `system` segue a preferencia do macOS.
enum Language: String, CaseIterable, Identifiable {
    case system
    case pt
    case en

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .system: return "" // preenchido pela traducao corrente
        case .pt: return "Português"
        case .en: return "English"
        }
    }
}

/// Tabela de traducoes. Sem .strings/.lproj de proposito: o app roda tambem como
/// binario solto (fora do bundle) durante o desenvolvimento, e Bundle.main falharia la.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published private(set) var language: Language {
        didSet { Defaults.language = language }
    }

    private init() {
        // Ordem: variavel de ambiente > escolha salva > idioma do sistema.
        if let forced = ProcessInfo.processInfo.environment["MACTRAY_LANG"],
           let lang = Language(rawValue: forced.lowercased()), lang != .system {
            language = lang
        } else {
            language = Defaults.language
        }
    }

    func set(_ lang: Language) {
        language = lang
    }

    /// Idioma efetivo: resolve `.system` olhando as preferencias do macOS.
    var resolved: Language {
        guard language == .system else { return language }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("pt") ? .pt : .en
    }

    func callAsFunction(_ key: String) -> String { string(key) }

    func string(_ key: String) -> String {
        let table = resolved == .pt ? L10n.pt : L10n.en
        return table[key] ?? L10n.en[key] ?? key
    }

    func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), arguments: args)
    }

    private static let pt: [String: String] = [
        "app.name": "MacTray",
        "menu.preferences": "Preferências…",
        "menu.about": "Sobre o MacTray",
        "menu.showAll": "Mostrar tudo (inclusive a área sempre oculta)",
        "menu.quit": "Sair do MacTray",
        "menu.hint": "Clique para mostrar/ocultar · ⌥ clique para mostrar tudo · clique direito para o menu",
        "tip.title": "Como usar",
        "tip.body": "Segure ⌘ e arraste os ícones da barra de menus: o que ficar à esquerda da seta fica escondido, o que ficar à direita continua sempre visível.",
        "tip.gotIt": "Entendi",
        "prefs.title": "Preferências do MacTray",
        "prefs.tab.general": "Geral",
        "prefs.tab.appearance": "Aparência",
        "prefs.tab.about": "Sobre",
        "prefs.launchAtLogin": "Abrir quando eu ligar o Mac",
        "prefs.autoHide": "Esconder de novo sozinho depois de",
        "prefs.seconds": "segundos",
        "prefs.hideOnOutsideClick": "Esconder ao clicar em qualquer outro lugar",
        "prefs.alwaysHidden": "Criar uma área sempre oculta",
        "prefs.alwaysHidden.help": "Um segundo separador aparece na barra. O que ficar à esquerda dele só aparece com ⌥ clique.",
        "prefs.showSeparator": "Mostrar a linha do separador quando estiver aberto",
        "prefs.icon": "Ícone da seta",
        "prefs.icon.chevron": "Seta (‹)",
        "prefs.icon.chevronDouble": "Seta dupla (‹‹)",
        "prefs.icon.triangle": "Triângulo",
        "prefs.icon.dot": "Ponto",
        "prefs.hotkey": "Atalho de teclado",
        "prefs.hotkey.record": "Gravar atalho",
        "prefs.hotkey.recording": "Digite o atalho…",
        "prefs.hotkey.clear": "Limpar",
        "prefs.hotkey.none": "nenhum",
        "prefs.language": "Idioma",
        "prefs.language.system": "Automático (sistema)",
        "prefs.quit": "Sair do MacTray",
        "about.tagline": "A bandeja do Windows, na barra de menus do Mac.",
        "about.version": "Versão %@",
        "about.site": "Abrir nspx.dev",
    ]

    private static let en: [String: String] = [
        "app.name": "MacTray",
        "menu.preferences": "Preferences…",
        "menu.about": "About MacTray",
        "menu.showAll": "Show everything (including the always-hidden area)",
        "menu.quit": "Quit MacTray",
        "menu.hint": "Click to show/hide · ⌥ click to show everything · right click for the menu",
        "tip.title": "How to use it",
        "tip.body": "Hold ⌘ and drag the menu bar icons around: whatever sits to the left of the arrow gets hidden, whatever sits to the right stays visible.",
        "tip.gotIt": "Got it",
        "prefs.title": "MacTray Preferences",
        "prefs.tab.general": "General",
        "prefs.tab.appearance": "Appearance",
        "prefs.tab.about": "About",
        "prefs.launchAtLogin": "Open when I turn on my Mac",
        "prefs.autoHide": "Hide again by itself after",
        "prefs.seconds": "seconds",
        "prefs.hideOnOutsideClick": "Hide when I click anywhere else",
        "prefs.alwaysHidden": "Create an always-hidden area",
        "prefs.alwaysHidden.help": "A second separator shows up in the bar. Whatever sits to its left only appears on ⌥ click.",
        "prefs.showSeparator": "Show the separator line while expanded",
        "prefs.icon": "Arrow icon",
        "prefs.icon.chevron": "Chevron (‹)",
        "prefs.icon.chevronDouble": "Double chevron (‹‹)",
        "prefs.icon.triangle": "Triangle",
        "prefs.icon.dot": "Dot",
        "prefs.hotkey": "Keyboard shortcut",
        "prefs.hotkey.record": "Record shortcut",
        "prefs.hotkey.recording": "Type the shortcut…",
        "prefs.hotkey.clear": "Clear",
        "prefs.hotkey.none": "none",
        "prefs.language": "Language",
        "prefs.language.system": "Automatic (system)",
        "prefs.quit": "Quit MacTray",
        "about.tagline": "The Windows tray, on the Mac menu bar.",
        "about.version": "Version %@",
        "about.site": "Open nspx.dev",
    ]
}
