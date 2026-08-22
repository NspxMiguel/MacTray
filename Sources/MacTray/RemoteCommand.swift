import Foundation

/// Comandos aceitos na linha de comando e transportados por notificacao distribuida.
enum RemoteCommand: String, CaseIterable {
    case toggle
    case show
    case hide
    case showAll = "show-all"
    case panel
    case preferences
    case pin
    case unpin

    var notificationName: Notification.Name {
        Notification.Name("dev.nspx.MacTray.\(rawValue)")
    }

    static func fromArguments(_ arguments: [String]) -> RemoteCommand? {
        for argument in arguments.dropFirst() {
            guard argument.hasPrefix("--") else { continue }
            if let command = RemoteCommand(rawValue: String(argument.dropFirst(2))) {
                return command
            }
        }
        return nil
    }

    static func send(_ command: RemoteCommand, argument: String? = nil) {
        DistributedNotificationCenter.default().postNotificationName(
            command.notificationName, object: argument, userInfo: nil, deliverImmediately: true)
    }

    /// `--pin Docker` e `--unpin Docker` levam o nome do app junto.
    static func withArgument(_ arguments: [String]) -> (RemoteCommand, String)? {
        for (index, argument) in arguments.enumerated() where argument.hasPrefix("--") {
            guard let command = RemoteCommand(rawValue: String(argument.dropFirst(2))),
                  command == .pin || command == .unpin,
                  index + 1 < arguments.count else { continue }
            return (command, arguments[index + 1])
        }
        return nil
    }

    static var usage: String {
        "MacTray --" + RemoteCommand.allCases.map(\.rawValue).joined(separator: " | --")
    }
}


/// `--login-item on` / `--login-item off`.
enum LoginItemArgument {
    static func fromArguments(_ arguments: [String]) -> Bool? {
        guard let index = arguments.firstIndex(of: "--login-item"),
              index + 1 < arguments.count else { return nil }
        switch arguments[index + 1].lowercased() {
        case "on", "true", "1", "yes": return true
        case "off", "false", "0", "no": return false
        default: return nil
        }
    }
}
