import XCTest
@testable import DelayedShortcuts

final class ShortcutStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: ShortcutStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DelayedShortcutsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ShortcutStore(directoryURL: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testWriteAndLoadRoundTrip() throws {
        let shortcuts = [
            DelayedShortcut(
                id: "test",
                name: "Test",
                trigger: ShortcutEndpoint(key: "a", modifiers: [.command]),
                output: ShortcutEndpoint(key: "b", modifiers: []),
                delayMilliseconds: 100
            )
        ]
        try store.save(shortcuts)
        let loaded = try store.loadShortcuts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "test")
        XCTAssertEqual(loaded[0].name, "Test")
        XCTAssertEqual(loaded[0].delayMilliseconds, 100)
    }

    func testLoadOrInstallDefaultsWritesConfigOnFirstLaunch() {
        // No file exists yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))
        let shortcuts = store.loadOrInstallDefaults()
        XCTAssertFalse(shortcuts.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testVersionMigrationPreservesUserShortcuts() throws {
        let v1JSON = """
        {
          "version": 1,
          "shortcuts": [
            {
              "id": "user-custom",
              "name": "My Custom Shortcut",
              "trigger": {"key": "a", "modifiers": ["command"]},
              "output": {"key": "z", "modifiers": ["shift"]},
              "delayMilliseconds": 300,
              "consumeTrigger": true,
              "enabled": true
            }
          ]
        }
        """
        try Data(v1JSON.utf8).write(to: store.configURL)

        let loaded = try store.loadShortcuts()
        XCTAssertEqual(loaded.count, 1, "Migration should preserve the 1 user shortcut")
        XCTAssertEqual(loaded[0].id, "user-custom")
        XCTAssertEqual(loaded[0].name, "My Custom Shortcut")
        XCTAssertEqual(loaded[0].delayMilliseconds, 300)

        // Config on disk should now be version 2
        let data = try Data(contentsOf: store.configURL)
        let config = try JSONDecoder().decode(ShortcutConfig.self, from: data)
        XCTAssertEqual(config.version, 2)
    }

    func testSaveWritesValidJSON() throws {
        let shortcuts = DelayedShortcut.defaultShortcuts
        try store.save(shortcuts)

        let data = try Data(contentsOf: store.configURL)
        let config = try JSONDecoder().decode(ShortcutConfig.self, from: data)
        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.shortcuts.count, shortcuts.count)
    }

    func testLoadShortcutsFromCurrentVersionConfig() throws {
        try store.save(DelayedShortcut.defaultShortcuts)
        let loaded = try store.loadShortcuts()
        XCTAssertEqual(loaded.count, DelayedShortcut.defaultShortcuts.count)
    }

    func testLoadOrInstallDefaultsReturnsDefaultsOnCorruptJSON() throws {
        try "not valid json".data(using: .utf8)!.write(to: store.configURL)
        let loaded = store.loadOrInstallDefaults()
        XCTAssertEqual(loaded.count, DelayedShortcut.defaultShortcuts.count)
        XCTAssertNotNil(store.lastLoadError)
    }
}
