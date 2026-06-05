import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum ShortcutModifier: String, Codable, CaseIterable, Hashable {
    case command
    case control
    case option
    case shift

    var cgFlag: CGEventFlags {
        switch self {
        case .command:
            return .maskCommand
        case .control:
            return .maskControl
        case .option:
            return .maskAlternate
        case .shift:
            return .maskShift
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .command:
            return CGKeyCode(kVK_Command)
        case .control:
            return CGKeyCode(kVK_Control)
        case .option:
            return CGKeyCode(kVK_Option)
        case .shift:
            return CGKeyCode(kVK_Shift)
        }
    }

    var displayName: String {
        switch self {
        case .command:
            return "Cmd"
        case .control:
            return "Ctrl"
        case .option:
            return "Opt"
        case .shift:
            return "Shift"
        }
    }

    var sortOrder: Int {
        switch self {
        case .control:
            return 0
        case .option:
            return 1
        case .shift:
            return 2
        case .command:
            return 3
        }
    }
}

struct ShortcutEndpoint: Codable, Hashable {
    var key: String
    var modifiers: [ShortcutModifier]

    var normalizedKey: String {
        KeyLookup.normalized(key)
    }

    var keyCode: CGKeyCode? {
        KeyLookup.keyCode(for: key)
    }

    var cgFlags: CGEventFlags {
        modifiers.reduce(CGEventFlags()) { partialResult, modifier in
            var flags = partialResult
            flags.insert(modifier.cgFlag)
            return flags
        }
    }

    var displayText: String {
        let modifierParts = modifiers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.displayName)
        return (modifierParts + [KeyLookup.displayName(for: key)]).joined(separator: "+")
    }
}

struct DelayedShortcut: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var trigger: ShortcutEndpoint
    var outputs: [ShortcutEndpoint]
    var delayMilliseconds: Int
    var outputStepDelayMilliseconds: Int
    var enabled: Bool
    var consumeTrigger: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case trigger
        case outputs
        case legacyOutput = "output"
        case delayMilliseconds
        case outputStepDelayMilliseconds
        case enabled
        case consumeTrigger
    }

    init(
        id: String,
        name: String,
        trigger: ShortcutEndpoint,
        outputs: [ShortcutEndpoint],
        delayMilliseconds: Int,
        outputStepDelayMilliseconds: Int = 0,
        enabled: Bool = true,
        consumeTrigger: Bool = true
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.outputs = outputs
        self.delayMilliseconds = delayMilliseconds
        self.outputStepDelayMilliseconds = outputStepDelayMilliseconds
        self.enabled = enabled
        self.consumeTrigger = consumeTrigger
    }

    init(
        id: String,
        name: String,
        trigger: ShortcutEndpoint,
        output: ShortcutEndpoint,
        delayMilliseconds: Int,
        outputStepDelayMilliseconds: Int = 0,
        enabled: Bool = true,
        consumeTrigger: Bool = true
    ) {
        self.init(
            id: id,
            name: name,
            trigger: trigger,
            outputs: [output],
            delayMilliseconds: delayMilliseconds,
            outputStepDelayMilliseconds: outputStepDelayMilliseconds,
            enabled: enabled,
            consumeTrigger: consumeTrigger
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        trigger = try container.decode(ShortcutEndpoint.self, forKey: .trigger)

        if let outputsArray = try container.decodeIfPresent([ShortcutEndpoint].self, forKey: .outputs) {
            outputs = outputsArray
        } else if let single = try container.decodeIfPresent(ShortcutEndpoint.self, forKey: .legacyOutput) {
            outputs = [single]
        } else {
            outputs = []
        }

        delayMilliseconds = try container.decode(Int.self, forKey: .delayMilliseconds)
        outputStepDelayMilliseconds = try container.decodeIfPresent(
            Int.self,
            forKey: .outputStepDelayMilliseconds
        ) ?? 0
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        consumeTrigger = try container.decodeIfPresent(Bool.self, forKey: .consumeTrigger) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(outputs, forKey: .outputs)
        try container.encode(delayMilliseconds, forKey: .delayMilliseconds)
        try container.encode(outputStepDelayMilliseconds, forKey: .outputStepDelayMilliseconds)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(consumeTrigger, forKey: .consumeTrigger)
    }

    var isValid: Bool {
        trigger.keyCode != nil && !outputs.isEmpty && outputs.allSatisfy { $0.keyCode != nil }
    }

    func matches(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        enabled && trigger.keyCode == keyCode && trigger.cgFlags == flags
    }

    var outputDisplayText: String {
        outputs.map(\.displayText).joined(separator: " → ")
    }

    var delayDisplayText: String {
        switch (delayMilliseconds, outputStepDelayMilliseconds) {
        case (0, 0):
            return "0 ms"
        case (0, let stepDelay):
            return "\(stepDelay) ms between steps"
        case (let startDelay, 0):
            return "\(startDelay) ms before output"
        case (let startDelay, let stepDelay):
            return "\(startDelay) ms before, \(stepDelay) ms between steps"
        }
    }
}

