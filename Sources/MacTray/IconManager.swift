import AppKit

/// Move ícones entre a barra e a bandeja fazendo o mesmo ⌘ arrastar que o usuário faria
/// na mão — não existe API para reposicionar o ícone de outro app, mas o gesto do sistema
/// funciona com eventos sintéticos.
enum IconManager {

    enum Failure: Error {
        /// O ícone está atrás do notch: não dá para agarrar o que não aparece.
        case notReachable
        case noAnchor
    }

    /// Leva o ícone para a direita do separador: passa a ficar sempre visível.
    static func pin(_ item: MenuBarItem, separator: CGRect, toggle: CGRect,
                    completion: @escaping (Result<Void, Failure>) -> Void) {
        // Entre o separador e a seta: é a faixa que sobrevive ao recolhimento.
        move(item, to: separator.maxX + 4, completion: completion)
        _ = toggle
    }

    /// Manda o ícone para a esquerda do separador: passa a viver na bandeja.
    static func unpin(_ item: MenuBarItem, separator: CGRect,
                      completion: @escaping (Result<Void, Failure>) -> Void) {
        move(item, to: separator.minX - 6, completion: completion)
    }

    private static func move(_ item: MenuBarItem, to destinationX: CGFloat,
                             completion: @escaping (Result<Void, Failure>) -> Void) {
        MenuBarScanner.awaitLaidOut(item) { laidOut in
            guard let laidOut else {
                completion(.failure(.notReachable))
                return
            }
            perform(laidOut, to: destinationX, completion: completion)
        }
    }

    private static func perform(_ item: MenuBarItem, to destinationX: CGFloat,
                                completion: @escaping (Result<Void, Failure>) -> Void) {
        let frame = item.frame
        let area = MenuBarScanner.clickableArea(on: NSScreen.main)
        guard frame.width > 0, frame.minX >= area.minX, frame.maxX <= area.maxX else {
            completion(.failure(.notReachable))
            return
        }

        let start = CGPoint(x: frame.midX, y: frame.midY)
        let end = CGPoint(x: min(max(destinationX, area.minX + 2), area.maxX - 2), y: frame.midY)
        drag(from: start, to: end)

        // A barra leva um instante para assentar antes de valer a pena reler.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            MenuBarScanner.refresh()
            completion(.success(()))
        }
    }

    private static func drag(from start: CGPoint, to end: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let cursorBefore = NSEvent.mouseLocation

        func post(_ type: CGEventType, _ point: CGPoint) {
            let event = CGEvent(mouseEventSource: source, mouseType: type,
                                mouseCursorPosition: point, mouseButton: .left)
            // Sem ⌘ o clique só abre o menu do ícone; com ⌘ ele vira arrastável.
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        post(.mouseMoved, start)
        usleep(120_000)
        post(.leftMouseDown, start)
        usleep(200_000)

        let steps = 24
        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            post(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y))
            usleep(25_000)
        }

        usleep(200_000)
        post(.leftMouseUp, end)

        // Devolve o ponteiro onde estava: o gesto é do app, não do usuário.
        CGWarpMouseCursorPosition(CGPoint(x: cursorBefore.x,
                                          y: (NSScreen.main?.frame.height ?? 0) - cursorBefore.y))
    }
}
