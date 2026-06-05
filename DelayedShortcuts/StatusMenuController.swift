import Cocoa

final class StatusMenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let titleItem = NSMenuItem(title: "Delayed Shortcuts", action: nil, keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "State: Checking", action: nil, keyEquivalent: "")
    private let listeningItem = NSMenuItem(title: "Enable Listening", action: #selector(toggleListening), keyEquivalent: "")
    private let requestPermissionsItem = NSMenuItem(
        title: "Request Permissions",
        action: #selector(requestPermissions),
        keyEquivalent: ""
    )
    private let showShortcutsItem = NSMenuItem(
        title: "Show Configured Shortcuts",
        action: #selector(showConfiguredShortcuts),
        keyEquivalent: ""
    )
    private let shortcutsMenuItem = NSMenuItem(title: "Configured Shortcuts", action: nil, keyEquivalent: "")
    private let shortcutsSubmenu = NSMenu()
    private let openConfigItem = NSMenuItem(title: "Open Config File", action: #selector(openConfig), keyEquivalent: "")
    private let reloadConfigItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

    private var permissionState = PermissionState(
        accessibilityAllowed: false,
        inputMonitoringAllowed: false
    )
    private var listeningEnabled = false
    private var shortcuts: [DelayedShortcut] = []

    var onToggleListening: ((Bool) -> Void)?
    var onRequestPermissions: (() -> Void)?
    var onShowConfiguredShortcuts: (() -> Void)?
    var onOpenConfig: (() -> Void)?
    var onReloadConfig: (() -> Void)?

    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        refresh()
    }

    func setPermissionState(_ state: PermissionState) {
        permissionState = state
        refresh()
    }

    func setListening(_ enabled: Bool) {
        listeningEnabled = enabled
        refresh()
    }

    func setShortcuts(_ shortcuts: [DelayedShortcut]) {
        self.shortcuts = shortcuts
        rebuildShortcutsSubmenu()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Delayed Shortcuts") {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.title = " DS"
        } else {
            button.image = nil
            button.title = "DS"
        }
        button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        button.alignment = .center
        button.toolTip = "Delayed Shortcuts"
    }

    private func setupMenu() {
        titleItem.isEnabled = false
        stateItem.isEnabled = false

        listeningItem.target = self
        requestPermissionsItem.target = self
        showShortcutsItem.target = self
        openConfigItem.target = self
        reloadConfigItem.target = self
        quitItem.target = self
        shortcutsMenuItem.submenu = shortcutsSubmenu

        menu.addItem(titleItem)
        menu.addItem(stateItem)
        menu.addItem(.separator())
        menu.addItem(listeningItem)
        menu.addItem(requestPermissionsItem)
        menu.addItem(.separator())
        menu.addItem(showShortcutsItem)
        menu.addItem(shortcutsMenuItem)
        menu.addItem(.separator())
        menu.addItem(openConfigItem)
        menu.addItem(reloadConfigItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refresh() {
        stateItem.title = "State: \(permissionState.summary)"
        listeningItem.title = listeningEnabled ? "Disable Listening" : "Enable Listening"
        listeningItem.state = listeningEnabled ? .on : .off
        listeningItem.isEnabled = permissionState.isReady
        requestPermissionsItem.isHidden = permissionState.isReady

        if let button = statusItem.button {
            button.toolTip = listeningEnabled
                ? "Delayed Shortcuts is listening"
                : "Delayed Shortcuts is not listening"
        }
    }

    private func rebuildShortcutsSubmenu() {
        shortcutsSubmenu.removeAllItems()

        guard !shortcuts.isEmpty else {
            let emptyItem = NSMenuItem(title: "No shortcuts configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            shortcutsSubmenu.addItem(emptyItem)
            return
        }

        for shortcut in shortcuts {
            let enabledText = shortcut.enabled ? "On" : "Off"
            let title = "\(enabledText) \(shortcut.name): \(shortcut.trigger.displayText) => \(shortcut.outputDisplayText) (\(shortcut.delayDisplayText))"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            shortcutsSubmenu.addItem(item)
        }
    }

    @objc private func toggleListening() {
        onToggleListening?(!listeningEnabled)
    }

    @objc private func requestPermissions() {
        onRequestPermissions?()
    }

    @objc private func showConfiguredShortcuts() {
        onShowConfiguredShortcuts?()
    }

    @objc private func openConfig() {
        onOpenConfig?()
    }

    @objc private func reloadConfig() {
        onReloadConfig?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