extension DelayedShortcut {
    static let defaultShortcuts: [DelayedShortcut] = [
        DelayedShortcut(
            id: "hyper-bang-to-option-1",
            name: "Hyper ! to Option 1",
            trigger: ShortcutEndpoint(key: "!", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "1", modifiers: [.option]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-at-to-option-2",
            name: "Hyper @ to Option 2",
            trigger: ShortcutEndpoint(key: "@", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "2", modifiers: [.option]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-backslash-to-option-3",
            name: "Hyper Backslash to Option 3",
            trigger: ShortcutEndpoint(key: "\\", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "3", modifiers: [.option]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-dollar-to-option-q",
            name: "Hyper $ to Option Q",
            trigger: ShortcutEndpoint(key: "$", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "q", modifiers: [.option]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-percent-to-option-w",
            name: "Hyper % to Option W",
            trigger: ShortcutEndpoint(key: "%", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "w", modifiers: [.option]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-ampersand-to-option-e",
            name: "Hyper & to Option E",
            trigger: ShortcutEndpoint(key: "&", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "e", modifiers: [.option]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-asterisk-to-option-shift-l",
            name: "Hyper * to Option Shift L",
            trigger: ShortcutEndpoint(key: "*", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "l", modifiers: [.option, .shift]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        ),
        DelayedShortcut(
            id: "hyper-left-paren-to-option-shift-h",
            name: "Hyper ( to Option Shift H",
            trigger: ShortcutEndpoint(key: "(", modifiers: [.control, .option, .command, .shift]),
            output: ShortcutEndpoint(key: "h", modifiers: [.option, .shift]),
            delayMilliseconds: 0,
            outputStepDelayMilliseconds: 250
        )
    ]
}

extension CGEventFlags {
    static var shortcutModifierMask: CGEventFlags {
        [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    }
}

enum KeyLookup {
    private static let aliases: [String: String] = [
        "esc": "escape",
        "enter": "return",
        "minus": "-",
        "hyphen": "-",
        "equal": "=",
        "equals": "=",
        "spacebar": "space",
        "!": "1",
        "@": "2",
        "#": "3",
        "$": "4",
        "%": "5",
        "^": "6",
        "&": "7",
        "*": "8",
        "(": "9",
        ")": "0"
    ]

    private static let displayNames: [String: String] = [
        "return": "Return",
        "escape": "Esc",
        "tab": "Tab",
        "space": "Space",
        "delete": "Delete",
        "left": "Left",
        "right": "Right",
        "up": "Up",
        "down": "Down",
        "-": "Minus",
        "=": "Equals",
        "[": "Left Bracket",
        "]": "Right Bracket",
        "\\": "Backslash",
        ";": "Semicolon",
        "'": "Quote",
        ",": "Comma",
        ".": "Period",
        "/": "Slash",
        "`": "Grave",
        "!": "!",
        "@": "@",
        "#": "#",
        "$": "$",
        "%": "%",
        "^": "^",
        "&": "&",
        "*": "*",
        "(": "(",
        ")": ")"
    ]

    private static let keyCodes: [String: CGKeyCode] = [
        "a": CGKeyCode(kVK_ANSI_A),
        "s": CGKeyCode(kVK_ANSI_S),
        "d": CGKeyCode(kVK_ANSI_D),
        "f": CGKeyCode(kVK_ANSI_F),
        "h": CGKeyCode(kVK_ANSI_H),
        "g": CGKeyCode(kVK_ANSI_G),
        "z": CGKeyCode(kVK_ANSI_Z),
        "x": CGKeyCode(kVK_ANSI_X),
        "c": CGKeyCode(kVK_ANSI_C),
        "v": CGKeyCode(kVK_ANSI_V),
        "b": CGKeyCode(kVK_ANSI_B),
        "q": CGKeyCode(kVK_ANSI_Q),
        "w": CGKeyCode(kVK_ANSI_W),
        "e": CGKeyCode(kVK_ANSI_E),
        "r": CGKeyCode(kVK_ANSI_R),
        "y": CGKeyCode(kVK_ANSI_Y),
        "t": CGKeyCode(kVK_ANSI_T),
        "1": CGKeyCode(kVK_ANSI_1),
        "2": CGKeyCode(kVK_ANSI_2),
        "3": CGKeyCode(kVK_ANSI_3),
        "4": CGKeyCode(kVK_ANSI_4),
        "6": CGKeyCode(kVK_ANSI_6),
        "5": CGKeyCode(kVK_ANSI_5),
        "=": CGKeyCode(kVK_ANSI_Equal),
        "9": CGKeyCode(kVK_ANSI_9),
        "7": CGKeyCode(kVK_ANSI_7),
        "-": CGKeyCode(kVK_ANSI_Minus),
        "8": CGKeyCode(kVK_ANSI_8),
        "0": CGKeyCode(kVK_ANSI_0),
        "]": CGKeyCode(kVK_ANSI_RightBracket),
        "o": CGKeyCode(kVK_ANSI_O),
        "u": CGKeyCode(kVK_ANSI_U),
        "[": CGKeyCode(kVK_ANSI_LeftBracket),
        "i": CGKeyCode(kVK_ANSI_I),
        "p": CGKeyCode(kVK_ANSI_P),
        "return": CGKeyCode(kVK_Return),
        "l": CGKeyCode(kVK_ANSI_L),
        "j": CGKeyCode(kVK_ANSI_J),
        "'": CGKeyCode(kVK_ANSI_Quote),
        "k": CGKeyCode(kVK_ANSI_K),
        ";": CGKeyCode(kVK_ANSI_Semicolon),
        "\\": CGKeyCode(kVK_ANSI_Backslash),
        ",": CGKeyCode(kVK_ANSI_Comma),
        "/": CGKeyCode(kVK_ANSI_Slash),
        "n": CGKeyCode(kVK_ANSI_N),
        "m": CGKeyCode(kVK_ANSI_M),
        ".": CGKeyCode(kVK_ANSI_Period),
        "tab": CGKeyCode(kVK_Tab),
        "space": CGKeyCode(kVK_Space),
        "`": CGKeyCode(kVK_ANSI_Grave),
        "delete": CGKeyCode(kVK_Delete),
        "escape": CGKeyCode(kVK_Escape),
        "left": CGKeyCode(kVK_LeftArrow),
        "right": CGKeyCode(kVK_RightArrow),
        "down": CGKeyCode(kVK_DownArrow),
        "up": CGKeyCode(kVK_UpArrow),
        "f1": CGKeyCode(kVK_F1),
        "f2": CGKeyCode(kVK_F2),
        "f3": CGKeyCode(kVK_F3),
        "f4": CGKeyCode(kVK_F4),
        "f5": CGKeyCode(kVK_F5),
        "f6": CGKeyCode(kVK_F6),
        "f7": CGKeyCode(kVK_F7),
        "f8": CGKeyCode(kVK_F8),
        "f9": CGKeyCode(kVK_F9),
        "f10": CGKeyCode(kVK_F10),
        "f11": CGKeyCode(kVK_F11),
        "f12": CGKeyCode(kVK_F12)
    ]

    static func normalized(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return aliases[trimmed] ?? trimmed
    }

    static func keyCode(for key: String) -> CGKeyCode? {
        keyCodes[normalized(key)]
    }

    static func displayName(for key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let displayName = displayNames[trimmed] {
            return displayName
        }

        let normalizedKey = normalized(key)
        if let displayName = displayNames[normalizedKey] {
            return displayName
        }
        return normalizedKey.uppercased()
    }

    static var allKeys: [String] {
        Array(keyCodes.keys).sorted()
    }
}
