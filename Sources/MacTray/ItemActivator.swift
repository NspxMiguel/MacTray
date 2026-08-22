import AppKit
import ApplicationServices

/// Abre o menu de um ícone escondido.
///
/// O caminho bom é a ação de acessibilidade: ela funciona até para ícone que ficou
/// atrás do notch, onde clique de mouse não chega. Só que ela exige que o ícone esteja
/// no layout da barra — com a bandeja fechada os ícones estão a milhares de pontos à
/// esquerda e a mesma chamada responde "ação não suportada". Por isso a barra é
/// expandida antes, mesmo que ninguém vá olhar para ela.
enum ItemActivator {

    enum Result: String {
        case pressed          // ação de acessibilidade
        case clicked          // clique sintético na posição real
        case appActivated     // nem uma nem outra: sobrou trazer o app para a frente
        case failed
    }

    static func activate(_ item: MenuBarItem,
                         expand: @escaping () -> Void,
                         completion: @escaping (Result) -> Void) {
        expand()
        // O layout da barra só acontece no ciclo seguinte; agir antes disso pega o
        // estado antigo, com o ícone ainda fora da tela.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(perform(item))
        }
    }

    private static func perform(_ item: MenuBarItem) -> Result {
        if AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success {
            return .pressed
        }

        let frame = MenuBarScanner.frameOf(item.element)
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        let area = MenuBarScanner.clickableArea(on: screen)
        if frame.width > 0, frame.minX >= area.minX, frame.maxX <= area.maxX {
            click(at: CGPoint(x: frame.midX, y: frame.midY))
            return .clicked
        }

        if let app = NSRunningApplication(processIdentifier: item.ownerPID) {
            app.activate()
            return .appActivated
        }
        return .failed
    }

    private static func click(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(60_000)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(50_000)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}
