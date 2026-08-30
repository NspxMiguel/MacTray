import Foundation

/// Um registro em arquivo, porque `NSLog` de app acessório assinado ad-hoc não chega ao
/// log unificado do sistema — e defeito de barra de menus só aparece na barra de quem
/// está usando, onde não há depurador nenhum ligado.
///
/// Fica em `~/Library/Logs/MacTray.log` e é aparado quando passa de 256 KB: o app roda o
/// dia inteiro, e um log que cresce para sempre é um defeito novo, não uma ferramenta.
enum Log {
    private static let queue = DispatchQueue(label: "dev.nspx.MacTray.log")
    private static let maxBytes = 256 * 1024

    static var url: URL {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("MacTray.log")
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ message: String) {
        let line = "\(stamp.string(from: Date()))  \(message)\n"
        queue.async {
            let url = Log.url
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
            trimIfNeeded(url)
        }
    }

    private static func trimIfNeeded(_ url: URL) {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > maxBytes,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        // Fica com a metade mais recente: o começo de um log cheio nunca é o interessante.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let kept = lines.suffix(lines.count / 2).joined(separator: "\n")
        try? kept.write(to: url, atomically: true, encoding: .utf8)
    }
}
