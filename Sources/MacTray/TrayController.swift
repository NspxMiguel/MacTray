import AppKit

extension Notification.Name {
    static let trayPreferencesChanged = Notification.Name("MacTrayPreferencesChanged")
}

/// O truque: um NSStatusItem com largura enorme empurra para fora da tela tudo o que
/// esta a esquerda dele. Nao existe API publica para esconder o icone de outro app,
/// entao o que se faz e ocupar o espaco. A barra fica assim, da esquerda para a direita:
///
///   [sempre ocultos] (alwaysHiddenItem) [ocultos] (expandItem) (toggleItem = a seta)
///
/// Fechado: expandItem gigante  -> some tudo o que esta a esquerda dele.
/// Aberto:  expandItem fino, alwaysHiddenItem gigante -> aparece a area normal.
/// ⌥ aberto: os dois finos -> aparece tudo.
final class TrayController: NSObject {

    enum State {
        case collapsed
        case expanded
        case revealedAll
    }

    private static let hugeLength: CGFloat = 10_000
    private static let separatorLength: CGFloat = 10

    private let statusBar = NSStatusBar.system
    private var toggleItem: NSStatusItem!
    private var expandItem: NSStatusItem!
    private var alwaysHiddenItem: NSStatusItem?

    private var autoHideTimer: Timer?
    private var outsideClickMonitor: Any?

    private(set) var state: State = .collapsed {
        didSet { applyState() }
    }

