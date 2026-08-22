import AppKit
import SwiftUI

final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show(tab: PrefsTab? = nil) {
        if window == nil {
            let view = PreferencesView(tab: tab ?? PrefsTab.remembered)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = L10n.shared("prefs.title")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.title = L10n.shared("prefs.title")
        // Um app .accessory nao consegue se por na frente: a janela abria atras de tudo.
        // Vira .regular enquanto a janela existe (aparece no Dock nesse intervalo) e
        // volta a ser acessorio quando ela fecha.
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        // A troca de politica so vale no ciclo seguinte do run loop: ativar no mesmo
        // ciclo nao traz a janela para a frente, ela abre atras do app que estava ativo.
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKeyAndOrderFront(nil)
            self?.window?.orderFrontRegardless()
        }
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
