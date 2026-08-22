import AppKit

// Chamado com um comando (MacTray.app/Contents/MacOS/MacTray --toggle), o binario nao
// sobe outra copia do app: avisa a que ja esta rodando e sai. E o gancho para Atalhos,
// Raycast, Keyboard Maestro ou um simples script.
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
