import SwiftUI
import AppKit

/// Lista da barra dividida em dois grupos, com o botão que move o ícone de um para o
/// outro. É o "tirar e colocar coisas da bandeja" sem precisar acertar o ⌘ arrastar.
final class IconsModel: ObservableObject {
    @Published private(set) var pinned: [MenuBarItem] = []
    @Published private(set) var hidden: [MenuBarItem] = []
    @Published private(set) var busy = false
    @Published var problem: String?

    func reload() {
        // Recolhe antes de medir: com a barra aberta todo mundo tem posição positiva e a
        // fronteira depende do separador, que nem sempre está desenhado.
        TrayController.shared?.collapse()
        MenuBarScanner.refresh { [weak self] items in
            guard let self, let tray = TrayController.shared else { return }
            let mine = items.filter { $0.frame.width > 0 }
            self.pinned = mine.filter { tray.isPinned($0) }
            self.hidden = mine.filter { !tray.isPinned($0) }
        }
    }

    func move(_ item: MenuBarItem, toBar: Bool) {
        guard let tray = TrayController.shared, !busy else { return }
        busy = true
        problem = nil
        tray.setPinned(item, toBar) { [weak self] result in
            guard let self else { return }
            self.busy = false
            if case .failure(let error) = result, error == .notReachable {
                self.problem = L10n.shared("icons.unreachable")
            }
            // A barra ainda está se acomodando quando o gesto termina.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.reload() }
        }
    }
}

extension IconManager.Failure: Equatable {}

struct IconsView: View {
    @StateObject private var model = IconsModel()
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: 0) {
            // ScrollView explícito: dentro de uma janela de altura fixa, a List não estava
            // rolando, e quem tem muitos ícones não alcançava os últimos.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    section(l10n("icons.pinned"), items: model.pinned, toBar: false)
                    section(l10n("icons.hidden"), items: model.hidden, toBar: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if let problem = model.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(l10n("icons.help"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if model.busy { ProgressView().controlSize(.small) }
                    Spacer()
                    Button(l10n("icons.refresh")) { model.reload() }
                        .controlSize(.small)
                }
            }
            .padding(12)
        }
        .frame(height: 430)
        .onAppear { model.reload() }
    }

    private func section(_ title: String, items: [MenuBarItem], toBar: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if items.isEmpty {
                emptyRow.padding(.vertical, 6)
            } else {
                ForEach(items) { item in
                    row(item, toBar: toBar)
                    if item.id != items.last?.id { Divider().opacity(0.4) }
                }
            }
        }
    }

    private var emptyRow: some View {
        Text("—").foregroundStyle(.tertiary)
    }

    private func row(_ item: MenuBarItem, toBar: Bool) -> some View {
        HStack(spacing: 10) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .renderingMode(item.isSystemItem ? .template : .original)
                    .frame(width: 18, height: 18)
            }
            Text(item.displayName)
                .lineLimit(1)
            Spacer()
            Button(l10n(toBar ? "icons.pin" : "icons.unpin")) {
                model.move(item, toBar: toBar)
            }
            .controlSize(.small)
            .disabled(model.busy)
        }
        .padding(.vertical, 2)
    }
}
