import SwiftUI
import CoreWLAN

private let headerHeight: CGFloat = 28

enum InterfaceViewMode: String, CaseIterable {
    case simple
    case details
    case monitor

    var displayName: String {
        switch self {
        case .simple:  String(localized: "Simple")
        case .details: String(localized: "Details")
        case .monitor: String(localized: "Monitor")
        }
    }
}

struct InterfacesView: View {
    let interfaces: [NetworkInterfaceInfo]
    let scannerViewModel: ScannerViewModel
    let throughputMonitor: ThroughputMonitor
    @State private var mode: InterfaceViewMode = .simple

    private var wifiInterface: NetworkInterfaceInfo? {
        interfaces.first(where: { $0.ssid != nil })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle
            HStack {
                Picker("", selection: $mode) {
                    ForEach(InterfaceViewMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 240)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if interfaces.isEmpty {
                Spacer()
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text(String(localized: "No network interfaces found"))
                    .foregroundColor(.secondary)
                Spacer()
            } else if mode == .simple {
                dashboardView
            } else if mode == .monitor {
                monitorView
            } else {
                detailsView
            }
        }
    }

    // MARK: - Dashboard (Simple)

    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let wifi = wifiInterface {
                    connectionHero(wifi)
                    healthIndicators(wifi)
                    linkDetails(wifi)
                }

                let others = interfaces.filter { $0.ssid == nil && $0.ipv4Addresses.first != nil }
                if !others.isEmpty {
                    otherInterfaces(others)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hero

    private func connectionHero(_ wifi: NetworkInterfaceInfo) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(wifi.displaySSID)
                        .font(.title3)
                        .fontWeight(.semibold)
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text(String(localized: "Connected"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("· \(wifi.interfaceName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(bandLabel(wifi))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(channelLabel(wifi))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Health Indicators

    private func healthIndicators(_ wifi: NetworkInterfaceInfo) -> some View {
        HStack(spacing: 12) {
            // RSSI
            indicatorPill(
                title: String(localized: "RSSI"),
                value: wifi.displayRSSI,
                subtitle: nil,
                color: rssiColor(wifi.rssi ?? -100),
                bar: rssiBar(wifi.rssi ?? -100)
            )

            // PHY Mode
            indicatorPill(
                title: String(localized: "PHY Mode"),
                value: wifi.displayPhyMode,
                subtitle: wifiModelabel(wifi),
                color: .accentColor,
                bar: nil
            )

            // Stability
            let stab = stability(wifi)
            indicatorPill(
                title: String(localized: "Stability"),
                value: stab.label,
                subtitle: "\(stab.score)/100",
                color: stab.color,
                bar: scoreBar(stab.score, color: stab.color)
            )
        }
    }

    private func indicatorPill(title: String, value: String, subtitle: String?, color: Color, bar: AnyView?) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(title).font(.system(size: 9)).foregroundColor(.secondary)
            Spacer().frame(height: 6)
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(color)
            Spacer().frame(height: 4)
            if let sub = subtitle {
                Text(sub).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer().frame(height: 4)
            if let bar = bar {
                bar.padding(.horizontal, 12)
            } else {
                Rectangle().fill(.clear).frame(height: 4)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Link Details

    private func linkDetails(_ wifi: NetworkInterfaceInfo) -> some View {
        HStack(alignment: .top, spacing: 24) {
            kvTable([
                (String(localized: "BSSID"), wifi.displayBSSID),
                (String(localized: "Security"), wifi.displaySecurity),
                (String(localized: "MCS / NSS"), mcsNssLabel(wifi)),
                (String(localized: "Tx Rate"), wifi.displayTxRate),
                (String(localized: "k / r / v"), kvrLabel(wifi)),
            ])
            kvTable([
                (String(localized: "IPv4 Address"), wifi.displayIP),
                (String(localized: "Subnet Mask"), wifi.displaySubnet),
                (String(localized: "Router"), wifi.displayRouter),
                (String(localized: "DNS"), wifi.displayDNS),
                (String(localized: "Hardware MAC"), wifi.displayMAC),
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Other Interfaces

    private func otherInterfaces(_ others: [NetworkInterfaceInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Other Interfaces"))
                .font(.headline)
                .foregroundColor(.secondary)
            VStack(spacing: 4) {
                ForEach(others, id: \.interfaceName) { iface in
                    HStack(spacing: 8) {
                        Image(systemName: "cable.connector")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(iface.interfaceName)
                            .font(.callout)
                        Spacer()
                        Text(iface.displayIP)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Monitor

    @State private var selectedMonitorInterface: String?
    @State private var isMonitorChartCollapsed = false
    @State private var isMonitorTableCollapsed = false

    private var monitorInterfaces: [String] {
        var seen = Set(throughputMonitor.activeInterfaces)
        for info in interfaces where !info.interfaceName.isEmpty {
            seen.insert(info.interfaceName)
        }
        return seen.sorted { a, b in
            let aWifi = a.hasPrefix("en") ? 0 : 1
            let bWifi = b.hasPrefix("en") ? 0 : 1
            if aWifi != bWifi { return aWifi < bWifi }
            return a < b
        }
    }

    private var monitorSamples: [ThroughputSample] {
        guard let name = selectedMonitorInterface else { return [] }
        return throughputMonitor.samples(for: name)
    }

    private var selectedMonitorRate: String {
        guard let name = selectedMonitorInterface,
              let last = throughputMonitor.samples(for: name).last else { return "" }
        let down = rateDown(last.rateIn)
        let up = rateUp(last.rateOut)
        return "\(down)  \(up)"
    }

    private var monitorView: some View {
        GeometryReader { geometry in
            let totalH = geometry.size.height
            let sections = 2
            let allHeaders = CGFloat(sections) * headerHeight
            let contentPool = max(0, totalH - allHeaders)
            let chartExpanded = !isMonitorChartCollapsed
            let tableExpanded = !isMonitorTableCollapsed

            let chartWeight: CGFloat = 1.0
            let tableWeight: CGFloat = 1.5
            let activeWeight = (chartExpanded ? chartWeight : 0) + (tableExpanded ? tableWeight : 0)
            let totalWeight = max(1, activeWeight)

            let chartContentH: CGFloat = chartExpanded
                ? max(60, contentPool * chartWeight / totalWeight)
                : 0
            let tableContentH: CGFloat = tableExpanded
                ? max(60, contentPool * tableWeight / totalWeight)
                : 0

            VStack(spacing: 0) {
                // Chart section
                monitorChartHeader
                if chartExpanded {
                    monitorChartContent(height: chartContentH)
                }

                Divider()

                // Interface table section
                monitorTableHeader
                if tableExpanded {
                    monitorTableContent(height: tableContentH)
                }
            }
            .clipped()
        }
    }

    private var monitorChartHeader: some View {
        Button {
            withAnimation { isMonitorChartCollapsed.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isMonitorChartCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .frame(width: 12)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                Text(String(localized: "Throughput"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(selectedMonitorRate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: headerHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var monitorTableHeader: some View {
        Button {
            withAnimation { isMonitorTableCollapsed.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isMonitorTableCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .frame(width: 12)
                Image(systemName: "list.bullet.rectangle")
                    .font(.caption)
                Text(String(localized: "Interfaces"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(monitorInterfaces.count) \(String(localized: "interfaces"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: headerHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func monitorChartContent(height: CGFloat) -> some View {
        Group {
            if monitorSamples.isEmpty {
                VStack {
                    Spacer()
                    Text(String(localized: "Select an interface below to monitor throughput"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: height)
            } else {
                ThroughputChartView(samples: monitorSamples, interfaceName: selectedMonitorInterface ?? "")
                    .frame(height: height)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func monitorTableContent(height: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(monitorInterfaces, id: \.self) { name in
                    let isSelected = selectedMonitorInterface == name
                    let lastSample = throughputMonitor.samples(for: name).last
                    Button {
                        selectedMonitorInterface = name
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: name.hasPrefix("en") ? "wifi" : "cable.connector")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                                .frame(width: 20)

                            Text(name)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(.primary)
                                .frame(width: 60, alignment: .leading)

                            Spacer()

                            if let s = lastSample {
                                Text(rateDown(s.rateIn))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(s.rateIn == 0 ? .secondary.opacity(0.5) : .green)
                                    .frame(width: 72, alignment: .trailing)
                                    .lineLimit(1)
                                Text(rateUp(s.rateOut))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(s.rateOut == 0 ? .secondary.opacity(0.5) : .blue)
                                    .frame(width: 72, alignment: .trailing)
                                    .lineLimit(1)
                            } else {
                                Text("—").font(.system(size: 12)).foregroundColor(.secondary).frame(width: 72)
                                Text("—").font(.system(size: 12)).foregroundColor(.secondary).frame(width: 72)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)

                    if name != monitorInterfaces.last {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: height)
    }

    private func rateDown(_ bytesPerSec: Double) -> String {
        "↓  " + rateVal(bytesPerSec)
    }
    private func rateUp(_ bytesPerSec: Double) -> String {
        "↑  " + rateVal(bytesPerSec)
    }
    private func rateVal(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1_024 { return String(format: "%4.0f B", bytesPerSec) }
        if bytesPerSec < 1_048_576 { return String(format: "%4.0f K", bytesPerSec / 1_024) }
        if bytesPerSec < 1_073_741_824 { return String(format: "%4.1f M", bytesPerSec / 1_048_576) }
        return String(format: "%4.1f G", bytesPerSec / 1_073_741_824)
    }

    // MARK: - Details (Professional)

    private var detailsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(interfaces, id: \.interfaceName) { iface in
                    InterfaceCard(info: iface)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helpers

    private func kvTable(_ pairs: [(String, String)]) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 4) {
            ForEach(pairs, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .gridColumnAlignment(.leading)
                }
            }
        }
    }

    private func bandLabel(_ wifi: NetworkInterfaceInfo) -> String {
        guard let ch = wifi.channel else { return "—" }
        if ch <= 14 { return String(localized: "2.4 GHz") }
        if ch <= 170 { return String(localized: "5 GHz") }
        return String(localized: "6 GHz")
    }

    private func channelLabel(_ wifi: NetworkInterfaceInfo) -> String {
        guard let ch = wifi.channel else { return "—" }
        return String(localized: "Channel \(ch)")
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -50 { return .green }
        if rssi >= -70 { return .yellow }
        if rssi >= -85 { return .orange }
        return .red
    }

    private func rssiBar(_ rssi: Int) -> AnyView {
        let pct = max(0.0, min(1.0, Double(rssi + 100) / 70.0))
        return AnyView(
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(.quaternary).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rssiColor(rssi))
                        .frame(width: geo.size.width * pct, height: 4)
                }
            }
            .frame(height: 4)
        )
    }

    private func scoreBar(_ score: Int, color: Color) -> AnyView {
        AnyView(
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(.quaternary).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 4)
                }
            }
            .frame(height: 4)
        )
    }

    private func stability(_ wifi: NetworkInterfaceInfo) -> (score: Int, label: String, color: Color) {
        let rssi = wifi.rssi ?? -100
        var score = 0
        if rssi >= -50 { score += 40 }
        else if rssi >= -70 { score += 30 }
        else if rssi >= -85 { score += 15 }

        // Trend bonus from signal history
        let bssid = wifi.bssid ?? ""
        if let trend = scannerViewModel.signalHistory.trend(for: bssid) {
            switch trend.direction {
            case .up:   score += 15
            case .down: score += 0
            case .stable:
                if abs(trend.delta) <= 2 { score += 15 }
                else { score += 5 }
            }
        }

        // Protocol bonus
        let ie = scannerViewModel.lastNetworks
            .first(where: { $0.bssid == bssid })
            .flatMap { $0.ieData.map { IEParser.parse(data: $0) } }
        let k = ie?.supports80211k ?? false
        let r = ie?.supports80211r ?? false
        let v = ie?.supports80211v ?? false
        let protoCount = [k, r, v].filter { $0 }.count
        score += [0, 7, 14, 20][protoCount]

        // Width bonus
        if let iface = CWWiFiClient.shared().interface() {
            let width = iface.wlanChannel()?.channelWidth.rawValue ?? 20
            if width >= 80 { score += 15 }
            else if width >= 40 { score += 10 }
        }

        score = min(100, score)
        let label: String = switch score {
        case 85...:  String(localized: "Excellent")
        case 70...:  String(localized: "Good")
        case 50...:  String(localized: "Moderate")
        default:     String(localized: "Weak")
        }
        let color: Color = switch score {
        case 85...: .green
        case 70...: .mint
        case 50...: .orange
        default:    .red
        }
        return (score, label, color)
    }

    private func wifiModelabel(_ wifi: NetworkInterfaceInfo) -> String {
        switch wifi.displayPhyMode {
        case "802.11be": return String(localized: "Wi‑Fi 7")
        case "802.11ax": return String(localized: "Wi‑Fi 6")
        case "802.11ac": return String(localized: "Wi‑Fi 5")
        case "802.11n":  return String(localized: "Wi‑Fi 4")
        default: return wifi.displayPhyMode
        }
    }

    private func mcsNssLabel(_ wifi: NetworkInterfaceInfo) -> String {
        let bssid = wifi.bssid ?? ""
        let ie = scannerViewModel.lastNetworks
            .first(where: { $0.bssid == bssid })
            .flatMap { $0.ieData.map { IEParser.parse(data: $0) } }
        let mcs = ie?.mcsSummary ?? ""
        let nss = ie?.nssSummary ?? ""
        if mcs.isEmpty && nss.isEmpty { return "—" }
        return "MCS \(mcs) / NSS \(nss)"
    }

    private func kvrLabel(_ wifi: NetworkInterfaceInfo) -> String {
        let bssid = wifi.bssid ?? ""
        let ie = scannerViewModel.lastNetworks
            .first(where: { $0.bssid == bssid })
            .flatMap { $0.ieData.map { IEParser.parse(data: $0) } }
        guard let ie else { return "—" }
        var parts: [String] = []
        if ie.supports80211k { parts.append("k") }
        if ie.supports80211r { parts.append("r") }
        if ie.supports80211v { parts.append("v") }
        return parts.isEmpty ? "—" : parts.joined(separator: " / ")
    }
}

// MARK: - Interface Card (Details mode)

private struct InterfaceCard: View {
    let info: NetworkInterfaceInfo

    /// A compact row that only renders if a value is meaningful.
    private func compactRow(label: String, value: String) -> some View {
        let isEmpty = value.isEmpty || value == "—"
        return HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(isEmpty ? "—" : value)
                .font(.system(size: 12, design: isEmpty ? .default : .monospaced))
                .foregroundColor(isEmpty ? .secondary.opacity(0.6) : .primary)
                .textSelection(.enabled)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    /// Non‑monospaced row for labels like security.
    private func labelRow(label: String, value: String) -> some View {
        let isEmpty = value.isEmpty || value == "—"
        return HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(isEmpty ? "—" : value)
                .font(.system(size: 12))
                .foregroundColor(isEmpty ? .secondary.opacity(0.6) : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func typeBadge(_ t: NetworkInterfaceInfo.InterfaceType) -> some View {
        let (label, color): (String, Color) = switch t {
        case .wifi:     (String(localized: "Wi‑Fi"), .accentColor)
        case .ethernet: (String(localized: "Ethernet"), .secondary)
        case .virtual:  (String(localized: "Virtual"), .secondary.opacity(0.8))
        }
        return Text(label)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    var body: some View {
        let t = info.interfaceType

        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                typeBadge(t)
                Text(t == .wifi ? (info.ssid ?? info.interfaceName) : info.interfaceName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if t == .wifi, !info.displayRSSI.isEmpty, info.displayRSSI != "—" {
                    Text(info.displayRSSI)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(rssiColor(info.rssi ?? -100))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(rssiColor(info.rssi ?? -100).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
                if t != .virtual {
                    Text(info.interfaceName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().padding(.horizontal, 8)

            // Body — two‑column compact rows
            VStack(spacing: 2) {
                if t == .wifi {
                    compactRow(label: String(localized: "BSSID"), value: info.displayBSSID)
                    compactRow(label: String(localized: "Channel"), value: info.displayChannel)
                    compactRow(label: String(localized: "PHY"), value: info.displayPhyMode)
                    compactRow(label: String(localized: "Tx Rate"), value: info.displayTxRate)
                    labelRow(label: String(localized: "Security"), value: info.displaySecurity)
                }

                // Network section — shown for Wi‑Fi and any interface that has network data
                if info.hasNetworkInfo || t == .wifi {
                    if t == .wifi {
                        Divider().padding(.horizontal, 8).padding(.vertical, 2)
                    }
                    compactRow(label: String(localized: "IPv4"), value: info.displayIP)
                    compactRow(label: String(localized: "Subnet"), value: info.displaySubnet)
                    compactRow(label: String(localized: "Router"), value: info.displayRouter)
                    compactRow(label: String(localized: "DNS"), value: info.displayDNS)
                }

                // MAC — only for Wi‑Fi and Ethernet (not virtual)
                if t != .virtual {
                    compactRow(label: String(localized: "MAC"), value: info.displayMAC)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -50 { return .green }
        if rssi >= -70 { return .yellow }
        if rssi >= -85 { return .orange }
        return .red
    }
}
