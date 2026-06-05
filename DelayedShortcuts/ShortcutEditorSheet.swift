import Cocoa

final class ShortcutEditorSheet: NSWindowController {
    var onSave: ((DelayedShortcut) -> Void)?

    private let editingShortcut: DelayedShortcut?

    private let nameField = NSTextField()
    private let enabledBox = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
    private let consumeBox = NSButton(checkboxWithTitle: "Consume trigger", target: nil, action: nil)

    private let triggerKeyField = NSTextField()
    private var triggerModBoxes: [ShortcutModifier: NSButton] = [:]

    private var outputRows: [OutputRow] = []
    private let outputsStack = NSStackView()
    private let addOutputButton = NSButton(title: "+ Add Output", target: nil, action: nil)

    private let delayField = NSTextField()
    private let stepDelayField = NSTextField()

    private let errorLabel = NSTextField(labelWithString: "")

    init(shortcut: DelayedShortcut? = nil) {
        self.editingShortcut = shortcut
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 530),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = shortcut == nil ? "Add Shortcut" : "Edit Shortcut"
        super.init(window: window)
        setupContent()
        populate(from: shortcut)
    }

    required init?(coder: NSCoder) { nil }

    func present(on parent: NSWindow) {
        guard let sheet = window else { return }
        parent.beginSheet(sheet) { [weak self] _ in
            self?.window?.orderOut(nil)
        }
    }

    private func dismiss(response: NSApplication.ModalResponse) {
        guard let sheet = window, let parent = sheet.sheetParent else { return }
        parent.endSheet(sheet, returnCode: response)
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 14
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            outerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            outerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            outerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        // Name
        outerStack.addArrangedSubview(labeledRow("Name", control: nameField))
        nameField.placeholderString = "My Shortcut"

        // Enabled + Consume
        let flagsRow = NSStackView(views: [enabledBox, consumeBox])
        flagsRow.spacing = 20
        outerStack.addArrangedSubview(flagsRow)

        outerStack.addArrangedSubview(separator())

        // Trigger
        outerStack.addArrangedSubview(sectionHeader("Trigger"))
        outerStack.addArrangedSubview(endpointRow(
            keyField: triggerKeyField,
            modBoxes: &triggerModBoxes
        ))

        outerStack.addArrangedSubview(separator())

        // Outputs
        outerStack.addArrangedSubview(sectionHeader("Outputs"))

        outputsStack.orientation = .vertical
        outputsStack.alignment = .leading
        outputsStack.spacing = 6
        outputsStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addArrangedSubview(outputsStack)

        addOutputButton.bezelStyle = .inline
        addOutputButton.target = self
        addOutputButton.action = #selector(addOutputRow)
        outerStack.addArrangedSubview(addOutputButton)

        outerStack.addArrangedSubview(separator())

        // Delays
        delayField.placeholderString = "0"
        delayField.formatter = onlyIntFormatter()
        stepDelayField.placeholderString = "0"
        stepDelayField.formatter = onlyIntFormatter()

        outerStack.addArrangedSubview(labeledRow("Initial delay (ms)", control: delayField))
        outerStack.addArrangedSubview(labeledRow("Step delay (ms)", control: stepDelayField))

        outerStack.addArrangedSubview(separator())

        // Error + buttons
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        outerStack.addArrangedSubview(errorLabel)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelBtn.keyEquivalent = "\u{1B}"
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveBtn.keyEquivalent = "\r"
        saveBtn.bezelStyle = .push

        let btnRow = NSStackView(views: [NSView(), cancelBtn, saveBtn])
        btnRow.spacing = 8
        outerStack.addArrangedSubview(btnRow)

        NSLayoutConstraint.activate([
            btnRow.widthAnchor.constraint(equalTo: outerStack.widthAnchor),
            nameField.widthAnchor.constraint(equalToConstant: 300),
            triggerKeyField.widthAnchor.constraint(equalToConstant: 80),
            delayField.widthAnchor.constraint(equalToConstant: 80),
            stepDelayField.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func populate(from shortcut: DelayedShortcut?) {
        if let shortcut {
            nameField.stringValue = shortcut.name
            enabledBox.state = shortcut.enabled ? .on : .off
            consumeBox.state = shortcut.consumeTrigger ? .on : .off

            triggerKeyField.stringValue = shortcut.trigger.key
            set(modBoxes: triggerModBoxes, to: shortcut.trigger.modifiers)

            for endpoint in shortcut.outputs {
                appendOutputRow(with: endpoint)
            }

            delayField.stringValue = "\(shortcut.delayMilliseconds)"
            stepDelayField.stringValue = "\(shortcut.outputStepDelayMilliseconds)"
        } else {
            enabledBox.state = .on
            consumeBox.state = .on
            appendOutputRow(with: nil)
        }
    }

    @objc private func addOutputRow() {
        appendOutputRow(with: nil)
    }

    private func appendOutputRow(with endpoint: ShortcutEndpoint?) {
        var modBoxes: [ShortcutModifier: NSButton] = [:]
        let keyField = NSTextField()
        keyField.placeholderString = "key"
        keyField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([keyField.widthAnchor.constraint(equalToConstant: 80)])

        let row = OutputRow(keyField: keyField, modBoxes: &modBoxes, index: outputRows.count)
        row.onRemove = { [weak self] r in self?.removeOutputRow(r) }
        outputRows.append(row)
        outputsStack.addArrangedSubview(row.view)

        if let endpoint {
            keyField.stringValue = endpoint.key
            set(modBoxes: modBoxes, to: endpoint.modifiers)
        }
    }

    private func removeOutputRow(_ row: OutputRow) {
        if outputRows.count <= 1 {
            errorLabel.stringValue = "At least one output is required."
            return
        }
        errorLabel.stringValue = ""
        outputsStack.removeArrangedSubview(row.view)
        row.view.removeFromSuperview()
        outputRows.removeAll { $0 === row }
    }

    @objc private func cancelTapped() {
        dismiss(response: .cancel)
    }

    @objc private func saveTapped() {
        errorLabel.stringValue = ""

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorLabel.stringValue = "Name is required."
            return
        }

        let triggerKey = triggerKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !triggerKey.isEmpty, KeyLookup.keyCode(for: triggerKey) != nil else {
            errorLabel.stringValue = "Trigger key '\(triggerKey)' is not recognized."
            return
        }

        let outputs = outputRows.compactMap { row -> ShortcutEndpoint? in
            let key = row.keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, KeyLookup.keyCode(for: key) != nil else { return nil }
            return ShortcutEndpoint(key: key, modifiers: row.selectedModifiers)
        }
        guard !outputs.isEmpty else {
            errorLabel.stringValue = "At least one valid output key is required."
            return
        }

        let delay = Int(delayField.stringValue) ?? 0
        let stepDelay = Int(stepDelayField.stringValue) ?? 0
        let trigger = ShortcutEndpoint(
            key: triggerKey,
            modifiers: selectedModifiers(from: triggerModBoxes)
        )
        let shortcut = DelayedShortcut(
            id: editingShortcut?.id ?? UUID().uuidString,
            name: name,
            trigger: trigger,
            outputs: outputs,
            delayMilliseconds: delay,
            outputStepDelayMilliseconds: stepDelay,
            enabled: enabledBox.state == .on,
            consumeTrigger: consumeBox.state == .on
        )

        onSave?(shortcut)
        dismiss(response: .OK)
    }

    private func set(modBoxes: [ShortcutModifier: NSButton], to modifiers: [ShortcutModifier]) {
        for (modifier, box) in modBoxes {
            box.state = modifiers.contains(modifier) ? .on : .off
        }
    }

    private func selectedModifiers(from boxes: [ShortcutModifier: NSButton]) -> [ShortcutModifier] {
        ShortcutModifier.allCases.filter { boxes[$0]?.state == .on }
    }

    private func endpointRow(
        keyField: NSTextField,
        modBoxes: inout [ShortcutModifier: NSButton]
    ) -> NSView {
        keyField.placeholderString = "key"
        let row = NSStackView()
        row.spacing = 8
        row.addArrangedSubview(keyField)

        for modifier in ShortcutModifier.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let box = NSButton(checkboxWithTitle: modifier.displayName, target: nil, action: nil)
            modBoxes[modifier] = box
            row.addArrangedSubview(box)
        }

        return row
    }

    private func labeledRow(_ label: String, control: NSView) -> NSView {
        let lbl = NSTextField(labelWithString: label + ":")
        lbl.alignment = .right
        lbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([lbl.widthAnchor.constraint(equalToConstant: 130)])

        let row = NSStackView(views: [lbl, control])
        row.spacing = 8
        return row
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: title)
        lbl.font = .boldSystemFont(ofSize: 12)
        return lbl
    }

    private func separator() -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        return sep
    }

    private func onlyIntFormatter() -> NumberFormatter {
        let fmt = NumberFormatter()
        fmt.allowsFloats = false
        fmt.minimum = 0
        return fmt
    }
}

