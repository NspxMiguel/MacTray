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
        let items = MenuBarScanner.scan()
        print("\(items.count) ícones encontrados:\n")
        for item in items {
            let clickable = MenuBarScanner.isClickable(item, on: screen)
            print(String(format: "  %-26@ x=%7.0f w=%5.0f  %@",
                         item.title as NSString, item.frame.minX, item.frame.width,
                         clickable ? "na barra" : "ESCONDIDO" as NSString))
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
        let area = MenuBarScanner.clickableArea(on: NSScreen.main)
        let frame = item.frame
        guard frame.minX >= area.minX, frame.maxX <= area.maxX else {
            print("\(item.displayName) está em x=\(Int(frame.minX)), fora da área clicável (\(Int(area.minX))–\(Int(area.maxX)))")
            print("mostre a barra antes: MacTray --show")
            exit(3)
        }
        RemoteCommand.send(.show)
        usleep(300_000)
        ItemActivator.activate(item, expand: {}) { result in
            print("\(item.displayName): \(result)")
            exit(0)
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
        let view = TrayPanelView(model: model, onPick: { _ in }, onPreferences: {}, onClose: {})

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
