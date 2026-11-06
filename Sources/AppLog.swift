import Foundation

enum AppLog {
    private static let queue = DispatchQueue(label: "local.dmc3.patch.log")
    static func write(_ message: String) {
        queue.sync {
            do {
                let fm = FileManager.default; let directory = Paths.project.appendingPathComponent("reports")
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
                let log = directory.appendingPathComponent("app.log")
                if let size = try? log.resourceValues(forKeys: [.fileSizeKey]).fileSize, size >= 1_048_576 {
                    let previous = directory.appendingPathComponent("app-previous.log")
                    if fm.fileExists(atPath: previous.path) { try fm.removeItem(at: previous) }
                    try fm.moveItem(at: log, to: previous)
                }
                if !fm.fileExists(atPath: log.path) { fm.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
                let file = try FileHandle(forWritingTo: log); defer { try? file.close() }
                try file.seekToEnd()
                let entry = ISO8601DateFormatter().string(from: Date()) + "  " + String(message.prefix(20_000)) + "\n"
                try file.write(contentsOf: Data(entry.utf8))
            } catch { /* The UI still displays errors if the log cannot be written. */ }
        }
    }
}
