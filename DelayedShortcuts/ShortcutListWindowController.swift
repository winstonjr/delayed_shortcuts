import Cocoa

final class ShortcutListWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private enum Column: String, CaseIterable {
        case enabled
        case name
        case trigger
        case output
        case delay

        var title: String {
            switch self {
            case .enabled: return "On"
            case .name: return "Name"
            case .trigger: return "Trigger"
            case .output: return "Output"
            case .delay: return "Delay"
            }
        }

        var width: CGFloat {
            switch self {
            case .enabled: return 40
            case .name: return 200
            case .trigger: return 190
            case .output: return 160
            case .delay: return 120
            }
        }
    }

    private let tableView = NSTableView()
    private var shortcuts: [DelayedShortcut] = []

    private let addButton = NSButton(title: "Add", target: nil, action: nil)
    private let editButton = NSButton(title: "Edit", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let toggleButton = NSButton(title: "Toggle", target: nil, action: nil)

    var onSave: (([DelayedShortcut]) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configured Shortcuts"
        window.minSize = NSSize(width: 620, height: 340)
        super.init(window: window)
        setupContent()
    }

    required init?(coder: NSCoder) { nil }

    func update(shortcuts: [DelayedShortcut]) {
        self.shortcuts = shortcuts
        tableView.reloadData()
        refreshButtons()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        // Table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = true
        tableView.rowHeight = 28
        tableView.doubleAction = #selector(editSelected)
        tableView.target = self

        for column in Column.allCases {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = column.width * 0.6
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView

        // Button bar
        [addButton, editButton, deleteButton, toggleButton].forEach {
            $0.bezelStyle = .inline
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        addButton.target = self; addButton.action = #selector(addShortcut)
        editButton.target = self; editButton.action = #selector(editSelected)
        deleteButton.target = self; deleteButton.action = #selector(deleteSelected)
        toggleButton.target = self; toggleButton.action = #selector(toggleSelected)

        let buttonBar = NSStackView(views: [addButton, editButton, deleteButton, toggleButton, NSView()])
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.spacing = 8
        buttonBar.orientation = .horizontal

        contentView.addSubview(scrollView)
        contentView.addSubview(buttonBar)

        NSLayoutConstraint.activate([
            buttonBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buttonBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            buttonBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            buttonBar.heightAnchor.constraint(equalToConstant: 28),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: -10)
        ])

        refreshButtons()
    }

    private func refreshButtons() {
        let selected = tableView.selectedRowIndexes
        editButton.isEnabled = selected.count == 1
        deleteButton.isEnabled = !selected.isEmpty
        toggleButton.isEnabled = !selected.isEmpty
    }

    private func commitChanges() {
        onSave?(shortcuts)
    }

    @objc private func addShortcut() {
        guard let window else { return }
        let sheet = ShortcutEditorSheet(shortcut: nil)
        sheet.onSave = { [weak self] newShortcut in
            self?.shortcuts.append(newShortcut)
            self?.tableView.reloadData()
            self?.commitChanges()
        }
        sheet.present(on: window)
    }

    @objc private func editSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < shortcuts.count, let window else { return }
        let sheet = ShortcutEditorSheet(shortcut: shortcuts[row])
        sheet.onSave = { [weak self] updated in
            self?.shortcuts[row] = updated
            self?.tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(0..<Column.allCases.count))
            self?.commitChanges()
        }
        sheet.present(on: window)
    }

    @objc private func deleteSelected() {
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Delete \(selected.count == 1 ? "shortcut" : "\(selected.count) shortcuts")?"
        alert.informativeText = "This will remove the selected shortcut\(selected.count == 1 ? "" : "s") and save immediately."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard let window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            for index in selected.reversed() {
                self.shortcuts.remove(at: index)
            }
            self.tableView.reloadData()
            self.commitChanges()
        }
    }

    @objc private func toggleSelected() {
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }

        for index in selected {
            shortcuts[index].enabled.toggle()
        }
        tableView.reloadData(forRowIndexes: selected, columnIndexes: IndexSet(0..<Column.allCases.count))
        commitChanges()
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        shortcuts.count
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < shortcuts.count, let tableColumn else { return nil }

        let identifier = tableColumn.identifier
        let textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField
            ?? NSTextField(labelWithString: "")
        textField.identifier = identifier
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1

        let shortcut = shortcuts[row]
        switch Column(rawValue: identifier.rawValue) {
        case .enabled:
            textField.stringValue = shortcut.enabled ? "On" : "Off"
            textField.textColor = shortcut.enabled ? .secondaryLabelColor : .tertiaryLabelColor
        case .name:
            textField.stringValue = shortcut.name
        case .trigger:
            textField.stringValue = shortcut.trigger.displayText
        case .output:
            textField.stringValue = shortcut.outputDisplayText
        case .delay:
            textField.stringValue = shortcut.delayDisplayText
        case .none:
            textField.stringValue = ""
        }

        return textField
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        refreshButtons()
    }
}