// MARK: - OutputRow

private final class OutputRow: NSObject {
    let view: NSView
    let keyField: NSTextField
    private var modBoxes: [ShortcutModifier: NSButton]

    var onRemove: ((OutputRow) -> Void)?

    var selectedModifiers: [ShortcutModifier] {
        ShortcutModifier.allCases.filter { modBoxes[$0]?.state == .on }
    }

    init(keyField: NSTextField, modBoxes: inout [ShortcutModifier: NSButton], index: Int) {
        self.keyField = keyField

        let stack = NSStackView()
        stack.spacing = 8
        stack.addArrangedSubview(keyField)

        var boxes: [ShortcutModifier: NSButton] = [:]
        for modifier in ShortcutModifier.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let box = NSButton(checkboxWithTitle: modifier.displayName, target: nil, action: nil)
            boxes[modifier] = box
            stack.addArrangedSubview(box)
        }
        modBoxes = boxes
        self.modBoxes = boxes

        let removeBtn = NSButton(title: "–", target: nil, action: nil)
        removeBtn.bezelStyle = .inline
        stack.addArrangedSubview(removeBtn)

        self.view = stack
        super.init()

        removeBtn.target = self
        removeBtn.action = #selector(removeTapped)
    }

    @objc private func removeTapped() {
        onRemove?(self)
    }
}
