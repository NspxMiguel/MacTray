import AppKit
import ApplicationServices

/// Um ícone da barra de menus pertencente a outro app.
struct MenuBarItem: Identifiable, Equatable {
    let id: String
    let ownerPID: pid_t
    let ownerName: String
    /// Descrição do próprio item (o Central de Controle nomeia "Wi-Fi", "Bluetooth"…).
    let label: String
    let frame: CGRect
    let element: AXUIElement

    static func == (a: MenuBarItem, b: MenuBarItem) -> Bool { a.id == b.id }

    /// A Central de Controle é dona de vários ícones ao mesmo tempo (Wi-Fi, Bluetooth,
    /// Foco…). Mostrar o ícone do app repetiria a mesma engrenagem quatro vezes, então
    /// esses ganham o símbolo do sistema que corresponde ao que o item faz.
    var icon: NSImage? {
        if let symbol = systemSymbol {
            let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: displayName)?
                .withSymbolConfiguration(config) {
                image.isTemplate = true
                return image
            }
        }
        return NSRunningApplication(processIdentifier: ownerPID)?.icon
    }

    var isSystemItem: Bool {
        NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier == "com.apple.controlcenter"
    }

    private var systemSymbol: String? {
        guard isSystemItem else { return nil }
        let key = label.lowercased()
        if key.contains("wi") && key.contains("fi") { return "wifi" }
        if key.contains("bluetooth") { return "dot.radiowaves.right" }
        if key.contains("focus") || key.contains("foco") { return "moon.fill" }
        if key.contains("playing") || key.contains("tocando") { return "play.circle" }
        if key.contains("batt") || key.contains("bateria") { return "battery.100" }
        if key.contains("sound") || key.contains("som") || key.contains("volume") { return "speaker.wave.2" }
        if key.contains("display") || key.contains("tela") { return "sun.max" }
        if key.contains("screen") || key.contains("mirror") { return "rectangle.on.rectangle" }
        if key.contains("clock") || key.contains("relógio") { return "clock" }
        return "switch.2"
    }

    /// O nome curto que vai embaixo do ícone.
    var displayName: String {
        // "Wi‑Fi, connected, 3 bars" é descrição de leitor de tela: fica só o começo.
        let short = label.split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if isSystemItem, !short.isEmpty { return short }
        // "GeminiAppLauncher" e "Docker Desktop Helper" são nomes de processo, não de
        // produto: o que o usuário reconhece é o começo.
        var name = ownerName
        for suffix in ["AppLauncher", "Launcher", "Helper", "Daemon", "Agent", "-daemon"] {
            if name.count > suffix.count + 2, name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return name
    }

    /// O texto completo, para o tooltip.
    var title: String {
        if !label.isEmpty, label != ownerName { return "\(ownerName) · \(label)" }
        return ownerName
    }
}

/// Lê a barra de menus pela API de Acessibilidade. É o único caminho: as janelas dos
/// ícones pertencem todas ao processo da Central de Controle, então CGWindowList não
/// diz de quem é cada uma. Aqui cada app entrega os seus pelo AXExtrasMenuBar.
enum MenuBarScanner {

    static var isAuthorized: Bool { AXIsProcessTrusted() }

