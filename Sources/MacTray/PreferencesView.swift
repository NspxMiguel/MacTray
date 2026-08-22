import SwiftUI
import Carbon.HIToolbox

/// Estado das preferencias exposto para a interface. Escreve no UserDefaults e avisa
/// o TrayController, que e quem sabe redesenhar a barra.
final class PrefsModel: ObservableObject {
    @Published var clickOpensPanel: Bool = Defaults.clickOpensPanel {
        didSet { Defaults.clickOpensPanel = clickOpensPanel; notify() }
    }
    @Published var accessibilityGranted: Bool = MenuBarScanner.isAuthorized
    @Published var launchAtLogin: Bool = LoginItem.isEnabled {
        didSet { LoginItem.set(launchAtLogin) }
    }
    @Published var autoHideEnabled: Bool = Defaults.autoHideEnabled {
        didSet { Defaults.autoHideEnabled = autoHideEnabled; notify() }
    }
    @Published var autoHideDelay: Double = Defaults.autoHideDelay {
        didSet { Defaults.autoHideDelay = autoHideDelay; notify() }
    }
    @Published var hideOnOutsideClick: Bool = Defaults.hideOnOutsideClick {
        didSet { Defaults.hideOnOutsideClick = hideOnOutsideClick; notify() }
    }
    @Published var alwaysHiddenEnabled: Bool = Defaults.alwaysHiddenEnabled {
        didSet { Defaults.alwaysHiddenEnabled = alwaysHiddenEnabled; notify() }
    }
    @Published var showSeparator: Bool = Defaults.showSeparator {
        didSet { Defaults.showSeparator = showSeparator; notify() }
    }
    @Published var icon: TrayIcon = Defaults.icon {
        didSet { Defaults.icon = icon; notify() }
    }
    @Published var hotKeyDescription: String? = HotKeyManager.describe(
        keyCode: Defaults.hotKeyCode, carbonModifiers: Defaults.hotKeyModifiers)

    private func notify() {
        NotificationCenter.default.post(name: .trayPreferencesChanged, object: nil)
    }

    func setHotKey(keyCode: Int, carbonModifiers: Int) {
        Defaults.hotKeyCode = keyCode
        Defaults.hotKeyModifiers = carbonModifiers
        hotKeyDescription = HotKeyManager.describe(keyCode: keyCode, carbonModifiers: carbonModifiers)
        HotKeyManager.shared.reload()
    }

    /// A autorização não chega por retorno de função: o usuário marca a caixa nos Ajustes
    /// e o app precisa perceber sozinho.
    func refreshAccessibility() {
        accessibilityGranted = MenuBarScanner.isAuthorized
    }

    func requestAccessibility() {
        MenuBarScanner.requestAuthorization()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refreshAccessibility() }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func clearHotKey() {
        setHotKey(keyCode: -1, carbonModifiers: 0)
    }
}

enum PrefsTab: String, Hashable {
    case general, appearance, about

    /// A janela reabre na aba onde o usuario parou.
    static var remembered: PrefsTab {
        get { PrefsTab(rawValue: UserDefaults.standard.string(forKey: "lastPrefsTab") ?? "") ?? .general }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "lastPrefsTab") }
    }
}

struct PreferencesView: View {
    @StateObject private var model = PrefsModel()
    @ObservedObject private var l10n = L10n.shared
    @State var tab: PrefsTab = .general

