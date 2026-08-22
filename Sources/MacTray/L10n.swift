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
        "auth.title": "A bandeja precisa de uma autorização",
        "auth.body": "Para mostrar os ícones escondidos numa caixinha e abrir o menu deles, o MacTray precisa da permissão de Acessibilidade — é assim que o macOS deixa um app enxergar a barra de menus dos outros. Sem ela, a seta continua funcionando do jeito simples: os ícones voltam para a própria barra.",
        "auth.grant": "Autorizar…",
        "auth.useBar": "Deixar na barra mesmo",
        "panel.title": "Ícones ocultos",
        "panel.empty": "Nada oculto agora. Segure ⌘ e arraste um ícone para a esquerda da seta para escondê-lo.",
        "panel.allVisible": "Nenhum ícone está escondido no momento — estes são os que estão na barra.",
        "prefs.clickOpensPanel": "Clicar na seta abre a bandeja",
        "prefs.clickOpensPanel.help": "Com a bandeja, os ícones aparecem numa caixinha embaixo da seta, como no Windows. Desligado, eles voltam para a própria barra de menus.",
        "prefs.accessibility": "Acesso à barra de menus",
        "prefs.accessibility.granted": "Autorizado",
        "prefs.accessibility.missing": "A bandeja precisa da permissão de Acessibilidade para ler os ícones e abrir o menu deles.",
        "prefs.accessibility.grant": "Autorizar…",
        "prefs.accessibility.open": "Abrir Ajustes",
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
        "auth.title": "The tray needs one permission",
        "auth.body": "To show the hidden icons in a little box and open their menus, MacTray needs the Accessibility permission — that is how macOS lets an app see other apps' menu bar items. Without it the arrow still works the simple way: the icons go back onto the bar itself.",
        "auth.grant": "Grant…",
        "auth.useBar": "Keep it on the bar",
        "panel.title": "Hidden icons",
        "panel.empty": "Nothing hidden right now. Hold ⌘ and drag an icon to the left of the arrow to hide it.",
        "panel.allVisible": "No icon is hidden at the moment — these are the ones on the bar.",
        "prefs.clickOpensPanel": "Clicking the arrow opens the tray",
        "prefs.clickOpensPanel.help": "With the tray, the icons show up in a little box under the arrow, like on Windows. Turned off, they go back onto the menu bar itself.",
        "prefs.accessibility": "Menu bar access",
        "prefs.accessibility.granted": "Granted",
        "prefs.accessibility.missing": "The tray needs the Accessibility permission to read the icons and open their menus.",
        "prefs.accessibility.grant": "Grant…",
        "prefs.accessibility.open": "Open Settings",
        "about.tagline": "The Windows tray, on the Mac menu bar.",
        "about.version": "Version %@",
        "about.site": "Open nspx.dev",
    ]
}
