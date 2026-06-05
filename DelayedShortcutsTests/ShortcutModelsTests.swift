import XCTest
@testable import DelayedShortcuts

final class ShortcutModelsTests: XCTestCase {

    // MARK: KeyLookup

    func testKeyLookupNormalizesCase() {
        XCTAssertEqual(KeyLookup.normalized("A"), "a")
        XCTAssertEqual(KeyLookup.normalized("  B  "), "b")
    }

    func testKeyLookupAliases() {
        XCTAssertEqual(KeyLookup.normalized("esc"), "escape")
        XCTAssertEqual(KeyLookup.normalized("enter"), "return")
        XCTAssertEqual(KeyLookup.normalized("minus"), "-")
        XCTAssertEqual(KeyLookup.normalized("!"), "1")
        XCTAssertEqual(KeyLookup.normalized("@"), "2")
        XCTAssertEqual(KeyLookup.normalized("("), "9")
        XCTAssertEqual(KeyLookup.normalized(")"), "0")
    }

    func testKeyLookupKnownKeyCodes() {
        XCTAssertNotNil(KeyLookup.keyCode(for: "a"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "1"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "return"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "escape"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "f1"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "f12"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "tab"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "space"))
    }

    func testKeyLookupAliasResolvesToKeyCode() {
        // "!" aliases to "1" which has a key code
        XCTAssertNotNil(KeyLookup.keyCode(for: "!"))
        XCTAssertNotNil(KeyLookup.keyCode(for: "enter"))
    }

    func testKeyLookupUnknownKeyReturnsNil() {
        XCTAssertNil(KeyLookup.keyCode(for: "notakey"))
        XCTAssertNil(KeyLookup.keyCode(for: ""))
    }

    func testKeyLookupDisplayName() {
        XCTAssertEqual(KeyLookup.displayName(for: "return"), "Return")
        XCTAssertEqual(KeyLookup.displayName(for: "escape"), "Esc")
        XCTAssertEqual(KeyLookup.displayName(for: "tab"), "Tab")
        XCTAssertEqual(KeyLookup.displayName(for: "-"), "Minus")
        XCTAssertEqual(KeyLookup.displayName(for: "a"), "A")
    }

    // MARK: ShortcutEndpoint

    func testEndpointCGFlags() {
        let endpoint = ShortcutEndpoint(key: "a", modifiers: [.command, .shift])
        let flags = endpoint.cgFlags
        XCTAssertTrue(flags.contains(.maskCommand))
        XCTAssertTrue(flags.contains(.maskShift))
        XCTAssertFalse(flags.contains(.maskControl))
        XCTAssertFalse(flags.contains(.maskAlternate))
    }

    func testEndpointDisplayTextOrdering() {
        let endpoint = ShortcutEndpoint(key: "a", modifiers: [.command, .control, .option, .shift])
        let text = endpoint.displayText
        // Control should come first (sortOrder 0), then Option (1), Shift (2), Command (3)
        let ctrlIdx = text.range(of: "Ctrl")!.lowerBound
        let optIdx = text.range(of: "Opt")!.lowerBound
        let shiftIdx = text.range(of: "Shift")!.lowerBound
        let cmdIdx = text.range(of: "Cmd")!.lowerBound
        XCTAssertLessThan(ctrlIdx, optIdx)
        XCTAssertLessThan(optIdx, shiftIdx)
        XCTAssertLessThan(shiftIdx, cmdIdx)
    }

    func testEndpointKeyCodeLookup() {
        XCTAssertNotNil(ShortcutEndpoint(key: "a", modifiers: []).keyCode)
        XCTAssertNil(ShortcutEndpoint(key: "notakey", modifiers: []).keyCode)
    }

    // MARK: DelayedShortcut – isValid

