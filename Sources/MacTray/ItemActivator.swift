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

    /// `restore` devolve a barra ao estado anterior — e só depois que o menu fechar:
    /// recolher com o menu aberto o fecha junto, porque o ícone dono sai do layout.
    static func activate(_ item: MenuBarItem,
                         expand: @escaping () -> Void,
                         restore: (() -> Void)? = nil,
                         completion: @escaping (Result) -> Void) {
        expand()
        // Abrir a barra não é instantâneo: enquanto o ícone não entra no layout, a ação de
        // acessibilidade responde "não suportada" e a posição lida ainda é a de fora da
        // tela. Esperar um tempo fixo às vezes acertava e às vezes não — então espera-se
        // o ícone aparecer de fato, e é o elemento novo que vale.
        MenuBarScanner.awaitLaidOut(item) { laidOut in
            let result = perform(laidOut ?? item)
            completion(result)
            guard let restore else { return }
            switch result {
            case .pressed, .clicked:
                waitForMenuToClose(item, then: restore)
            case .appActivated, .failed:
                restore()
            }
        }
    }

    /// Enquanto o menu de um ícone está aberto, o item fica marcado como selecionado.
    /// É o único sinal disponível: menu aberto não é uma janela que dê para observar.
    private static func waitForMenuToClose(_ item: MenuBarItem, then restore: @escaping () -> Void) {
        var opened = false
        var elapsed: TimeInterval = 0
        let step: TimeInterval = 0.3
        let limit: TimeInterval = 120

        Timer.scheduledTimer(withTimeInterval: step, repeats: true) { timer in
            elapsed += step
            let selected = isSelected(item)
            if selected { opened = true }

            // Meio segundo sem abrir nada quer dizer que não havia menu para abrir.
            let gaveUp = !opened && elapsed > 0.9
            if (opened && !selected) || gaveUp || elapsed > limit {
                timer.invalidate()
                restore()
            }
        }
    }

    private static func isSelected(_ item: MenuBarItem) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item.element, kAXSelectedAttribute as CFString, &value) == .success
        else { return false }
        return (value as? Bool) ?? false
    }

    private static func perform(_ stale: MenuBarItem) -> Result {
        // O elemento guardado quando a barra estava recolhida não aceita mais a ação
        // depois do relayout; o mesmo ícone, relido agora, aceita.
        let fresh = MenuBarScanner.items(forPID: stale.ownerPID)
        let item = fresh.first { $0.id == stale.id }
            ?? fresh.first { $0.label == stale.label }
            ?? stale

        // A primeira tentativa costuma voltar "ação não suportada" e a seguinte funciona:
        // o app dono só monta a árvore de acessibilidade quando alguém pergunta, e a ação
        // aparece um instante depois. Medido no Ollama — 1 erro, depois quatro acertos
        // seguidos. Por isso insiste antes de desistir; parar no primeiro acerto importa,
        // porque cada acionamento é um liga/desliga do menu.
        for attempt in 0..<6 {
            if AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success {
                return .pressed
            }
            if attempt < 5 { usleep(130_000) }
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
