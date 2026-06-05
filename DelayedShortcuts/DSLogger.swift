import Foundation
import os

// Append-only log at ~/Library/Logs/DelayedShortcuts/shortcuts.log
// Rotates at 1 MB → renames to shortcuts.log.1 (keeps one backup).
// Readable in Console.app (subsystem: com.local.DelayedShortcuts) or tail -f the file.
final class DSLogger {
    static let shared = DSLogger()

    enum Category: String {
        case config   = "CONFIG "
        case trigger  = "TRIGGER"
        case output   = "OUTPUT "
        case state    = "STATE  "
    }

    private static let maxBytes: UInt64 = 1 * 1024 * 1024   // 1 MB per file
    private static let maxBackups: Int  = 4                 // + current = 5 files = 5 MB total

    private let osLog = OSLog(subsystem: "com.local.DelayedShortcuts", category: "shortcuts")
    private let writeQueue = DispatchQueue(label: "com.local.DelayedShortcuts.logger", qos: .utility)
    private var fileHandle: FileHandle?

    let logURL: URL = {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DelayedShortcuts", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("shortcuts.log")
    }()

    private func archiveURL(_ n: Int) -> URL {
        logURL.deletingPathExtension().appendingPathExtension("log.\(n)")
    }

    private init() {
        openFile()
    }

    // Call from any thread. Timestamp is captured immediately; file write is async.
    func log(_ category: Category, _ message: String) {
        let line = "[\(timestamp())] [\(category.rawValue)] \(message)"
        os_log("%{public}@", log: osLog, type: .info, line)
        let data = (line + "\n").data(using: .utf8)
        writeQueue.async { [weak self] in
            guard let self, let data else { return }
            self.rotateIfNeeded()
            self.fileHandle?.write(data)
        }
    }

    func logSection(_ title: String) {
        let data = ("\n──── \(title) ────\n").data(using: .utf8)
        writeQueue.async { [weak self] in
            guard let self, let data else { return }
            self.rotateIfNeeded()
            self.fileHandle?.write(data)
        }
    }

    // Must be called on writeQueue.
    private func rotateIfNeeded() {
        guard let size = fileHandle?.seekToEndOfFile(), size >= Self.maxBytes else { return }

        fileHandle?.closeFile()
        fileHandle = nil

        // Drop the oldest backup, then shift .3→.4, .2→.3, .1→.2, current→.1
        try? FileManager.default.removeItem(at: archiveURL(Self.maxBackups))
        for n in stride(from: Self.maxBackups - 1, through: 1, by: -1) {
            try? FileManager.default.moveItem(at: archiveURL(n), to: archiveURL(n + 1))
        }
        try? FileManager.default.moveItem(at: logURL, to: archiveURL(1))

        openFile()
        fileHandle?.write("──── log rotated (keeping \(Self.maxBackups) backups) ────\n".data(using: .utf8)!)
    }

    private func openFile() {
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: logURL)
        fileHandle?.seekToEndOfFile()
    }

    private func timestamp() -> String {
        var tv = timeval()
        gettimeofday(&tv, nil)
        let ms = tv.tv_usec / 1000
        var t = tv.tv_sec
        var tm = Darwin.tm()
        localtime_r(&t, &tm)
        return String(
            format: "%04d-%02d-%02d %02d:%02d:%02d.%03d",
            tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
            tm.tm_hour, tm.tm_min, tm.tm_sec, ms
        )
    }
}
