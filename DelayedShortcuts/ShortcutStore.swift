import Foundation

struct ShortcutConfig: Codable {
    var version: Int
    var shortcuts: [DelayedShortcut]
}

final class ShortcutStore {
    private static let currentConfigVersion = 2
    private let appDirectoryName = "DelayedShortcuts"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()
    private(set) var lastLoadError: Error?

    private let overrideDirectoryURL: URL?

    init(directoryURL: URL? = nil) {
        self.overrideDirectoryURL = directoryURL
    }

    var configURL: URL {
        if let overrideDirectoryURL {
            return overrideDirectoryURL.appendingPathComponent("shortcuts.json")
        }
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupport
            .appendingPathComponent(appDirectoryName, isDirectory: true)
            .appendingPathComponent("shortcuts.json")
    }

    func loadOrInstallDefaults() -> [DelayedShortcut] {
        do {
            let shortcuts = try loadShortcuts()
            lastLoadError = nil
            return shortcuts
        } catch {
            lastLoadError = error
            return DelayedShortcut.defaultShortcuts
        }
    }

    func loadShortcuts() throws -> [DelayedShortcut] {
        try ensureConfigExists()
        let data = try Data(contentsOf: configURL)
        let config = try decoder.decode(ShortcutConfig.self, from: data)

        if config.version < Self.currentConfigVersion {
            // Preserve user shortcuts — just bump the version on disk
            let upgraded = ShortcutConfig(version: Self.currentConfigVersion, shortcuts: config.shortcuts)
            try? encoder.encode(upgraded).write(to: configURL, options: .atomic)
            return config.shortcuts
        }

        return config.shortcuts
    }

    func save(_ shortcuts: [DelayedShortcut]) throws {
        try ensureConfigExists()
        let config = ShortcutConfig(version: Self.currentConfigVersion, shortcuts: shortcuts)
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func ensureConfigExists() throws {
        let directoryURL = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        guard !FileManager.default.fileExists(atPath: configURL.path) else {
            return
        }

        try writeDefaultConfig()
    }

    func writeDefaultConfig() throws {
        let config = ShortcutConfig(
            version: Self.currentConfigVersion,
            shortcuts: DelayedShortcut.defaultShortcuts
        )
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }
}
