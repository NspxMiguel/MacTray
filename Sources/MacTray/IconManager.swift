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
        // Entre o separador e a seta: é a faixa que sobrevive ao recolhimento. Sem a
        // moldura da seta não há faixa nenhuma para mirar, e soltar no meio da barra
        // devolveria o ícone para o lado errado da fronteira.
        let destination = toggle.width > 0
            ? max(separator.maxX + 4, toggle.minX - 4)
            : separator.maxX + 4
        move(item, to: destination) { result in
            guard case .success = result else { return completion(result) }
            // O gesto pode ser aceito e mesmo assim não mover nada — a barra recusa o
            // drop quando não há espaço. Quem responde é a moldura depois de assentar.
            let moved = MenuBarScanner.scan().first { $0.id == item.id }
            Log.write("depois do gesto: \(item.displayName) em x=\(moved.map { Int($0.frame.minX) }.map(String.init) ?? "sumiu"), fronteira em x=\(Int(separator.minX))")
            guard let moved, moved.frame.minX > separator.minX else {
                return completion(.failure(.notReachable))
            }
            completion(.success(()))
        }
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
            Log.write("não dá para agarrar \(item.displayName): x=\(Int(frame.minX)) w=\(Int(frame.width)), área \(Int(area.minX))–\(Int(area.maxX))")
            completion(.failure(.notReachable))
            return
        }

        let start = CGPoint(x: frame.midX, y: frame.midY)
        let end = CGPoint(x: min(max(destinationX, area.minX + 2), area.maxX - 2), y: frame.midY)
        Log.write("arrastando \(item.displayName) de x=\(Int(start.x)) para x=\(Int(end.x))")
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
        TrayController.isPerformingGesture = true
        defer {
            // Solto com folga: o monitor global recebe o evento depois do post, e liberar
            // no mesmo instante deixaria o último clique do gesto recolher a barra.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                TrayController.isPerformingGesture = false
            }
        }

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