    func testIsValidRequiresKnownTriggerKey() {
        let valid = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: []),
            output: ShortcutEndpoint(key: "b", modifiers: []),
            delayMilliseconds: 0
        )
        XCTAssertTrue(valid.isValid)
    }

    func testIsValidFailsOnUnknownTrigger() {
        let invalid = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "zzzunknown", modifiers: []),
            output: ShortcutEndpoint(key: "b", modifiers: []),
            delayMilliseconds: 0
        )
        XCTAssertFalse(invalid.isValid)
    }

    func testIsValidFailsOnEmptyOutputs() {
        let invalid = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: []),
            outputs: [],
            delayMilliseconds: 0
        )
        XCTAssertFalse(invalid.isValid)
    }

    func testIsValidMultipleOutputsAllMustBeValid() {
        let shortcut = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: []),
            outputs: [
                ShortcutEndpoint(key: "b", modifiers: []),
                ShortcutEndpoint(key: "zzzbad", modifiers: [])
            ],
            delayMilliseconds: 0
        )
        XCTAssertFalse(shortcut.isValid)
    }

    // MARK: DelayedShortcut – matches

    func testMatchesReturnsTrueOnExactKeyCodeAndFlags() throws {
        let shortcut = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: [.command]),
            output: ShortcutEndpoint(key: "b", modifiers: []),
            delayMilliseconds: 0
        )
        let keyCode = try XCTUnwrap(shortcut.trigger.keyCode)
        XCTAssertTrue(shortcut.matches(keyCode: keyCode, flags: .maskCommand))
    }

    func testMatchesReturnsFalseOnWrongFlags() throws {
        let shortcut = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: [.command]),
            output: ShortcutEndpoint(key: "b", modifiers: []),
            delayMilliseconds: 0
        )
        let keyCode = try XCTUnwrap(shortcut.trigger.keyCode)
        XCTAssertFalse(shortcut.matches(keyCode: keyCode, flags: .maskShift))
    }

    func testMatchesReturnsFalseWhenDisabled() throws {
        let shortcut = DelayedShortcut(
            id: "x",
            name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: [.command]),
            output: ShortcutEndpoint(key: "b", modifiers: []),
            delayMilliseconds: 0,
            enabled: false
        )
        let keyCode = try XCTUnwrap(shortcut.trigger.keyCode)
        XCTAssertFalse(shortcut.matches(keyCode: keyCode, flags: .maskCommand))
    }

    // MARK: DelayedShortcut – display

    func testDelayDisplayTextVariants() {
        let zero = makeShortcut(delay: 0, stepDelay: 0)
        XCTAssertEqual(zero.delayDisplayText, "0 ms")

        let startOnly = makeShortcut(delay: 100, stepDelay: 0)
        XCTAssertTrue(startOnly.delayDisplayText.contains("100"))
        XCTAssertTrue(startOnly.delayDisplayText.contains("before"))

        let stepOnly = makeShortcut(delay: 0, stepDelay: 50)
        XCTAssertTrue(stepOnly.delayDisplayText.contains("50"))
        XCTAssertTrue(stepOnly.delayDisplayText.contains("between"))

        let both = makeShortcut(delay: 100, stepDelay: 50)
        XCTAssertTrue(both.delayDisplayText.contains("100"))
        XCTAssertTrue(both.delayDisplayText.contains("50"))
    }

    func testOutputDisplayTextSingleOutput() {
        let shortcut = DelayedShortcut(
            id: "x", name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: []),
            output: ShortcutEndpoint(key: "b", modifiers: [.command]),
            delayMilliseconds: 0
        )
        XCTAssertEqual(shortcut.outputDisplayText, "Cmd+B")
    }

    func testOutputDisplayTextMultipleOutputs() {
        let shortcut = DelayedShortcut(
            id: "x", name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: []),
            outputs: [
                ShortcutEndpoint(key: "b", modifiers: [.command]),
                ShortcutEndpoint(key: "c", modifiers: [.shift])
            ],
            delayMilliseconds: 0
        )
        XCTAssertTrue(shortcut.outputDisplayText.contains("→"))
        XCTAssertTrue(shortcut.outputDisplayText.contains("Cmd+B"))
        XCTAssertTrue(shortcut.outputDisplayText.contains("Shift+C"))
    }

    // MARK: JSON encode / decode

    func testRoundTripWithOutputsArray() throws {
        let original = DelayedShortcut(
            id: "test-id",
            name: "Test",
            trigger: ShortcutEndpoint(key: "a", modifiers: [.command]),
            outputs: [
                ShortcutEndpoint(key: "b", modifiers: [.shift]),
                ShortcutEndpoint(key: "c", modifiers: [])
            ],
            delayMilliseconds: 100,
            outputStepDelayMilliseconds: 50,
            enabled: false,
            consumeTrigger: false
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DelayedShortcut.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.outputs.count, 2)
        XCTAssertEqual(decoded.delayMilliseconds, 100)
        XCTAssertEqual(decoded.outputStepDelayMilliseconds, 50)
        XCTAssertFalse(decoded.enabled)
        XCTAssertFalse(decoded.consumeTrigger)
    }

    func testDecodesLegacySingleOutputField() throws {
        let json = """
        {
          "id": "legacy",
          "name": "Legacy",
          "trigger": {"key": "a", "modifiers": ["command"]},
          "output": {"key": "b", "modifiers": ["shift"]},
          "delayMilliseconds": 250
        }
        """
        let decoded = try JSONDecoder().decode(
            DelayedShortcut.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(decoded.outputs.count, 1)
        XCTAssertEqual(decoded.outputs[0].key, "b")
        XCTAssertEqual(decoded.outputs[0].modifiers, [.shift])
    }

    func testDecodesWithMissingOptionalFields() throws {
        let json = """
        {
          "id": "minimal",
          "name": "Minimal",
          "trigger": {"key": "a", "modifiers": []},
          "outputs": [{"key": "b", "modifiers": []}],
          "delayMilliseconds": 0
        }
        """
        let decoded = try JSONDecoder().decode(
            DelayedShortcut.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(decoded.outputStepDelayMilliseconds, 0)
        XCTAssertTrue(decoded.enabled)
        XCTAssertTrue(decoded.consumeTrigger)
    }

    func testDefaultShortcutsAreAllValid() {
        for shortcut in DelayedShortcut.defaultShortcuts {
            XCTAssertTrue(shortcut.isValid, "\(shortcut.name) is not valid")
        }
    }

    // MARK: Helpers

    private func makeShortcut(delay: Int, stepDelay: Int) -> DelayedShortcut {
        DelayedShortcut(
            id: "x", name: "x",
            trigger: ShortcutEndpoint(key: "a", modifiers: []),
            output: ShortcutEndpoint(key: "b", modifiers: []),
            delayMilliseconds: delay,
            outputStepDelayMilliseconds: stepDelay
        )
    }
}
