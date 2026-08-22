import AppKit

// Chamado com um comando (MacTray.app/Contents/MacOS/MacTray --toggle), o binario nao
// sobe outra copia do app: avisa a que ja esta rodando e sai. E o gancho para Atalhos,
// Raycast, Keyboard Maestro ou um simples script.
// `--login-item on|off` roda aqui mesmo, sem passar pela instancia que ja esta na barra:
// o SMAppService registra o bundle de quem chama, e e esse caminho que vale no login.
if let wanted = LoginItemArgument.fromArguments(CommandLine.arguments) {
    let ok = LoginItem.set(wanted)
    print(ok ? "login item: \(wanted ? "on" : "off")" : "login item: falhou")
    exit(ok ? 0 : 1)
}

// `--list` responde a pergunta "o app esta enxergando meus icones?" sem precisar abrir
// nada; `--render-panel` desenha a bandeja num PNG, para conferir o visual sem depender
// da barra de menus estar acessivel.
if CommandLine.arguments.contains("--list") {
    MainActor.assumeIsolated { Diagnostics.printItems() }
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--open"),
   index + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { Diagnostics.openItem(named: CommandLine.arguments[index + 1]) }
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--render-panel"),
   index + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { Diagnostics.renderPanel(to: CommandLine.arguments[index + 1]) }
    exit(0)
}

if let (command, argument) = RemoteCommand.withArgument(CommandLine.arguments) {
    RemoteCommand.send(command, argument: argument)
    exit(0)
}

if let command = RemoteCommand.fromArguments(CommandLine.arguments) {
    RemoteCommand.send(command)
    exit(0)
}

// LSUIElement no Info.plist ja tira o app do Dock; aqui garantimos o modo acessorio
// mesmo quando o binario roda solto, fora do bundle.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
