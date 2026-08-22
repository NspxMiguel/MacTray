import AppKit
import SwiftUI

/// A caixa que abre embaixo da seta, com os ícones que a barra não mostra — a bandeja
/// do Windows. Só ela resolve o caso do MacBook: quando os ícones não cabem, o macOS
/// os empurra para trás do notch, onde não dá nem para ver nem para clicar.
final class TrayPanel: NSObject {

    static let shared = TrayPanel()

    private var panel: NSPanel?
    /// Canto superior esquerdo desejado. O SwiftUI acerta o tamanho da caixa só depois do
    /// primeiro layout, e ancorar pela base fazia a caixa descer quando ela encolhia.
    private var desiredTopLeft: NSPoint?
    private var resizeObserver: NSObjectProtocol?
    private var model: TrayPanelModel?
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var onExpandRequest: (() -> Void)?
    private var onRestoreRequest: (() -> Void)?

    var isOpen: Bool { panel?.isVisible == true }

    /// `anchor` é o botão da seta; o painel abre alinhado com ele.
    func toggle(anchor: NSStatusBarButton?,
                expand: @escaping () -> Void,
                restore: @escaping () -> Void) {
        isOpen ? close() : open(anchor: anchor, expand: expand, restore: restore)
    }

    func open(anchor: NSStatusBarButton?,
              expand: @escaping () -> Void,
              restore: @escaping () -> Void) {
        close()
        onExpandRequest = expand
        onRestoreRequest = restore

        let screen = anchor?.window?.screen
        // Na primeira vez não há retrato nenhum: aí vale esperar a leitura (menos de um
        // segundo) em vez de abrir uma caixa vazia.
        let known = MenuBarScanner.cached.isEmpty ? MenuBarScanner.scan() : MenuBarScanner.cached
        let model = TrayPanelModel(items: known, screen: screen)
        self.model = model
        // Abre na hora com o que já se sabe e corrige assim que a leitura nova chega:
        // segurar o clique por um segundo para ler a barra inteira era pior.
        MenuBarScanner.refresh { items in model.update(items: items, screen: screen) }

        let content = TrayPanelView(
            model: model,
            onPick: { [weak self] item in self?.pick(item) },
            onPreferences: { PreferencesWindowController.shared.show() })

        let hosting = NSHostingView(rootView: content)
        hosting.layoutSubtreeIfNeeded()
        hosting.frame.size = hosting.fittingSize

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        self.panel = panel
        panel.setContentSize(hosting.fittingSize)
        position(panel, below: anchor)
        panel.orderFrontRegardless()

        // Cada relayout do SwiftUI muda a altura; reancorar pelo topo mantém a caixa
        // colada na barra em vez de escorregar para baixo.
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
                self?.applyTopLeft()
            }
        DispatchQueue.main.async { [weak self] in self?.applyTopLeft() }

        installMonitors()
    }

    func close() {
        removeMonitors()
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        resizeObserver = nil
        desiredTopLeft = nil
        model = nil
        onExpandRequest = nil
        onRestoreRequest = nil
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Posicionamento

    private func position(_ panel: NSPanel, below anchor: NSStatusBarButton?) {
        let width = panel.frame.width
        let screen = anchor?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let margin: CGFloat = 8

        // Alinha a borda direita do painel com a da seta, como o Windows faz.
        var x = (anchor?.window?.frame.maxX ?? screen.frame.maxX - margin) - width
        x = min(max(x, screen.frame.minX + margin), screen.frame.maxX - width - margin)

        // visibleFrame.maxY é exatamente onde a barra de menus termina.
        // visibleFrame.maxY é exatamente onde a barra de menus termina.
        desiredTopLeft = NSPoint(x: x, y: screen.visibleFrame.maxY - 4)
        applyTopLeft()
    }

    private func applyTopLeft() {
        guard let panel, let point = desiredTopLeft else { return }
        panel.setFrameTopLeftPoint(point)
    }

    // MARK: - Interação

    private func pick(_ item: MenuBarItem) {
        let expand = onExpandRequest
        let restore = onRestoreRequest
        close()
        ItemActivator.activate(item, expand: { expand?() }) { _ in
            // A barra só foi aberta para o ícone entrar no layout; o menu que abriu é
            // janela própria e continua de pé quando ela volta a recolher.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { restore?() }
        }
    }

    private func installMonitors() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.close()
            }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { self?.close(); return nil }
            return event
        }
    }

    private func removeMonitors() {
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        localKeyMonitor = nil
    }
}

// MARK: - Conteúdo

/// Estado da bandeja: quais ícones mostrar. Separado da view porque a leitura da barra
/// chega depois que a caixa já está na tela.
final class TrayPanelModel: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []
    @Published private(set) var showingAll = false

    init(items: [MenuBarItem], screen: NSScreen?) {
        update(items: items, screen: screen)
    }

    func update(items all: [MenuBarItem], screen: NSScreen?) {
        let hidden = all.filter { !MenuBarScanner.isClickable($0, on: screen) }
        showingAll = hidden.isEmpty
        items = hidden.isEmpty ? all : hidden
    }
}

struct TrayPanelView: View {
    @ObservedObject var model: TrayPanelModel
    let onPick: (MenuBarItem) -> Void
    let onPreferences: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var hovered: String?

    private var items: [MenuBarItem] { model.items }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(78), spacing: 2), count: min(max(items.count, 1), 5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l10n("panel.title"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Button(action: onPreferences) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l10n("menu.preferences"))
            }

            if items.isEmpty {
                Text(l10n("panel.empty"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 220, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        cell(item)
                    }
                }
            }

            if model.showingAll, !items.isEmpty {
                Text(l10n("panel.allVisible"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 320, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        )
    }

    private func cell(_ item: MenuBarItem) -> some View {
        Button {
            onPick(item)
        } label: {
            VStack(spacing: 3) {
                Group {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .renderingMode(item.isSystemItem ? .template : .original)
                    } else {
                        Image(systemName: "app.dashed").resizable()
                    }
                }
                .frame(width: 26, height: 26)
                .foregroundStyle(.primary)

                Text(item.displayName)
                    .font(.system(size: 9.5))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
                    .frame(width: 72, height: 24, alignment: .top)
            }
            .padding(.vertical, 6)
            .frame(width: 78)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovered == item.id ? Color.primary.opacity(0.12) : .clear))
        }
        .buttonStyle(.plain)
        .help(item.title)
        .onHover { inside in hovered = inside ? item.id : (hovered == item.id ? nil : hovered) }
    }
}
