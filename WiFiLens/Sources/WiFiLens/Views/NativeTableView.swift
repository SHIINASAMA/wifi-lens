import SwiftUI
import AppKit

struct NativeTableView: NSViewRepresentable {
    let rows: [NetworkTableRow]
    @Binding var selectedID: String?
    @Binding var sortOrder: [NSSortDescriptor]

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, selectedID: $selectedID, sortOrder: $sortOrder)
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
        addColumn(to: tableView, id: "WPA3", title: "WPA3", width: 50, sortKey: "supportsWPA3", ascending: false)

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

        let idsChanged = context.coordinator.rows.map(\.id) != rows.map(\.id)
        let orderChanged = context.coordinator.sortOrder.wrappedValue != sortOrder
        context.coordinator.rows = rows
        context.coordinator.selectedID = $selectedID
        context.coordinator.sortOrder = $sortOrder

        if idsChanged || orderChanged {
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

        init(rows: [NetworkTableRow], selectedID: Binding<String?>, sortOrder: Binding<[NSSortDescriptor]>) {
            self.rows = rows
            self.selectedID = selectedID
            self.sortOrder = sortOrder
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < rows.count, let columnID = tableColumn?.identifier.rawValue else { return nil }
            let network = rows[row]
            let opacity = rowOpacity(network)

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
            case "RSSI":  textField.stringValue = "\(network.rssi) dBm"
            case "BSSID": textField.stringValue = network.bssid
            case "PHY":   textField.stringValue = network.phyMode; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "BW":    textField.stringValue = network.channelWidth; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "k":     textField.stringValue = network.supportsK ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "r":     textField.stringValue = network.supportsR ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "v":     textField.stringValue = network.supportsV ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
            case "WPA3":  textField.stringValue = network.supportsWPA3 ? "✓" : ""; textField.alignment = .center; textField.font = NSFont.systemFont(ofSize: 10)
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

        private func hiddenIndicator(_ hidden: Bool, opacity: Double) -> NSView {
            guard hidden else { return NSView() }
            let label = NSTextField(labelWithString: "H")
            label.font = NSFont.systemFont(ofSize: 9, weight: .medium)
            label.textColor = NSColor.secondaryLabelColor.withAlphaComponent(opacity)
            label.alignment = .center
            return label
        }

        private func rowOpacity(_ row: NetworkTableRow) -> Double {
            if let selID = selectedID.wrappedValue {
                return row.id == selID ? 1.0 : 0.25
            }
            return row.isFilteredOut ? Constants.filteredOutOpacity : 1.0
        }
    }
}
