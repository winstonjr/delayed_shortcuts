import CoreFoundation
import CoreGraphics
import Foundation

final class ShortcutMonitor {
    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<ShortcutMonitor>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        return monitor.handle(type: type, event: event)
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcuts: [DelayedShortcut] = []
    private let triggerQueue = DispatchQueue(
        label: "com.local.DelayedShortcuts.triggerQueue",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private(set) var isRunning = false

    func updateShortcuts(_ shortcuts: [DelayedShortcut]) {
        self.shortcuts = shortcuts.filter(\.isValid)
    }

    func start(with shortcuts: [DelayedShortcut]? = nil) -> Bool {
        if let shortcuts {
            updateShortcuts(shortcuts)
        }

        guard PermissionManager.currentState().isReady else {
            return false
        }

        if eventTap == nil && !createEventTap() {
            return false
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isRunning = true
            return true
        }

        return false
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        isRunning = false
    }

    func invalidate() {
        stop()

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        self.runLoopSource = nil
        self.eventTap = nil
    }

    private func createEventTap() -> Bool {
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue)
            | (CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue)

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard isRunning && type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        guard event.getIntegerValueField(.eventSourceUserData) != EventSender.syntheticEventUserData else {
            return Unmanaged.passUnretained(event)
        }

        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection(.shortcutModifierMask)

        guard let shortcut = shortcuts.first(where: { $0.matches(keyCode: keyCode, flags: flags) }) else {
            return Unmanaged.passUnretained(event)
        }

        schedule(shortcut)
        return shortcut.consumeTrigger ? nil : Unmanaged.passUnretained(event)
    }

    private func schedule(_ shortcut: DelayedShortcut) {
        let outputs = shortcut.outputs
        let stepDelay = shortcut.outputStepDelayMilliseconds
        let deadline = DispatchTime.now() + .milliseconds(max(shortcut.delayMilliseconds, 0))

        triggerQueue.asyncAfter(deadline: deadline) {
            for (index, endpoint) in outputs.enumerated() {
                if index > 0 && stepDelay > 0 {
                    Thread.sleep(forTimeInterval: Double(stepDelay) / 1_000)
                }
                EventSender.send(endpoint, stepDelayMilliseconds: stepDelay)
            }
        }
    }
}
