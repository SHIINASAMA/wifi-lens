import SwiftUI
import AppKit

struct NativeTableView: NSViewRepresentable {
    let rows: [NetworkTableRow]
    @Binding var selectedID: String?
    @Binding var sortOrder: [NSSortDescriptor]
    var onToggleVisibility: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, selectedID: $selectedID, sortOrder: $sortOrder, onToggleVisibility: onToggleVisibility)
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
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        // Color dot column
        let dotColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("dot"))
        dotColumn.title = ""
        dotColumn.width = 24
        dotColumn.minWidth = 24
        dotColumn.maxWidth = 24
        dotColumn.isEditable = false
        tableView.addTableColumn(dotColumn)

        // Checkbox column
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("check"))
        checkColumn.title = ""
        checkColumn.width = 22
        checkColumn.minWidth = 22
        checkColumn.maxWidth = 22
        checkColumn.isEditable = false
        tableView.addTableColumn(checkColumn)

        // Data columns with sort support
        addColumn(to: tableView, id: "SSID", title: "SSID", width: 160, sortKey: "ssid", ascending: true)
        addColumn(to: tableView, id: "Hidden", title: "H", width: 20, sortKey: "isHiddenSSID", ascending: false)
        addColumn(to: tableView, id: "Band", title: "Band", width: 80, sortKey: "bandLabel", ascending: true)
        addColumn(to: tableView, id: "Ch", title: "Ch", width: 50, sortKey: "channel", ascending: true)
        addColumn(to: tableView, id: "RSSI", title: "RSSI", width: 75, sortKey: "rssi", ascending: false)
        addColumn(to: tableView, id: "BSSID", title: "BSSID", width: 150, sortKey: "bssid", ascending: true)
        addColumn(to: tableView, id: "PHY", title: "PHY", width: 36, sortKey: "phyMode", ascending: true)
        addColumn(to: tableView, id: "BW", title: "BW", width: 40, sortKey: "channelWidth", ascending: false)
        addColumn(to: tableView, id: "k", title: "k", width: 28, sortKey: "supportsK", ascending: false)
        addColumn(to: tableView, id: "r", title: "r", width: 28, sortKey: "supportsR", ascending: false)
        addColumn(to: tableView, id: "v", title: "v", width: 28, sortKey: "supportsV", ascending: false)
        addColumn(to: tableView, id: "Score", title: "Score", width: 48, sortKey: "qualityScore", ascending: false)
        addColumn(to: tableView, id: "Sec", title: "Sec", width: 120, sortKey: "security", ascending: true)
        addColumn(to: tableView, id: "MCS", title: "MCS", width: 36, sortKey: "mcs", ascending: false)
        addColumn(to: tableView, id: "NSS", title: "NSS", width: 36, sortKey: "nss", ascending: false)
        addColumn(to: tableView, id: "CC", title: "CC", width: 36, sortKey: "country", ascending: true)

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

        let rowsChanged = context.coordinator.rows.map(\.id) != rows.map(\.id)
            || context.coordinator.rows.map(\.isVisible) != rows.map(\.isVisible)
        let orderChanged = context.coordinator.sortOrder.wrappedValue != sortOrder
        context.coordinator.rows = rows
        context.coordinator.selectedID = $selectedID
        context.coordinator.sortOrder = $sortOrder

        if rowsChanged || orderChanged {
            tableView.reloadData()
        }

        // Restore selection
        if let selID = selectedID,
           let idx = rows.firstIndex(where: { $0.id == selID }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
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
        var onToggleVisibility: ((String) -> Void)?

        init(rows: [NetworkTableRow], selectedID: Binding<String?>, sortOrder: Binding<[NSSortDescriptor]>, onToggleVisibility: ((String) -> Void)?) {
            self.rows = rows
            self.selectedID = selectedID
            self.sortOrder = sortOrder
            self.onToggleVisibility = onToggleVisibility
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < rows.count, let columnID = tableColumn?.identifier.rawValue else { return nil }
            let network = rows[row]
            let opacity = rowOpacity(network)

            if columnID == "check" {
                let container = NSView(frame: NSRect(x: 0, y: 0, width: 22, height: 16))
                let checkbox = NSButton(frame: NSRect(x: 3, y: 1, width: 16, height: 14))
                checkbox.setButtonType(.switch)
                checkbox.title = ""
                checkbox.state = network.isVisible ? .on : .off
                checkbox.isEnabled = true
                checkbox.alphaValue = opacity
                checkbox.tag = row
                checkbox.target = self
                checkbox.action = #selector(Coordinator.checkboxToggled(_:))
                container.addSubview(checkbox)
                return container
            }

            if columnID == "dot" {
                let view = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 16))
                let dot = NSView(frame: NSRect(x: 8, y: 4, width: 8, height: 8))
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

            switch columnID {
            case "Hidden": return hiddenIndicator(network.isHiddenSSID, opacity: opacity)
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
            return textField
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            let newDescriptors = tableView.sortDescriptors
            DispatchQueue.main.async {
                self.sortOrder.wrappedValue = newDescriptors
            }
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let selectedRow = tableView.selectedRow
            let newID: String? = (selectedRow >= 0 && selectedRow < rows.count) ? rows[selectedRow].id : nil
            DispatchQueue.main.async {
                self.selectedID.wrappedValue = newID
            }
        }

        @MainActor private func hiddenIndicator(_ hidden: Bool, opacity: Double) -> NSView {
            guard hidden else { return NSView() }
            let label = NSTextField(labelWithString: "H")
            label.font = NSFont.systemFont(ofSize: 9, weight: .medium)
            label.textColor = NSColor.secondaryLabelColor.withAlphaComponent(opacity)
            label.alignment = .center
            return label
        }

        @MainActor @objc func checkboxToggled(_ sender: NSButton) {
            let row = sender.tag
            guard row < rows.count else { return }
            onToggleVisibility?(rows[row].bssid)
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
