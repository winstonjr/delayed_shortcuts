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
            case .enabled:
                return "On"
            case .name:
                return "Name"
            case .trigger:
                return "Trigger"
            case .output:
                return "Output"
            case .delay:
                return "Delay"
            }
        }

        var width: CGFloat {
            switch self {
            case .enabled:
                return 56
            case .name:
                return 210
            case .trigger:
                return 190
            case .output:
                return 150
            case .delay:
                return 90
            }
        }
    }

    private let tableView = NSTableView()
    private var shortcuts: [DelayedShortcut] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configured Shortcuts"
        window.minSize = NSSize(width: 620, height: 320)
        super.init(window: window)
        setupContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(shortcuts: [DelayedShortcut]) {
        self.shortcuts = shortcuts
        tableView.reloadData()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupContent() {
        guard let contentView = window?.contentView else {
            return
        }

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
        tableView.rowHeight = 28

        for column in Column.allCases {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = column.width
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        shortcuts.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard row < shortcuts.count, let tableColumn else {
            return nil
        }

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
        case .name:
            textField.stringValue = shortcut.name
        case .trigger:
            textField.stringValue = shortcut.trigger.displayText
        case .output:
            textField.stringValue = shortcut.output.displayText
        case .delay:
            textField.stringValue = shortcut.delayDisplayText
        case .none:
            textField.stringValue = ""
        }

        return textField
    }
}
