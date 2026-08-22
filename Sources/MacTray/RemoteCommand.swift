import Foundation

/// Comandos aceitos na linha de comando e transportados por notificacao distribuida.
enum RemoteCommand: String, CaseIterable {
    case toggle
    case show
    case hide
    case showAll = "show-all"
    case preferences

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

    static func send(_ command: RemoteCommand) {
        DistributedNotificationCenter.default().postNotificationName(
            command.notificationName, object: nil, userInfo: nil, deliverImmediately: true)
    }

    static var usage: String {
        "MacTray --" + RemoteCommand.allCases.map(\.rawValue).joined(separator: " | --")
    }
}
