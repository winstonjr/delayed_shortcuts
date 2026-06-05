import ApplicationServices
import Cocoa
import IOKit.hid

struct PermissionState: Equatable {
    var accessibilityAllowed: Bool
    var inputMonitoringAllowed: Bool

    var isReady: Bool {
        accessibilityAllowed && inputMonitoringAllowed
    }

    var summary: String {
        switch (accessibilityAllowed, inputMonitoringAllowed) {
        case (true, true):
            return "Ready"
        case (false, false):
            return "Needs Accessibility and Input Monitoring"
        case (false, true):
            return "Needs Accessibility"
        case (true, false):
            return "Needs Input Monitoring"
        }
    }
}

enum PermissionManager {
    static func currentState() -> PermissionState {
        let accessibilityAllowed = AXIsProcessTrusted()
        let inputMonitoringAllowed: Bool

        if #available(macOS 10.15, *) {
            inputMonitoringAllowed = accessibilityAllowed
                || CGPreflightListenEventAccess()
                || IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        } else {
            inputMonitoringAllowed = true
        }

        return PermissionState(
            accessibilityAllowed: accessibilityAllowed,
            inputMonitoringAllowed: inputMonitoringAllowed
        )
    }

    @discardableResult
    static func requestPermissions() -> PermissionState {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if #available(macOS 10.15, *) {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            _ = CGRequestListenEventAccess()
            registerInputMonitoringNeed()
        }

        return currentState()
    }

    static func openAccessibilitySettings() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openPrivacyPane(anchor: "Privacy_ListenEvent")
    }

    private static func openPrivacyPane(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @available(macOS 10.15, *)
    private static func registerInputMonitoringNeed() {
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in
                Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            return
        }

        CFMachPortInvalidate(eventTap)
    }
}
