import SwiftUI
import AppKit

struct NativeTableView: NSViewRepresentable {
    let rows: [NetworkTableRow]
    @Binding var selectedID: String?
    @Binding var sortOrder: [NSSortDescriptor]
    @Binding var hiddenColumns: Set<String>
    var onToggleVisibility: ((String) -> Void)?
    var onToggleVisibilityLocked: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, selectedID: $selectedID, sortOrder: $sortOrder, hiddenColumns: $hiddenColumns, onToggleVisibility: onToggleVisibility, onToggleVisibilityLocked: onToggleVisibilityLocked)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 20
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing

        // Color dot column
        let dotColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("dot"))
        dotColumn.title = ""
        dotColumn.width = 24
        dotColumn.minWidth = 24
        dotColumn.maxWidth = 24
        dotColumn.isEditable = false
        tableView.addTableColumn(dotColumn)

        // Visibility column (专注 -> 可见性)
        let visibilityColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("visibility"))
        visibilityColumn.title = String(localized: "table.column.visibility", comment: "Visibility column header in network table")
        visibilityColumn.width = 42
        visibilityColumn.minWidth = 38
        visibilityColumn.maxWidth = 46
        visibilityColumn.isEditable = false
        tableView.addTableColumn(visibilityColumn)

        // Lock column (锁定)
        let lockColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lock"))
        lockColumn.title = String(localized: "table.column.lock", comment: "Lock column header in network table")
        lockColumn.width = 28
        lockColumn.minWidth = 24
        lockColumn.maxWidth = 32
        lockColumn.isEditable = false
        tableView.addTableColumn(lockColumn)

        // Data columns with sort support
        addColumn(to: tableView, id: "SSID", title: String(localized: "table.column.ssid", comment: "SSID column header in network table"), width: 160, sortKey: "ssid", ascending: true)
        addColumn(to: tableView, id: "Hidden", title: String(localized: "table.column.hidden", comment: "Hidden network indicator column header"), width: 20, sortKey: "isHiddenSSID", ascending: false)
        addColumn(to: tableView, id: "Band", title: String(localized: "channels.table.col.band", comment: "Band column header"), width: 80, sortKey: "bandLabel", ascending: true)
        addColumn(to: tableView, id: "Ch", title: String(localized: "table.column.channel", comment: "Channel column header (abbreviated)"), width: 50, sortKey: "channel", ascending: true)
        addColumn(to: tableView, id: "RSSI", title: String(localized: "channels.table.col.rssi", comment: "RSSI column header"), width: 75, sortKey: "rssi", ascending: false)
        addColumn(to: tableView, id: "BSSID", title: String(localized: "interfaces.field.bssid", comment: "BSSID field label"), width: 150, sortKey: "bssid", ascending: true)
        addColumn(to: tableView, id: "Seen", title: String(localized: "table.column.seen", comment: "Last seen column header"), width: 56, sortKey: "lastSeen", ascending: false)
        addColumn(to: tableView, id: "PHY", title: String(localized: "interfaces.field.phy", comment: "PHY mode field label (short)"), width: 36, sortKey: "phyMode", ascending: true)
        addColumn(to: tableView, id: "BW", title: String(localized: "table.column.bandwidth", comment: "Channel bandwidth column header"), width: 40, sortKey: "channelWidth", ascending: false)
        addColumn(to: tableView, id: "k", title: String(localized: "table.column.dot11k", comment: "802.11k support indicator column header"), width: 28, sortKey: "supportsK", ascending: false)
        addColumn(to: tableView, id: "r", title: String(localized: "table.column.dot11r", comment: "802.11r support indicator column header"), width: 28, sortKey: "supportsR", ascending: false)
        addColumn(to: tableView, id: "v", title: String(localized: "table.column.dot11v", comment: "802.11v support indicator column header"), width: 28, sortKey: "supportsV", ascending: false)
        addColumn(to: tableView, id: "Score", title: String(localized: "channels.table.col.score", comment: "Quality score column header"), width: 48, sortKey: "qualityScore", ascending: false)
        addColumn(to: tableView, id: "Sec", title: String(localized: "table.column.security", comment: "Security type column header (abbreviated)"), width: 120, sortKey: "security", ascending: true)
        addColumn(to: tableView, id: "MCS", title: String(localized: "table.column.mcs", comment: "MCS index column header"), width: 36, sortKey: "mcs", ascending: false)
        addColumn(to: tableView, id: "NSS", title: String(localized: "table.column.nss", comment: "NSS (spatial streams) column header"), width: 36, sortKey: "nss", ascending: false)
        addColumn(to: tableView, id: "CC", title: String(localized: "table.column.country_code", comment: "Country code column header"), width: 36, sortKey: "country", ascending: true)

        // Apply persisted hidden columns
        for column in tableView.tableColumns {
            if hiddenColumns.contains(column.identifier.rawValue) {
                column.isHidden = true
            }
        }

        // Custom header view for column context menu
        let headerView = ColumnMenuHeaderView()
        headerView.menuProvider = { [weak tableView] in
            guard let tableView = tableView else { return nil }
            let menu = NSMenu()
            for column in tableView.tableColumns {
                let id = column.identifier.rawValue
                if id == "dot" || id == "check" { continue }
                let item = NSMenuItem(title: column.title, action: nil, keyEquivalent: "")
                item.state = column.isHidden ? .off : .on
                item.representedObject = id
                item.target = context.coordinator
                item.action = #selector(Coordinator.toggleColumnVisibility(_:))
                menu.addItem(item)
            }
            return menu
        }
        tableView.headerView = headerView
        context.coordinator.tableView = tableView

        // Apply stored sort descriptors
        let storedColumns = tableView.tableColumns
        for descriptor in sortOrder {
            if let key = descriptor.key,
               let column = storedColumns.first(where: { $0.identifier.rawValue == key }) {
                column.sortDescriptorPrototype = descriptor
            }
        }
        if !sortOrder.isEmpty {
            tableView.sortDescriptors = sortOrder
        }

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }

        let rowsChanged = context.coordinator.rows != rows
        let selectionChanged = context.coordinator.previousSelectedID != selectedID
        context.coordinator.rows = rows
        context.coordinator.selectedID = $selectedID
        context.coordinator.sortOrder = $sortOrder
        context.coordinator.previousSelectedID = selectedID

        let needsRestore = rowsChanged || selectionChanged

        if rowsChanged {
            tableView.reloadData()
            context.coordinator.autoSizeColumns()
        } else if selectionChanged {
            let visibleRange = tableView.rows(in: tableView.visibleRect)
            let rowIndexes = IndexSet(integersIn: visibleRange.lowerBound..<visibleRange.upperBound)
            let colIndexes = IndexSet(integersIn: 0..<tableView.tableColumns.count)
            tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: colIndexes)
        }

        // Restore selection only when state actually changed, not on every scan refresh.
        if needsRestore {
            if let selID = selectedID,
               let idx = rows.firstIndex(where: { $0.id == selID }),
               tableView.selectedRow != idx {
                tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            } else if selectedID == nil && tableView.selectedRow != -1 {
                tableView.deselectAll(nil)
            }
        }
    }

    private func addColumn(to tableView: NSTableView, id: String, title: String, width: CGFloat, sortKey: String, ascending: Bool) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        column.minWidth = max(40, width * 0.6)
        column.isEditable = false
        column.sortDescriptorPrototype = NSSortDescriptor(key: sortKey, ascending: ascending)
        tableView.addTableColumn(column)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var rows: [NetworkTableRow]
        var selectedID: Binding<String?>
        var sortOrder: Binding<[NSSortDescriptor]>
        var hiddenColumns: Binding<Set<String>>
        var onToggleVisibility: ((String) -> Void)?
        var onToggleVisibilityLocked: ((String) -> Void)?
        weak var tableView: NSTableView?
        var previousSelectedID: String?

        init(rows: [NetworkTableRow], selectedID: Binding<String?>, sortOrder: Binding<[NSSortDescriptor]>, hiddenColumns: Binding<Set<String>>, onToggleVisibility: ((String) -> Void)?, onToggleVisibilityLocked: ((String) -> Void)?) {
            self.rows = rows
            self.selectedID = selectedID
            self.sortOrder = sortOrder
            self.hiddenColumns = hiddenColumns
            self.onToggleVisibility = onToggleVisibility
            self.onToggleVisibilityLocked = onToggleVisibilityLocked
            self.previousSelectedID = selectedID.wrappedValue
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < rows.count, let columnID = tableColumn?.identifier.rawValue else { return nil }
            let network = rows[row]
            let opacity = rowOpacity(network)

            if columnID == "visibility" {
                return makeCenteredIconCell(
                    symbolName: network.isVisible ? "eye.fill" : "eye.slash",
                    tintColor: network.isVisible ? .secondaryLabelColor : .tertiaryLabelColor,
                    opacity: opacity,
                    row: row,
                    action: #selector(Coordinator.visibilityToggled(_:)),
                    accessibilityLabel: String(localized: "table.accessibility.toggle_visibility", comment: "Toggle network visibility checkbox")
                )
            }

            if columnID == "lock" {
                return makeCenteredIconCell(
                    symbolName: network.visibilityLocked ? "lock.fill" : "lock.open",
                    tintColor: network.visibilityLocked ? .secondaryLabelColor : .tertiaryLabelColor,
                    opacity: opacity,
                    row: row,
                    action: #selector(Coordinator.lockToggled(_:)),
                    accessibilityLabel: String(localized: "table.accessibility.toggle_lock", comment: "Toggle network lock checkbox")
                )
            }

            if columnID == "dot" {
                let view = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
                view.setAccessibilityElement(false)
                let dot = NSView(frame: NSRect(x: 8, y: 6, width: 8, height: 8))
                dot.wantsLayer = true
                dot.layer?.cornerRadius = 4
                let nsColor = NSColor(network.color)
                dot.layer?.backgroundColor = nsColor.withAlphaComponent(opacity).cgColor
                view.addSubview(dot)
                return view
            }

            let textField = NSTextField(labelWithString: "")
            textField.font = columnID == "BSSID" ? NSFont.systemFont(ofSize: 11) : NSFont.systemFont(ofSize: 12)
            textField.textColor = columnID == "BSSID" ? .secondaryLabelColor : .labelColor
            textField.alphaValue = opacity
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 1
            textField.translatesAutoresizingMaskIntoConstraints = false

            let cellView = NSTableCellView()
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            cellView.textField = textField

            switch columnID {
            case "Hidden": textField.stringValue = network.isHiddenSSID ? "H" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 9, weight: .medium); textField.textColor = NSColor.secondaryLabelColor.withAlphaComponent(opacity)
            case "SSID":  textField.stringValue = network.ssid
            case "Band":  textField.stringValue = network.bandLabel
            case "Ch":    textField.stringValue = String(network.channel)
            case "RSSI":
                let deltaStr: String
                if network.trendDelta != 0 {
                    let sign = network.trendDelta > 0 ? "+" : ""
                    deltaStr = " \(network.trendArrow) \(sign)\(network.trendDelta)"
                } else if !network.trendArrow.isEmpty {
                    deltaStr = " \(network.trendArrow)"
                } else {
                    deltaStr = ""
                }
                textField.stringValue = "\(network.rssi) dBm\(deltaStr)"
            case "BSSID": textField.stringValue = network.bssid
            case "Seen":  textField.stringValue = network.lastSeen; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "PHY":   textField.stringValue = network.phyMode; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "BW":    textField.stringValue = network.channelWidth; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "k":     textField.stringValue = network.supportsK ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "r":     textField.stringValue = network.supportsR ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "v":     textField.stringValue = network.supportsV ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "Score":
                textField.stringValue = "\(network.qualityScore)"
                textField.alignment = .center
                textField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                textField.textColor = scoreColor(network.qualityScore)
            case "Sec":   textField.stringValue = network.security; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "MCS":   textField.stringValue = network.mcs; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "NSS":   textField.stringValue = network.nss; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "CC":    textField.stringValue = network.country; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            default: break
            }
            return cellView
        }

        @MainActor
        private func makeCenteredIconCell(
            symbolName: String,
            tintColor: NSColor,
            opacity: Double,
            row: Int,
            action: Selector,
            accessibilityLabel: String
        ) -> NSView {
            let container = NSTableCellView()

            let button = NSButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setButtonType(.momentaryChange)
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .medium))
            button.contentTintColor = tintColor
            button.alphaValue = opacity
            button.tag = row
            button.target = self
            button.action = action
            button.setAccessibilityLabel(accessibilityLabel)
            container.addSubview(button)

            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 18),
                button.heightAnchor.constraint(equalToConstant: 18)
            ])

            return container
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            let newValue = tableView.sortDescriptors
            if newValue != sortOrder.wrappedValue {
                sortOrder.wrappedValue = newValue
            }
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let selectedRow = tableView.selectedRow
            let newID: String? = (selectedRow >= 0 && selectedRow < rows.count) ? rows[selectedRow].id : nil
            if newID != selectedID.wrappedValue {
                selectedID.wrappedValue = newID
            }
        }

        @MainActor @objc func visibilityToggled(_ sender: NSButton) {
            let row = sender.tag
            guard row < rows.count else { return }
            onToggleVisibility?(rows[row].id)
        }

        @MainActor @objc func lockToggled(_ sender: NSButton) {
            let row = sender.tag
            guard row < rows.count else { return }
            onToggleVisibilityLocked?(rows[row].id)
        }

        @MainActor @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
            guard let columnID = sender.representedObject as? String,
                  let column = tableView?.tableColumns.first(where: { $0.identifier.rawValue == columnID })
            else { return }
            column.isHidden.toggle()
            var hidden = hiddenColumns.wrappedValue
            if column.isHidden { hidden.insert(columnID) } else { hidden.remove(columnID) }
            hiddenColumns.wrappedValue = hidden
        }

        @MainActor func autoSizeColumns() {
            guard let tableView = tableView else { return }
            for column in tableView.tableColumns {
                let id = column.identifier.rawValue
                if id == "dot" || id == "check" || column.isHidden { continue }

                let font = columnFont(for: id)
                let attrs: [NSAttributedString.Key: Any] = [.font: font]

                var maxW: CGFloat = (column.title as NSString).size(withAttributes: attrs).width + 20

                for row in rows {
                    let text = rowText(row, columnID: id)
                    let w = (text as NSString).size(withAttributes: attrs).width + 14
                    if w > maxW { maxW = w }
                }

                let minW = max(column.minWidth, 28)
                column.width = min(max(minW, ceil(maxW)), 350)
            }
        }

        private func columnFont(for columnID: String) -> NSFont {
            switch columnID {
            case "BSSID": return .systemFont(ofSize: 11)
            case "PHY", "BW", "k", "r", "v", "Score", "Sec", "MCS", "NSS", "CC", "Seen":
                return .systemFont(ofSize: 10)
            default: return .systemFont(ofSize: 12)
            }
        }

        private func rowText(_ row: NetworkTableRow, columnID: String) -> String {
            switch columnID {
            case "SSID":  return row.ssid
            case "Hidden": return row.isHiddenSSID ? "H" : ""
            case "Band":  return row.bandLabel
            case "Ch":    return String(row.channel)
            case "RSSI":  return "\(row.rssi) dBm  ▲ +99"
            case "BSSID": return row.bssid
            case "Seen":  return row.lastSeen.isEmpty ? "0s" : row.lastSeen
            case "PHY":   return row.phyMode
            case "BW":    return row.channelWidth
            case "k":     return row.supportsK ? "✓" : ""
            case "r":     return row.supportsR ? "✓" : ""
            case "v":     return row.supportsV ? "✓" : ""
            case "Score": return String(row.qualityScore)
            case "Sec":   return row.security
            case "MCS":   return row.mcs
            case "NSS":   return row.nss
            case "CC":    return row.country
            default: return ""
            }
        }

        private func scoreColor(_ score: Int) -> NSColor {
            if score >= 70 { return NSColor.systemGreen }
            if score >= 40 { return NSColor.systemOrange }
            return NSColor.systemRed
        }

        private func rowOpacity(_ row: NetworkTableRow) -> Double {
            if let selID = selectedID.wrappedValue {
                return row.id == selID ? 1.0 : 0.25
            }
            return row.isFilteredOut ? Constants.filteredOutOpacity : 1.0
        }
    }
}

private final class ColumnMenuHeaderView: NSTableHeaderView {
    var menuProvider: (() -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        return menuProvider?()
    }
}