    var body: some View {
        TabView(selection: $tab) {
            general
                .tabItem { Label(l10n("prefs.tab.general"), systemImage: "gearshape") }
                .tag(PrefsTab.general)
            appearance
                .tabItem { Label(l10n("prefs.tab.appearance"), systemImage: "paintbrush") }
                .tag(PrefsTab.appearance)
            about
                .tabItem { Label(l10n("prefs.tab.about"), systemImage: "info.circle") }
                .tag(PrefsTab.about)
        }
        .frame(width: 460)
        .padding(.top, 8)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshAccessibility() }
        .onChange(of: tab) { _, newValue in PrefsTab.remembered = newValue }
    }

    // MARK: - Geral

    private var general: some View {
        Form {
            Section {
                Toggle(l10n("prefs.clickOpensPanel"), isOn: $model.clickOpensPanel)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n("prefs.clickOpensPanel.help"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if model.clickOpensPanel, !model.accessibilityGranted {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l10n("prefs.accessibility.missing"))
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Button(l10n("prefs.accessibility.grant")) { model.requestAccessibility() }
                                    Button(l10n("prefs.accessibility.open")) { model.openAccessibilitySettings() }
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }

            Section {
                Toggle(l10n("prefs.launchAtLogin"), isOn: $model.launchAtLogin)
                Toggle(l10n("prefs.hideOnOutsideClick"), isOn: $model.hideOnOutsideClick)
                Toggle(l10n("prefs.autoHide"), isOn: $model.autoHideEnabled)
                if model.autoHideEnabled {
                    Stepper(value: $model.autoHideDelay, in: 1...120, step: 1) {
                        Text("\(Int(model.autoHideDelay)) \(l10n("prefs.seconds"))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(l10n("prefs.alwaysHidden"), isOn: $model.alwaysHiddenEnabled)
            } footer: {
                Text(l10n("prefs.alwaysHidden.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                LabeledContent(l10n("prefs.hotkey")) {
                    HotKeyRecorder(model: model)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 340)
    }

    // MARK: - Aparencia

    private var appearance: some View {
        Form {
            Section {
                Picker(l10n("prefs.icon"), selection: $model.icon) {
                    ForEach(TrayIcon.allCases) { icon in
                        HStack {
                            Image(systemName: icon.symbols.collapsed)
                            Text(l10n(icon.labelKey))
                        }.tag(icon)
                    }
                }
                Toggle(l10n("prefs.showSeparator"), isOn: $model.showSeparator)
            }

            Section {
                Picker(l10n("prefs.language"), selection: Binding(
                    get: { l10n.language },
                    set: { L10n.shared.set($0) }
                )) {
                    Text(l10n("prefs.language.system")).tag(Language.system)
                    Text(Language.pt.nativeName).tag(Language.pt)
                    Text(Language.en.nativeName).tag(Language.en)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 200)
    }

    // MARK: - Sobre

    private var about: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.left.2")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.top, 20)
            Text(l10n("app.name")).font(.title2.bold())
            Text(l10n("about.tagline"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(l10n.string("about.version", AppInfo.version))
                .font(.caption)
                .foregroundStyle(.tertiary)

            GroupBox {
                Text(l10n("tip.body"))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(6)
            } label: {
                Text(l10n("tip.title"))
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            HStack {
                Link(l10n("about.site"), destination: URL(string: "https://www.nspx.dev/MacTray/")!)
                Spacer()
                Button(l10n("prefs.quit")) { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 340)
    }
}

/// Campo que grava o atalho. Usa monitor local (a janela precisa estar em foco),
/// entao nao pede permissao nenhuma ao sistema.
struct HotKeyRecorder: View {
    @ObservedObject var model: PrefsModel
    @ObservedObject private var l10n = L10n.shared
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .frame(minWidth: 110)
                    .monospaced()
            }
            .buttonStyle(.bordered)
            .tint(recording ? .accentColor : nil)

            if model.hotKeyDescription != nil {
                Button(l10n("prefs.hotkey.clear")) {
                    stopRecording()
                    model.clearHotKey()
                }
                .buttonStyle(.borderless)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if recording { return l10n("prefs.hotkey.recording") }
        return model.hotKeyDescription ?? l10n("prefs.hotkey.record")
    }

    private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let carbon = HotKeyManager.carbonModifiers(from: event.modifierFlags)
            guard carbon != 0 else { return nil } // atalho sem modificador roubaria a tecla do sistema inteiro
            model.setHotKey(keyCode: Int(event.keyCode), carbonModifiers: Int(carbon))
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
