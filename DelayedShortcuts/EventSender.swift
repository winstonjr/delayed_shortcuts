import CoreGraphics
import Foundation

enum EventSender {
    static let syntheticEventUserData: Int64 = 0x44534344454C4159

    static func send(_ endpoint: ShortcutEndpoint, stepDelayMilliseconds: Int = 0, label: String = "1/1") {
        guard let keyCode = endpoint.keyCode else {
            DSLogger.shared.log(.output, "  [\(label)] SKIPPED \(endpoint.displayText) — key '\(endpoint.key)' has no keyCode")
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let modifiers = endpoint.modifiers.sorted { $0.sortOrder < $1.sortOrder }
        var activeFlags = CGEventFlags()

        DSLogger.shared.log(.output, "  [\(label)] SEND \(endpoint.displayText)  step=\(stepDelayMilliseconds)ms")

        for modifier in modifiers {
            activeFlags.insert(modifier.cgFlag)
            DSLogger.shared.log(.output, "  [\(label)]   ↓ \(modifier.displayName) (keyCode \(modifier.keyCode))")
            post(keyCode: modifier.keyCode, keyDown: true, flags: activeFlags, source: source)
            wait(milliseconds: stepDelayMilliseconds)
        }

        DSLogger.shared.log(.output, "  [\(label)]   ↓ \(KeyLookup.displayName(for: endpoint.key)) (keyCode \(keyCode)) [main key]")
        post(keyCode: keyCode, keyDown: true, flags: endpoint.cgFlags, source: source)
        DSLogger.shared.log(.output, "  [\(label)]   ↑ \(KeyLookup.displayName(for: endpoint.key)) released [main key]")
        post(keyCode: keyCode, keyDown: false, flags: endpoint.cgFlags, source: source)

        for modifier in modifiers.reversed() {
            activeFlags.remove(modifier.cgFlag)
            DSLogger.shared.log(.output, "  [\(label)]   ↑ \(modifier.displayName) released")
            post(keyCode: modifier.keyCode, keyDown: false, flags: activeFlags, source: source)
        }
    }

    private static func wait(milliseconds: Int) {
        guard milliseconds > 0 else { return }
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1_000)
    }

    private static func post(
        keyCode: CGKeyCode,
        keyDown: Bool,
        flags: CGEventFlags,
        source: CGEventSource?
    ) {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: keyDown
        ) else { return }

        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: syntheticEventUserData)
        event.post(tap: .cghidEventTap)
    }
}
