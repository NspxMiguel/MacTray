import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tray: TrayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !terminateIfAlreadyRunning() else { return }

        Defaults.registerDefaults()
        _ = L10n.shared
        applyActivationPolicy()

        let tray = TrayController()
        self.tray = tray

        HotKeyManager.shared.onTrigger = { [weak tray] in tray?.toggle() }
        HotKeyManager.shared.reload()

        TrayPanel.shared.onClose = { [weak tray] in tray?.panelDidClose() }

        observeRemoteCommands(tray: tray)

        // Retrato do arranque: quando a bandeja não abre, a resposta quase sempre está
        // nestas três linhas — sem acessibilidade não há o que ler, e sem área clicável
        // não há onde desenhar.
        let area = MenuBarScanner.clickableArea(on: NSScreen.main)
        Log.write("subindo \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") — "
                  + "acessibilidade: \(MenuBarScanner.isAuthorized ? "sim" : "NÃO"), "
                  + "área clicável \(Int(area.minX))–\(Int(area.maxX)), "
                  + "fronteira \(Defaults.boundaryPosition.map { String(Int($0)) } ?? "—")")

        // Deixa o retrato da barra pronto antes do primeiro clique na seta.
        MenuBarScanner.refresh()

        if !Defaults.didShowOnboarding {
            Defaults.didShowOnboarding = true
            showOnboarding()
        }
    }

    /// O Info.plist marca LSUIElement, então o app nasce acessório: sem Dock e sem
    /// alternador de janelas — e, de quebra, invisível para quem lista os aplicativos
    /// instalados do sistema. Quem quiser encontrá-lo por lá liga isto.
    func applyActivationPolicy() {
        NSApp.setActivationPolicy(Defaults.showInDock ? .regular : .accessory)
    }

    /// Comandos vindos de outro processo (o proprio binario chamado com --toggle).
    private func observeRemoteCommands(tray: TrayController) {
        let center = DistributedNotificationCenter.default()
        for command in RemoteCommand.allCases {
            center.addObserver(forName: command.notificationName, object: nil, queue: .main) { [weak tray, weak self] note in
                guard let tray, let self else { return }
                switch command {
                case .toggle: tray.toggle()
                case .show: tray.expand()
                case .hide: tray.collapse()
                case .showAll: tray.revealAll()
                case .panel: tray.togglePanel()
                case .preferences: PreferencesWindowController.shared.show()
                case .dock:
                    guard let wanted = LoginItemArgument.value(note.object as? String) else { return }
                    Defaults.showInDock = wanted
                    self.applyActivationPolicy()
                    Log.write("ícone no Dock \(wanted ? "ligado" : "desligado")")
                case .pin, .unpin:
                    guard let needle = note.object as? String else { return }
                    let wanted = command == .pin
                    let items = MenuBarScanner.scan()
                    guard let item = items.first(where: {
                        $0.ownerName.lowercased().contains(needle.lowercased())
                            || $0.displayName.lowercased().contains(needle.lowercased())
                    }) else {
                        Log.write("--\(command.rawValue): não achei ícone de \(needle). Vejo: "
                                  + items.map { "\($0.ownerName)/\($0.displayName)" }.joined(separator: ", "))
                        return
                    }
                    Log.write("--\(command.rawValue) \(needle) -> \(item.title) em x=\(Int(item.frame.minX))")
                    tray.setPinned(item, wanted) { result in
                        switch result {
                        case .success: Log.write("\(item.displayName) agora está \(wanted ? "na barra" : "na bandeja")")
                        case .failure(let error): Log.write("não deu para mover \(item.displayName): \(error)")
                        }
                    }
                }
            }
        }
    }

    /// Duas copias do app significam duas setas na barra. A segunda sai de cena.
    private func terminateIfAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !others.isEmpty else { return false }
        others.first?.activate()
        NSApp.terminate(nil)
        return true
    }

    private func showOnboarding() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l("tip.title")
        alert.informativeText = l("tip.body")
        alert.addButton(withTitle: l("tip.gotIt"))
        alert.addButton(withTitle: l("menu.preferences"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            PreferencesWindowController.shared.show()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Com ícone no Dock, clicar nele não tem janela para trazer de volta: abre as
    /// Preferências, que é a única janela que o app tem.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { PreferencesWindowController.shared.show() }
        return true
    }
}
