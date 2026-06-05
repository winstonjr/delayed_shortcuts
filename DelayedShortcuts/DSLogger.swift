import Foundation
import os

// Append-only log at ~/Library/Logs/DelayedShortcuts/shortcuts.log
// Readable in Console.app (subsystem: com.local.DelayedShortcuts) or tail -f the file.
final class DSLogger {
    static let shared = DSLogger()

    enum Category: String {
        case config   = "CONFIG "
        case trigger  = "TRIGGER"
        case output   = "OUTPUT "
        case state    = "STATE  "
    }

    private let osLog = OSLog(subsystem: "com.local.DelayedShortcuts", category: "shortcuts")
    private let writeQueue = DispatchQueue(label: "com.local.DelayedShortcuts.logger", qos: .utility)
    private var fileHandle: FileHandle?

    let logURL: URL = {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DelayedShortcuts", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("shortcuts.log")
    }()

    private init() {
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: logURL)
        fileHandle?.seekToEndOfFile()
    }

    // Call from any thread. Timestamp is captured immediately; file write is async.
    func log(_ category: Category, _ message: String) {
        let line = "[\(timestamp())] [\(category.rawValue)] \(message)"
        os_log("%{public}@", log: osLog, type: .info, line)
        let data = (line + "\n").data(using: .utf8)
        writeQueue.async { [weak self] in
            if let data { self?.fileHandle?.write(data) }
        }
    }

    func logSection(_ title: String) {
        let line = "\n──── \(title) ────"
        let data = (line + "\n").data(using: .utf8)
        writeQueue.async { [weak self] in
            if let data { self?.fileHandle?.write(data) }
        }
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
