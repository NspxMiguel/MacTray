import AppKit
import SwiftUI

/// Ferramentas de linha de comando para conferir o que o app está lendo da barra.
enum Diagnostics {

    @MainActor
    static func printItems() {
        guard MenuBarScanner.isAuthorized else {
            print("sem permissão de Acessibilidade — a bandeja não consegue ler a barra de menus")
            print("autorize em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade")
            exit(2)
        }
        let screen = NSScreen.main
        let area = MenuBarScanner.clickableArea(on: screen)
        print("área clicável da barra: x de \(Int(area.minX)) a \(Int(area.maxX))")
        // Inclui os próprios ícones: quando a seta some, é justamente a moldura dela que
        // responde se ela não foi criada ou se nasceu num x onde ninguém alcança.
        let items = MenuBarScanner.scan(includingOwn: true)
        let ownPID = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "dev.nspx.MacTray")
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?
            .processIdentifier
        print("\(items.count) ícones encontrados:\n")
        for item in items {
            let clickable = MenuBarScanner.isClickable(item, on: screen)
            let mark = item.ownerPID == ownPID ? "  <- MacTray" : ""
            print(String(format: "  %-26@ x=%7.0f w=%5.0f  %@%@",
                         item.title as NSString, item.frame.minX, item.frame.width,
                         clickable ? "na barra" : "ESCONDIDO" as NSString, mark as NSString))
        }
        if let ownPID, !items.contains(where: { $0.ownerPID == ownPID }) {
            print("\naviso: o MacTray está rodando mas não pôs nenhum ícone na barra.")
        } else if ownPID == nil {
            print("\naviso: o MacTray não está rodando.")
        }
    }

    /// Abre o menu de um ícone pelo nome do app. Serve para Atalhos e Raycast
    /// ("abrir o menu do Docker") e para conferir se o clique está chegando.
    @MainActor
    static func openItem(named needle: String) {
        guard MenuBarScanner.isAuthorized else {
            print("sem permissão de Acessibilidade")
            exit(2)
        }
        let items = MenuBarScanner.scan()
        let lowered = needle.lowercased()
        guard let item = items.first(where: {
            $0.ownerName.lowercased().contains(lowered) || $0.displayName.lowercased().contains(lowered)
        }) else {
            print("não achei nenhum ícone de \"\(needle)\"")
            exit(1)
        }
        // Pede à instância que está na barra para expandir: o ícone precisa estar no
        // layout para aceitar a ação.
        RemoteCommand.send(.show)
        ItemActivator.activate(item, expand: {}) { result in
            print("\(item.displayName): \(result.rawValue)")
            exit(result == .failed ? 1 : 0)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(3))
    }

    /// Desenha a bandeja num PNG, com os ícones reais.
    @MainActor
    static func renderPanel(to path: String) {
        let items = MenuBarScanner.scan()
        let screen = NSScreen.main
        let hidden = items.filter { !MenuBarScanner.isClickable($0, on: screen) }
        let model = TrayPanelModel(items: items, screen: screen)
        let view = TrayPanelView(model: model, onPick: { _ in }, onPreferences: {})

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("não consegui desenhar a bandeja")
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("bandeja desenhada em \(path) — \(hidden.count) ícones escondidos de \(items.count)")
    }
}
