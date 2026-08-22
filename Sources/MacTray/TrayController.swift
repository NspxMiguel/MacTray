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

    /// A interface de preferências precisa falar com quem manda na barra.
    private(set) static weak var shared: TrayController?

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
        TrayController.shared = self
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
        // Só na primeira execução: depois disso vale a posição salva, seja ela do usuário
        // arrastando com ⌘ ou da aba Ícones movendo a fronteira.
        seedPreferredPositionIfNeeded("MacTrayToggle", 0)
        seedPreferredPositionIfNeeded("MacTrayExpand", 1)
        seedPreferredPositionIfNeeded("MacTrayAlwaysHidden", 2)

        // A fronteira escolhida pelo usuário vale sobre a posição semeada: o sistema apaga
        // a chave dele ao encerrar o app, então ela é reescrita a cada arranque.
        if let boundary = Defaults.boundaryPosition {
            UserDefaults.standard.set(boundary, forKey: "NSStatusItem Preferred Position MacTrayExpand")
        }

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

    /// A bandeja aberta também conta como "aberto": é ela que a seta comanda agora.
    private var isShowingSomething: Bool {
        state != .collapsed || TrayPanel.shared.isOpen
    }

    private func updateToggleImage() {
        toggleItem.button?.toolTip = L10n.shared("menu.hint")
        guard animationTimer == nil else { return } // a animação termina no quadro certo
        toggleItem.button?.image = symbolImage(for: isShowingSomething)
    }

    /// Meia volta na seta ao clicar. Feito trocando a imagem quadro a quadro: animar a
    /// layer do botão não aparece, porque o AppKit redesenha o item de status por cima
    /// da animação a cada ciclo. Rodar na mão custa nada e é o que de fato se vê.
    private var animationTimer: Timer?

    private func animateToggleButton() {
        animationTimer?.invalidate()
        animationTimer = nil

        guard Defaults.animateToggle,
              let button = toggleItem.button,
              let target = symbolImage(for: isShowingSomething) else { return }

        let frames = 12
        let duration = 0.3
        var frame = 0

        animationTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(frames),
                                              repeats: true) { [weak self] timer in
            frame += 1
            guard let self, let button = self.toggleItem.button else { timer.invalidate(); return }

            if frame >= frames {
                timer.invalidate()
                self.animationTimer = nil
                button.image = target
                return
            }

            // Meia volta com desaceleração, e uma encolhida no meio do caminho.
            let progress = Double(frame) / Double(frames)
            let eased = 1 - pow(1 - progress, 3)
            let angle = CGFloat((1 - eased) * .pi)
            let scale = CGFloat(1 - 0.22 * sin(progress * .pi))
            button.image = Self.transformed(target, rotation: angle, scale: scale)
        }
        // Primeiro quadro imediato: esperar o timer deixava um piscar com a imagem antiga.
        button.image = Self.transformed(target, rotation: .pi, scale: 1)
    }

    private func symbolImage(for showing: Bool) -> NSImage? {
        let symbols = Defaults.icon.symbols
        let name = showing ? symbols.expanded : symbols.collapsed
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: L10n.shared("app.name"))?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private static func transformed(_ image: NSImage, rotation: CGFloat, scale: CGFloat) -> NSImage {
        let size = image.size
        let output = NSImage(size: size)
        output.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: size.width / 2, yBy: size.height / 2)
        transform.rotate(byRadians: rotation)
        transform.scale(by: scale)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size),
                   operation: .sourceOver, fraction: 1)
        output.unlockFocus()
        output.isTemplate = true
        return output
    }

    // MARK: - Acoes

    func toggle() {
        state = (state == .collapsed) ? .expanded : .collapsed
        animateToggleButton()
    }

    func revealAll() {
        state = (state == .revealedAll) ? .collapsed : .revealedAll
    }

    func expand() {
        guard state == .collapsed else { return }
        state = .expanded
    }

    func collapse() {
        TrayPanel.shared.close()
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
        } else if Defaults.clickOpensPanel {
            togglePanel()
        } else {
            toggle()
        }
    }

    /// Abre a bandeja. Sem a permissão de Acessibilidade não há como ler os ícones dos
    /// outros apps, então nessa primeira vez o pedido sobe e o clique faz o de sempre.
    func togglePanel() {
        guard MenuBarScanner.isAuthorized else {
            explainAuthorization()
            toggle()
            return
        }
        if TrayPanel.shared.isOpen {
            TrayPanel.shared.close()
        } else {
            TrayPanel.shared.open(
                anchor: toggleItem.button,
                expand: { [weak self] in self?.state = .expanded },
                restore: { [weak self] in self?.state = .collapsed })
        }
        animateToggleButton()
        updateToggleImage()
    }

    /// A bandeja também fecha sozinha (clique fora, Esc); a seta precisa saber.
    func panelDidClose() {
        updateToggleImage()
    }

    /// O diálogo do sistema sozinho não diz por que um app de barra de menus quer
    /// Acessibilidade; sem explicação, a resposta natural é negar.
    private var didExplainAuthorization = false

    private func explainAuthorization() {
        guard !didExplainAuthorization else { return }
        didExplainAuthorization = true

        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l("auth.title")
        alert.informativeText = l("auth.body")
        alert.addButton(withTitle: l("auth.grant"))
        alert.addButton(withTitle: l("auth.useBar"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            MenuBarScanner.requestAuthorization()
        } else {
            Defaults.clickOpensPanel = false
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

    // MARK: - Mover a fronteira

    /// A chave de posição preferida guarda a distância até a borda direita da barra, e o
    /// sistema a relê quando o item é criado. Reposicionar os próprios itens é então uma
    /// questão de gravar e recriar — bem mais confiável do que arrastar, que só funciona
    /// no sentido da esquerda.
    private func preferredPosition(forX x: CGFloat, on screen: NSScreen?) -> Double {
        let width = (screen ?? NSScreen.main)?.frame.width ?? 1512
        return Double(max(0, width - x))
    }

    /// Põe o separador logo à esquerda do ícone: ele e todos à direita passam a ficar na
    /// barra. É a fronteira do app inteiro, não uma exceção para um ícone só.
    func moveBoundary(leftOf item: MenuBarItem) {
        let screen = toggleItem.button?.window?.screen
        // Só o separador se move. A seta fica na ponta direita: é ela que o usuário clica,
        // e mandá-la para o meio já a fez sumir atrás do notch uma vez.
        let position = preferredPosition(forX: item.frame.minX - 8, on: screen)
        Defaults.boundaryPosition = position
        rebuildOwnItems(positions: ["MacTrayExpand": position])
    }

    /// Recria os próprios itens para que o sistema releia a posição pedida.
    ///
    /// A ordem aqui não é enfeite: remover um NSStatusItem apaga a chave de posição dele,
    /// e o apagamento chega depois da remoção. Gravar antes de remover perde a escrita —
    /// foi assim que a seta foi parar atrás do notch no primeiro teste.
    func rebuildOwnItems(positions: [String: Double] = [:]) {
        let previous = state
        TrayPanel.shared.close()

        statusBar.removeStatusItem(toggleItem)
        statusBar.removeStatusItem(expandItem)
        if let alwaysHidden = alwaysHiddenItem {
            statusBar.removeStatusItem(alwaysHidden)
            alwaysHiddenItem = nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let defaults = UserDefaults.standard
            for (name, value) in positions {
                defaults.set(value, forKey: "NSStatusItem Preferred Position \(name)")
            }
            // A seta volta sempre para a ponta direita, onde dá para clicar nela.
            defaults.set(0.0, forKey: "NSStatusItem Preferred Position MacTrayToggle")
            self.buildItems()
            self.state = previous
            self.applyState()
        }
    }

    // MARK: - Quem fica na barra, quem fica na bandeja

    var separatorFrame: CGRect { expandItem.button?.window?.frame ?? .zero }

    /// Recolhido, quem está na bandeja foi empurrado para fora da tela (x negativo);
    /// aberto, o que separa os dois grupos é a posição do separador.
    func isPinned(_ item: MenuBarItem) -> Bool {
        if state == .collapsed { return item.frame.minX >= 0 }
        let boundary = separatorFrame
        // Sem a moldura do separador não há fronteira para comparar; recolhido é o único
        // estado em que a resposta é sempre confiável.
        guard boundary.width > 0 else { return item.frame.minX >= 0 }
        return item.frame.minX > boundary.minX
    }

    /// Move um ícone de um lado para o outro do separador. A barra precisa estar aberta
    /// durante o gesto — não dá para agarrar um ícone que está fora da tela.
    func setPinned(_ item: MenuBarItem, _ pinned: Bool,
                   completion: @escaping (Result<Void, IconManager.Failure>) -> Void) {
        let previous = state
        if state == .collapsed { state = .expanded }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            let separator = self.separatorFrame
            let finish: (Result<Void, IconManager.Failure>) -> Void = { result in
                if previous == .collapsed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.state = previous }
                }
                completion(result)
            }
            if pinned {
                // Trazer um ícone para a direita da seta exigiria arrastá-lo para a
                // direita, e o sistema só aceita o gesto para a esquerda. Mover a
                // fronteira dá no mesmo e não depende de gesto nenhum.
                MenuBarScanner.awaitLaidOut(item) { laidOut in
                    self.moveBoundary(leftOf: laidOut ?? item)
                    finish(.success(()))
                }
            } else {
                IconManager.unpin(item, separator: separator, completion: finish)
            }
        }
    }

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