    override init() {
        super.init()
        buildItems()
        applyState()
        NotificationCenter.default.addObserver(
            self, selector: #selector(preferencesChanged),
            name: .trayPreferencesChanged, object: nil)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.applyState() }
    }

    // MARK: - Montagem

    /// Numa barra ja lotada o macOS simplesmente nao desenha um item novo: ele nasce na
    /// ponta esquerda, que e justamente a parte cortada pelo notch. A posicao preferida
    /// e gravada no UserDefaults com esta chave (a mesma que o sistema escreve quando se
    /// arrasta um icone com ⌘) e vale a distancia ate a borda direita — 0 encosta no
    /// relogio. Sem isso o app inteiro nao aparece para quem mais precisa dele.
    private func seedPreferredPositionIfNeeded(_ autosaveName: String, _ position: Double) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        // So na primeira vez: depois disso quem manda e o que o usuario arrastou.
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        UserDefaults.standard.set(position, forKey: key)
    }

    private func buildItems() {
        // Ordem de criacao importa: cada item novo entra a esquerda dos anteriores.
        seedPreferredPositionIfNeeded("MacTrayToggle", 0)
        seedPreferredPositionIfNeeded("MacTrayExpand", 1)
        seedPreferredPositionIfNeeded("MacTrayAlwaysHidden", 2)

        toggleItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem.autosaveName = "MacTrayToggle"
        toggleItem.behavior = []
        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = L10n.shared("menu.hint")
        }

        expandItem = statusBar.statusItem(withLength: Self.separatorLength)
        expandItem.autosaveName = "MacTrayExpand"
        if let button = expandItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        rebuildAlwaysHiddenItem()
        updateToggleImage()
    }

    private func rebuildAlwaysHiddenItem() {
        if Defaults.alwaysHiddenEnabled {
            guard alwaysHiddenItem == nil else { return }
            let item = statusBar.statusItem(withLength: Self.separatorLength)
            item.autosaveName = "MacTrayAlwaysHidden"
            if let button = item.button {
                button.image = Self.separatorImage(dashed: true)
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            alwaysHiddenItem = item
        } else if let item = alwaysHiddenItem {
            statusBar.removeStatusItem(item)
            alwaysHiddenItem = nil
            if state == .revealedAll { state = .expanded }
        }
    }

    /// Linha fina desenhada na mao: mais previsivel do que depender de um SF Symbol
    /// de linha vertical existir em todas as versoes do macOS.
    private static func separatorImage(dashed: Bool) -> NSImage {
        let size = NSSize(width: 2, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            if dashed {
                let path = NSBezierPath()
                path.lineWidth = 2
                path.setLineDash([3, 3], count: 2, phase: 0)
                path.move(to: NSPoint(x: 1, y: rect.minY))
                path.line(to: NSPoint(x: 1, y: rect.maxY))
                NSColor.black.setStroke()
                path.stroke()
            } else {
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Estado

    private func applyState() {
        let huge = Self.hugeLength
        let thin = Self.separatorLength

        switch state {
        case .collapsed:
            expandItem.length = huge
            expandItem.button?.image = nil
            alwaysHiddenItem?.length = thin
        case .expanded:
            expandItem.length = thin
            expandItem.button?.image = Defaults.showSeparator ? Self.separatorImage(dashed: false) : nil
            alwaysHiddenItem?.length = Defaults.alwaysHiddenEnabled ? huge : thin
            alwaysHiddenItem?.button?.image = nil
        case .revealedAll:
            expandItem.length = thin
            expandItem.button?.image = Defaults.showSeparator ? Self.separatorImage(dashed: false) : nil
            alwaysHiddenItem?.length = thin
            alwaysHiddenItem?.button?.image = Self.separatorImage(dashed: true)
        }

        updateToggleImage()
        updateAutoHideTimer()
        updateOutsideClickMonitor()
    }

    private func updateToggleImage() {
        let symbols = Defaults.icon.symbols
        let name = state == .collapsed ? symbols.collapsed : symbols.expanded
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: L10n.shared("app.name"))?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        toggleItem.button?.image = image
        toggleItem.button?.toolTip = L10n.shared("menu.hint")
    }

    // MARK: - Acoes

    func toggle() {
        state = (state == .collapsed) ? .expanded : .collapsed
    }

    func revealAll() {
        state = (state == .revealedAll) ? .collapsed : .revealedAll
    }

    func expand() {
        guard state == .collapsed else { return }
        state = .expanded
    }

    func collapse() {
        guard state != .collapsed else { return }
        state = .collapsed
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isRight {
            showMenu(for: sender)
        } else if event?.modifierFlags.contains(.option) == true, Defaults.alwaysHiddenEnabled {
            revealAll()
        } else {
            toggle()
        }
    }

    private func showMenu(for button: NSStatusBarButton) {
        let l = L10n.shared
        let menu = NSMenu()

        if Defaults.alwaysHiddenEnabled {
            let showAll = NSMenuItem(title: l("menu.showAll"), action: #selector(menuRevealAll), keyEquivalent: "")
            showAll.target = self
            menu.addItem(showAll)
            menu.addItem(.separator())
        }

        let prefs = NSMenuItem(title: l("menu.preferences"), action: #selector(menuPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let about = NSMenuItem(title: l("menu.about"), action: #selector(menuAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: l("menu.quit"), action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Nao da para deixar o menu preso no NSStatusItem: com `menu` definido o botao
        // para de mandar a acao do clique esquerdo, e o truque de pendurar/despendurar
        // durante o clique nao abre nada. Abrir na mao, ancorado no botao, funciona.
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    @objc private func menuRevealAll() { revealAll() }
    @objc private func menuPreferences() { PreferencesWindowController.shared.show() }
    @objc private func menuAbout() { PreferencesWindowController.shared.show(tab: .about) }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - Automatismos

    private func updateAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        guard Defaults.autoHideEnabled, state != .collapsed else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: Defaults.autoHideDelay, repeats: false) { [weak self] _ in
            self?.collapse()
        }
    }

    private func updateOutsideClickMonitor() {
        let wanted = Defaults.hideOnOutsideClick && state != .collapsed
        if wanted, outsideClickMonitor == nil {
            // Monitor global de mouse nao exige permissao de acessibilidade
            // (so o de teclado exige) e nao ve os cliques do proprio app.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    self?.collapse()
                }
        } else if !wanted, let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    @objc private func preferencesChanged() {
        rebuildAlwaysHiddenItem()
        applyState()
    }
}