    /// Abre o diálogo do sistema e devolve se já está autorizado.
    @discardableResult
    static func requestAuthorization() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Último retrato conhecido da barra. A leitura em si é cara (uma conversa de
    /// acessibilidade com cada app aberto), então a bandeja abre com o retrato e manda
    /// atualizar por baixo em vez de segurar o clique.
    private(set) static var cached: [MenuBarItem] = []
    private static let scanQueue = DispatchQueue(label: "dev.nspx.MacTray.scan", qos: .userInitiated)

    static func refresh(completion: (([MenuBarItem]) -> Void)? = nil) {
        scanQueue.async {
            let items = scan()
            DispatchQueue.main.async {
                cached = items
                completion?(items)
            }
        }
    }

    /// Perguntar a todos os processos abertos custa meio segundo e uma enxurrada de
    /// threads — a cada clique na seta isso travava a máquina inteira. Quase nenhum app
    /// tem ícone na barra, então os que têm ficam anotados e são os únicos consultados no
    /// caminho rápido; a lista completa é revista de vez em quando, em segundo plano.
    private static var knownOwners: [pid_t] = []
    private static var lastFullScan: Date = .distantPast
    private static let fullScanInterval: TimeInterval = 20

    /// `includingOwn` existe para o diagnostico: a bandeja nunca deve mostrar os proprios
    /// icones, mas quem esta depurando precisa justamente saber onde a seta foi parar.
    static func scan(includingOwn: Bool = false) -> [MenuBarItem] {
        guard isAuthorized else { return [] }
        let now = Date()
        let owners: [NSRunningApplication]

        if includingOwn {
            owners = candidateApps(includingOwn: true)
        } else if !knownOwners.isEmpty, now.timeIntervalSince(lastFullScan) < fullScanInterval {
            owners = knownOwners.compactMap { NSRunningApplication(processIdentifier: $0) }
        } else {
            lastFullScan = now
            owners = candidateApps()
        }

        let found = read(from: owners)
        let ownersWithItems = Set(found.map(\.ownerPID))
        // O caminho rapido nao pode herdar a lista do diagnostico: ela inclui o proprio
        // app, e a bandeja passaria a listar a propria seta.
        if !includingOwn, !ownersWithItems.isEmpty { knownOwners = Array(ownersWithItems) }
        return found.sorted { $0.frame.minX < $1.frame.minX }
    }

    private static func candidateApps(includingOwn: Bool = false) -> [NSRunningApplication] {
        let ownBundleID = Bundle.main.bundleIdentifier ?? "dev.nspx.MacTray"
        return NSWorkspace.shared.runningApplications.filter {
            ($0.bundleIdentifier != ownBundleID || includingOwn)
                && $0.activationPolicy != .prohibited
        }
    }

    private static func read(from apps: [NSRunningApplication]) -> [MenuBarItem] {
        // Concorrência limitada de propósito: chamada de acessibilidade bloqueia a thread,
        // e deixar o GCD abrir uma por app abria dezenas de uma vez.
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 6
        queue.qualityOfService = .userInitiated

        let lock = NSLock()
        var found: [MenuBarItem] = []

        for app in apps {
            queue.addOperation {
                let mine = itemsOf(app)
                guard !mine.isEmpty else { return }
                lock.lock()
                found.append(contentsOf: mine)
                lock.unlock()
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        return found
    }

    private static func itemsOf(_ app: NSRunningApplication) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.2)
        guard let extras = copy(appElement, "AXExtrasMenuBar") else { return [] }
        let bar = extras as! AXUIElement
        AXUIElementSetMessagingTimeout(bar, 0.2)
        guard let children = copy(bar, kAXChildrenAttribute as String) as? [AXUIElement] else { return [] }

        var mine: [MenuBarItem] = []
        for (position, item) in children.enumerated() {
            AXUIElementSetMessagingTimeout(item, 0.2)
            let frame = frameOf(item)
            // Itens zerados são placeholders que a Central de Controle mantém para
            // recursos desligados; não existem na barra.
            guard frame.width > 0 else { continue }
            let label = (copy(item, kAXDescriptionAttribute as String) as? String)
                ?? (copy(item, kAXTitleAttribute as String) as? String) ?? ""
            mine.append(MenuBarItem(
                id: "\(app.processIdentifier)-\(position)",
                ownerPID: app.processIdentifier,
                ownerName: app.localizedName ?? "?",
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                frame: frame,
                element: item))
        }
        return mine
    }

    /// Relê os ícones de um app só. Quando a barra faz relayout, o macOS troca os
    /// elementos de acessibilidade: o que estava guardado ainda responde posição, mas
    /// recusa a ação de clique. Antes de acionar, vale pegar o elemento novo.
    static func items(forPID pid: pid_t) -> [MenuBarItem] {
        guard isAuthorized, let app = NSRunningApplication(processIdentifier: pid) else { return [] }
        return itemsOf(app)
    }

    /// Espera o ícone entrar no layout da barra e devolve a versão nova dele. Depois de
    /// abrir a barra, o elemento guardado ainda responde a posição antiga (fora da tela) e
    /// recusa qualquer ação — quem for agir precisa deste, não daquele.
    static func awaitLaidOut(_ item: MenuBarItem,
                             timeout: TimeInterval = 1.8,
                             then completion: @escaping (MenuBarItem?) -> Void) {
        var elapsed: TimeInterval = 0
        let step: TimeInterval = 0.08

        Timer.scheduledTimer(withTimeInterval: step, repeats: true) { timer in
            elapsed += step
            let fresh = items(forPID: item.ownerPID)
            let match = fresh.first { $0.id == item.id }
                ?? fresh.first { $0.label == item.label && !item.label.isEmpty }

            if let match, match.frame.minX >= 0 {
                timer.invalidate()
                // Um quadro a mais: recém-posicionado, o ícone ainda recusa a ação.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { completion(match) }
            } else if elapsed >= timeout {
                timer.invalidate()
                completion(match)
            }
        }
    }

    /// Área da barra onde um clique realmente chega no ícone: à direita do notch.
    /// Fora dela o macOS desenha o recorte da câmera ou os menus do app, e o clique
    /// não encontra ninguém — foi medido, não suposto.
    static func clickableArea(on screen: NSScreen?) -> CGRect {
        guard let screen = screen ?? NSScreen.main else { return .zero }
        if let right = screen.auxiliaryTopRightArea { return right }
        // Tela sem notch: a barra inteira serve.
        return CGRect(x: screen.frame.minX, y: screen.frame.maxY - 24,
                      width: screen.frame.width, height: 24)
    }

    static func isClickable(_ item: MenuBarItem, on screen: NSScreen?) -> Bool {
        let area = clickableArea(on: screen)
        return item.frame.minX >= area.minX && item.frame.maxX <= area.maxX
    }

    // MARK: - AX

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func frameOf(_ element: AXUIElement) -> CGRect {
        var origin = CGPoint.zero
        var size = CGSize.zero
        if let value = copy(element, kAXPositionAttribute as String) {
            AXValueGetValue(value as! AXValue, .cgPoint, &origin)
        }
        if let value = copy(element, kAXSizeAttribute as String) {
            AXValueGetValue(value as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: origin, size: size)
    }
}
