import SwiftUI
import AppKit

struct NativeTableView: NSViewRepresentable {
    let rows: [NetworkTableRow]
    @Binding var selectedID: String?
    @Binding var sortOrder: [NSSortDescriptor]
    @Binding var hiddenColumns: Set<String>
    var onToggleVisibility: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, selectedID: $selectedID, sortOrder: $sortOrder, hiddenColumns: $hiddenColumns, onToggleVisibility: onToggleVisibility)
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

        // Checkbox column
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("check"))
        checkColumn.title = ""
        checkColumn.width = 22
        checkColumn.minWidth = 22
        checkColumn.maxWidth = 22
        checkColumn.isEditable = false
        tableView.addTableColumn(checkColumn)

        // Data columns with sort support
        addColumn(to: tableView, id: "SSID", title: String(localized: "SSID"), width: 160, sortKey: "ssid", ascending: true)
        addColumn(to: tableView, id: "Hidden", title: String(localized: "H"), width: 20, sortKey: "isHiddenSSID", ascending: false)
        addColumn(to: tableView, id: "Band", title: String(localized: "Band"), width: 80, sortKey: "bandLabel", ascending: true)
        addColumn(to: tableView, id: "Ch", title: String(localized: "Ch"), width: 50, sortKey: "channel", ascending: true)
        addColumn(to: tableView, id: "RSSI", title: String(localized: "RSSI"), width: 75, sortKey: "rssi", ascending: false)
        addColumn(to: tableView, id: "BSSID", title: String(localized: "BSSID"), width: 150, sortKey: "bssid", ascending: true)
        addColumn(to: tableView, id: "PHY", title: String(localized: "PHY"), width: 36, sortKey: "phyMode", ascending: true)
        addColumn(to: tableView, id: "BW", title: String(localized: "BW"), width: 40, sortKey: "channelWidth", ascending: false)
        addColumn(to: tableView, id: "k", title: String(localized: "k"), width: 28, sortKey: "supportsK", ascending: false)
        addColumn(to: tableView, id: "r", title: String(localized: "r"), width: 28, sortKey: "supportsR", ascending: false)
        addColumn(to: tableView, id: "v", title: String(localized: "v"), width: 28, sortKey: "supportsV", ascending: false)
        addColumn(to: tableView, id: "Score", title: String(localized: "Score"), width: 48, sortKey: "qualityScore", ascending: false)
        addColumn(to: tableView, id: "Sec", title: String(localized: "Sec"), width: 120, sortKey: "security", ascending: true)
        addColumn(to: tableView, id: "MCS", title: String(localized: "MCS"), width: 36, sortKey: "mcs", ascending: false)
        addColumn(to: tableView, id: "NSS", title: String(localized: "NSS"), width: 36, sortKey: "nss", ascending: false)
        addColumn(to: tableView, id: "CC", title: String(localized: "CC"), width: 36, sortKey: "country", ascending: true)

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

        let rowsChanged = context.coordinator.rows.map(\.id) != rows.map(\.id)
            || context.coordinator.rows.map(\.isVisible) != rows.map(\.isVisible)
        let orderChanged = context.coordinator.sortOrder.wrappedValue != sortOrder
        let selectionChanged = context.coordinator.selectedID.wrappedValue != selectedID
        context.coordinator.rows = rows
        context.coordinator.selectedID = $selectedID
        context.coordinator.sortOrder = $sortOrder

        if rowsChanged || orderChanged {
            tableView.reloadData()
            context.coordinator.autoSizeColumns()
        } else if selectionChanged {
            // Reload only visible rows to update opacity without a full reload
            let visibleRange = tableView.rows(in: tableView.visibleRect)
            let rowIndexes = IndexSet(integersIn: visibleRange.lowerBound..<visibleRange.upperBound)
            let colIndexes = IndexSet(integersIn: 0..<tableView.tableColumns.count)
            tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: colIndexes)
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
        var hiddenColumns: Binding<Set<String>>
        var onToggleVisibility: ((String) -> Void)?
        weak var tableView: NSTableView?

        init(rows: [NetworkTableRow], selectedID: Binding<String?>, sortOrder: Binding<[NSSortDescriptor]>, hiddenColumns: Binding<Set<String>>, onToggleVisibility: ((String) -> Void)?) {
            self.rows = rows
            self.selectedID = selectedID
            self.sortOrder = sortOrder
            self.hiddenColumns = hiddenColumns
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

        @MainActor @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
            guard let columnID = sender.representedObject as? String,
                  let column = tableView?.tableColumns.first(where: { $0.identifier.rawValue == columnID })
            else { return }
            column.isHidden.toggle()
            var hidden = hiddenColumns.wrappedValue
            if column.isHidden { hidden.insert(columnID) } else { hidden.remove(columnID) }
            hiddenColumns.wrappedValue = hidden
        }

        func autoSizeColumns() {
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
            case "PHY", "BW", "k", "r", "v", "Score", "Sec", "MCS", "NSS", "CC":
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
