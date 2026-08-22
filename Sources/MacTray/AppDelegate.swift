import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tray: TrayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !terminateIfAlreadyRunning() else { return }

        Defaults.registerDefaults()
        _ = L10n.shared

        let tray = TrayController()
        self.tray = tray

        HotKeyManager.shared.onTrigger = { [weak tray] in tray?.toggle() }
        HotKeyManager.shared.reload()

        observeRemoteCommands(tray: tray)

        if !Defaults.didShowOnboarding {
            Defaults.didShowOnboarding = true
            showOnboarding()
        }
    }

    /// Comandos vindos de outro processo (o proprio binario chamado com --toggle).
    private func observeRemoteCommands(tray: TrayController) {
        let center = DistributedNotificationCenter.default()
        for command in RemoteCommand.allCases {
            center.addObserver(forName: command.notificationName, object: nil, queue: .main) { [weak tray] _ in
                guard let tray else { return }
                switch command {
                case .toggle: tray.toggle()
                case .show: tray.expand()
                case .hide: tray.collapse()
                case .showAll: tray.revealAll()
                case .preferences: PreferencesWindowController.shared.show()
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
}
