import Foundation

/// Comandos aceitos na linha de comando e transportados por notificacao distribuida.
public enum RemoteCommand: String, CaseIterable {
    case toggle
    case show
    case hide
    case showAll = "show-all"
    case panel
    case preferences
    case pin
    case unpin
    case dock

    public var notificationName: Notification.Name {
        Notification.Name("dev.nspx.MacTray.\(rawValue)")
    }

    public static func fromArguments(_ arguments: [String]) -> RemoteCommand? {
        for argument in arguments.dropFirst() {
            guard argument.hasPrefix("--") else { continue }
            if let command = RemoteCommand(rawValue: String(argument.dropFirst(2))) {
                return command
            }
        }
        return nil
    }

    public static func send(_ command: RemoteCommand, argument: String? = nil) {
        DistributedNotificationCenter.default().postNotificationName(
            command.notificationName, object: argument, userInfo: nil, deliverImmediately: true)
    }

    /// Comandos que levam um argumento junto: `--pin Docker`, `--dock on`.
    private static let takesArgument: Set<RemoteCommand> = [.pin, .unpin, .dock]

    public static func withArgument(_ arguments: [String]) -> (RemoteCommand, String)? {
        for (index, argument) in arguments.enumerated() where argument.hasPrefix("--") {
            guard let command = RemoteCommand(rawValue: String(argument.dropFirst(2))),
                  takesArgument.contains(command),
                  index + 1 < arguments.count else { continue }
            return (command, arguments[index + 1])
        }
        return nil
    }

    public static var usage: String {
        "MacTray --" + RemoteCommand.allCases.map(\.rawValue).joined(separator: " | --")
    }
}


/// `--login-item on` / `--login-item off`.
public enum LoginItemArgument {
    public static func fromArguments(_ arguments: [String]) -> Bool? {
        guard let index = arguments.firstIndex(of: "--login-item"),
              index + 1 < arguments.count else { return nil }
        return value(arguments[index + 1])
    }

    /// `on` / `off` e os sinônimos que a gente sempre acaba digitando.
    public static func value(_ text: String?) -> Bool? {
        switch text?.lowercased() {
        case "on", "true", "1", "yes": return true
        case "off", "false", "0", "no": return false
        default: return nil
        }
    }
}
