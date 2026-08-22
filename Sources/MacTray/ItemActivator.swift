import AppKit

/// Abre o menu de um ícone escondido. Nao existe acao de acessibilidade nesses itens
/// (AXPress responde "unsupported"), entao o caminho e um clique sintetico na posicao
/// real — o que exige que o icone esteja de fato na area clicavel da barra.
enum ItemActivator {

    enum Result {
        case clicked
        /// Nem expandindo o icone cabe na barra: ficou atras do notch, onde clique nenhum
        /// chega. Sobra ativar o app dono.
        case appActivatedInstead
        case failed
    }

    static func activate(_ item: MenuBarItem,
                         expand: @escaping () -> Void,
                         completion: @escaping (Result) -> Void) {
        expand()
        // O layout da barra so acontece no ciclo seguinte; medir antes devolve a posicao antiga.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            let frame = MenuBarScanner.frameOf(item.element)
            let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
            let area = MenuBarScanner.clickableArea(on: screen)

            guard frame.width > 0, frame.minX >= area.minX, frame.maxX <= area.maxX else {
                if let app = NSRunningApplication(processIdentifier: item.ownerPID) {
                    app.activate()
                    completion(.appActivatedInstead)
                } else {
                    completion(.failed)
                }
                return
            }

            click(at: CGPoint(x: frame.midX, y: frame.midY))
            completion(.clicked)
        }
    }

    private static func click(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                         mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(60_000)
        down?.post(tap: .cghidEventTap)
        usleep(50_000)
        up?.post(tap: .cghidEventTap)
    }
}
