import Foundation
import ServiceManagement

/// Abrir junto com o sistema. SMAppService so funciona com o app dentro de um bundle
/// assinado; quando falha (binario solto, assinatura ad-hoc recusada) caimos num
/// LaunchAgent escrito na mao, que e o que o proprio macOS usava antes.
enum LoginItem {

    static var isEnabled: Bool {
        if #available(macOS 13.0, *), Bundle.main.bundleIdentifier != nil {
            if SMAppService.mainApp.status == .enabled { return true }
        }
        return FileManager.default.fileExists(atPath: agentPath)
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *), Bundle.main.bundleIdentifier != nil {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                removeLegacyAgent()
                return true
            } catch {
                NSLog("MacTray: SMAppService falhou (%@), usando LaunchAgent", "\(error)")
            }
        }
        return enabled ? writeLegacyAgent() : removeLegacyAgent()
    }

    // MARK: - LaunchAgent de reserva

    private static let agentLabel = "dev.nspx.MacTray.login"

    private static var agentPath: String {
        (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    @discardableResult
    private static func writeLegacyAgent() -> Bool {
        let executable = Bundle.main.bundlePath.hasSuffix(".app")
            ? Bundle.main.bundlePath
            : CommandLine.arguments[0]
        let args: [String] = executable.hasSuffix(".app")
            ? ["/usr/bin/open", "-a", executable]
            : [executable]
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": args,
            "RunAtLoad": true,
        ]
        do {
            let dir = (agentPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: agentPath))
            return true
        } catch {
            NSLog("MacTray: nao consegui escrever o LaunchAgent: %@", "\(error)")
            return false
        }
    }

    @discardableResult
    private static func removeLegacyAgent() -> Bool {
        guard FileManager.default.fileExists(atPath: agentPath) else { return true }
        do {
            try FileManager.default.removeItem(atPath: agentPath)
            return true
        } catch {
            return false
        }
    }
}
