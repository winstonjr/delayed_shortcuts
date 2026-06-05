import Cocoa
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let listeningEnabledKey = "ListeningEnabled"
    private static let singleInstanceLockPath = "/tmp/com.local.DelayedShortcuts.pid"

    private let shortcutStore = ShortcutStore()
    private let monitor = ShortcutMonitor()
    private let shortcutListWindowController = ShortcutListWindowController()

    private var menuController: StatusMenuController?
    private var permissionTimer: Timer?
    private var ownsSingleInstanceLock = false
    private var shortcuts: [DelayedShortcut] = []
    private var didShowInitialPermissionHelp = false

    private var wantsListening: Bool = {
        if UserDefaults.standard.object(forKey: listeningEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: listeningEnabledKey)
    }()

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireSingleInstanceLock() else {
            exit(EXIT_SUCCESS)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        shortcuts = shortcutStore.loadOrInstallDefaults()
        monitor.updateShortcuts(shortcuts)

        let menuController = StatusMenuController()
        self.menuController = menuController
        wireMenuCallbacks(menuController)
        menuController.setShortcuts(shortcuts)
        shortcutListWindowController.update(shortcuts: shortcuts)
        shortcutListWindowController.onSave = { [weak self] updated in
            self?.applyShortcuts(updated)
        }

        refreshReadiness()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.requestInitialPermissionsIfNeeded()
            self?.refreshReadiness()
        }

        permissionTimer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            self?.refreshReadiness()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        monitor.invalidate()
        releaseSingleInstanceLock()
    }

    private func acquireSingleInstanceLock() -> Bool {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        while true {
            let fileDescriptor = open(Self.singleInstanceLockPath, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
            if fileDescriptor != -1 {
                writeLockOwner(fileDescriptor, processIdentifier: currentProcessIdentifier)
                close(fileDescriptor)
                ownsSingleInstanceLock = true
                return true
            }

            guard errno == EEXIST else {
                return false
            }

            guard let lockOwnerProcessIdentifier = readLockOwnerProcessIdentifier() else {
                unlink(Self.singleInstanceLockPath)
                continue
            }

            guard !lockOwnerIsRunning(lockOwnerProcessIdentifier) else {
                return false
            }

            removeStaleLock(ownedBy: lockOwnerProcessIdentifier)
        }
    }

    private func lockOwnerIsRunning(_ processIdentifier: pid_t) -> Bool {
        guard processIdentifier > 0 else {
            return false
        }

        if kill(processIdentifier, 0) == -1, errno != EPERM {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return true
        }

        guard let runningApplication = NSRunningApplication(processIdentifier: processIdentifier) else {
            return false
        }

        return runningApplication.bundleIdentifier == bundleIdentifier && !runningApplication.isTerminated
    }

    private func writeLockOwner(_ fileDescriptor: CInt, processIdentifier: pid_t) {
        let lockContents = "\(processIdentifier)\n"
        lockContents.withCString { pointer in
            _ = write(fileDescriptor, pointer, strlen(pointer))
        }
    }

    private func readLockOwnerProcessIdentifier() -> pid_t? {
        guard let lockContents = try? String(contentsOfFile: Self.singleInstanceLockPath, encoding: .utf8) else {
            return nil
        }

        return pid_t(lockContents.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func removeStaleLock(ownedBy processIdentifier: pid_t) {
        guard readLockOwnerProcessIdentifier() == processIdentifier else {
            return
        }

        unlink(Self.singleInstanceLockPath)
    }

    private func releaseSingleInstanceLock() {
        guard ownsSingleInstanceLock else {
            return
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard readLockOwnerProcessIdentifier() == currentProcessIdentifier else {
            return
        }

        unlink(Self.singleInstanceLockPath)
        ownsSingleInstanceLock = false
    }

    private func wireMenuCallbacks(_ menuController: StatusMenuController) {
        menuController.onToggleListening = { [weak self] enabled in
            self?.setListening(enabled)
        }

        menuController.onRequestPermissions = { [weak self] in
            self?.requestPermissions()
        }

        menuController.onShowConfiguredShortcuts = { [weak self] in
            self?.showConfiguredShortcuts()
        }

        menuController.onOpenConfig = { [weak self] in
            self?.openConfigFile()
        }

        menuController.onReloadConfig = { [weak self] in
            self?.reloadShortcuts()
        }
    }

    private func requestInitialPermissionsIfNeeded() {
        guard !isRunningTests else { return }
        let state = PermissionManager.currentState()
        guard !state.isReady else {
            return
        }

        PermissionManager.requestPermissions()
        showPermissionHelpIfNeeded(force: false)
    }

    private func requestPermissions() {
        PermissionManager.requestPermissions()
        showPermissionHelpIfNeeded(force: true)
        refreshReadiness()
    }

    private func setListening(_ enabled: Bool) {
        wantsListening = enabled
        UserDefaults.standard.set(enabled, forKey: Self.listeningEnabledKey)

        if enabled, !PermissionManager.currentState().isReady {
            PermissionManager.requestPermissions()
            showPermissionHelpIfNeeded(force: true)
        }

        refreshReadiness()
    }

    private func refreshReadiness() {
        let permissionState = PermissionManager.currentState()
        menuController?.setPermissionState(permissionState)

        if permissionState.isReady {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }

        guard permissionState.isReady, wantsListening else {
            monitor.stop()
            menuController?.setListening(false)
            return
        }

        monitor.updateShortcuts(shortcuts)
        let started = monitor.start()
        menuController?.setListening(started)
    }

    private func reloadShortcuts() {
        do {
            shortcuts = try shortcutStore.loadShortcuts()
            monitor.updateShortcuts(shortcuts)
            menuController?.setShortcuts(shortcuts)
            shortcutListWindowController.update(shortcuts: shortcuts)
            refreshReadiness()
        } catch {
            showAlert(
                message: "Could not reload shortcuts",
                informativeText: "The config file has invalid JSON or unsupported shortcut data. The current in-memory shortcuts were kept.\n\n\(error.localizedDescription)"
            )
        }
    }

    func applyShortcuts(_ updated: [DelayedShortcut]) {
        do {
            try shortcutStore.save(updated)
            shortcuts = updated
            monitor.updateShortcuts(shortcuts)
            menuController?.setShortcuts(shortcuts)
            shortcutListWindowController.update(shortcuts: shortcuts)
            refreshReadiness()
        } catch {
            showAlert(
                message: "Could not save shortcuts",
                informativeText: error.localizedDescription
            )
        }
    }

    private func showConfiguredShortcuts() {
        shortcutListWindowController.update(shortcuts: shortcuts)
        shortcutListWindowController.showWindow(nil)
    }

    private func openConfigFile() {
        do {
            try shortcutStore.ensureConfigExists()
            NSWorkspace.shared.activateFileViewerSelecting([shortcutStore.configURL])
        } catch {
            showAlert(
                message: "Could not open config file",
                informativeText: error.localizedDescription
            )
        }
    }

    private func showPermissionHelpIfNeeded(force: Bool) {
        guard force || !didShowInitialPermissionHelp else {
            return
        }

        didShowInitialPermissionHelp = true
        let state = PermissionManager.currentState()
        guard !state.isReady else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [
            .activateAllWindows,
            .activateIgnoringOtherApps
        ])

        let alert = NSAlert()
        alert.messageText = "Delayed Shortcuts needs permission"
        alert.informativeText = "Allow Accessibility and Input Monitoring in System Settings. The app stays Not Ready until both are allowed."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Later")
        alert.window.level = .floating
        alert.window.collectionBehavior = [.canJoinAllSpaces]

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            PermissionManager.openAccessibilitySettings()
        case .alertSecondButtonReturn:
            PermissionManager.openInputMonitoringSettings()
        default:
            break
        }
    }

    private func showAlert(message: String, informativeText: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
