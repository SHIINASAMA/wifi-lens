import SwiftUI

enum ChannelViewMode: String, CaseIterable {
    case simple
    case table

    var displayName: String {
        switch self {
        case .simple: String(localized: "channels.mode.simple", comment: "Simple view mode for channel quality")
        case .table:  String(localized: "channels.mode.professional", comment: "Professional view mode for channel quality")
        }
    }
}

struct ChannelQualityView: View {
    let channels: [ChannelRecommendation]
    let isWiFiAvailable: Bool
    @State private var mode: ChannelViewMode = .simple
    @State private var sortKey: SortKey = .rfScore
    @State private var sortAscending: Bool = false
    @State private var selectedID: String?

    enum SortKey: String { case channel, bandDisplay, rfScore, rfLevel, apCount, coChannelCount, adjacentCount, overlapLevel, strongestNeighborRSSI, interferenceScore, classification }

    private var displayed: [ChannelRecommendation] {
        if mode == .simple {
            return channels.filter(\.showInSimpleView)
        }

        return channels.sorted { a, b in
            let cmp: Bool = switch sortKey {
            case .channel:              a.channel < b.channel
            case .bandDisplay:          a.bandDisplay < b.bandDisplay
            case .rfScore:             a.rfScore < b.rfScore
            case .rfLevel:             a.rfScore < b.rfScore
            case .apCount:              a.apCount < b.apCount
            case .coChannelCount:       a.coChannelCount < b.coChannelCount
            case .adjacentCount:        a.adjacentCount < b.adjacentCount
            case .overlapLevel:         a.overlapLevel.rawValue < b.overlapLevel.rawValue
            case .strongestNeighborRSSI: a.strongestNeighborRSSI < b.strongestNeighborRSSI
            case .interferenceScore:    a.interferenceScore < b.interferenceScore
            case .classification:       a.classification.order < b.classification.order
            }
            return sortAscending ? cmp : !cmp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isWiFiAvailable {
                WiFiOffView()
            } else {
            // Mode toggle
                HStack {
                    Picker("", selection: $mode.animation(.bouncy)) {
                        ForEach(ChannelViewMode.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.regular)
                    .frame(width: 160)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                regulatoryInfoBanner

                if channels.isEmpty {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(String(localized: "spectrum.empty.no_channel_data", comment: "Empty state when no channel data exists"))
                        .foregroundColor(.secondary)
                    Spacer()
                } else if mode == .simple {
                    simpleList
                } else {
                    tableView
                }
            }
        }
    }

    // MARK: - Regulatory Info

    private var hasRegulatoryChannels: Bool {
        channels.contains(where: { $0.classification != .recommended })
    }

    private var regulatoryInfoBanner: some View {
        Group {
            if hasRegulatoryChannels {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text(String(localized: "channels.banner.regulatory", comment: "Info banner about regulatory-aware recommendations"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Simple

    private var simpleList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(displayed) { ch in
                    ChannelCard(channel: ch)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Table

    private var tableView: some View {
        ScrollView {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    sortHeader(String(localized: "channels.table.col.ch", comment: "Channel column header (abbreviated)"), .channel)
                    sortHeader(String(localized: "channels.table.col.band", comment: "Band column header"), .bandDisplay)
                    sortHeader(String(localized: "channels.table.col.score", comment: "Quality score column header"), .rfScore)
                    sortHeader(String(localized: "channels.table.col.level", comment: "Quality level column header"), .rfLevel)
                    sortHeader(String(localized: "channels.table.col.aps", comment: "Access Point count column header"), .apCount)
                    sortHeader(String(localized: "channels.table.col.co_ch", comment: "Co-channel count column header"), .coChannelCount)
                    sortHeader(String(localized: "channels.table.col.adjacent", comment: "Adjacent channel count column header"), .adjacentCount)
                    sortHeader(String(localized: "channels.table.col.overlap", comment: "Overlap column header"), .overlapLevel)
                    sortHeader(String(localized: "channels.table.col.rssi", comment: "RSSI column header"), .strongestNeighborRSSI)
                    sortHeader(String(localized: "channels.table.col.interference", comment: "Interference column header"), .interferenceScore)
                    sortHeader(String(localized: "channels.table.col.class", comment: "Regulatory class column header"), .classification)
                }
                .background(.bar)

                ForEach(Array(displayed.enumerated()), id: \.element.id) { idx, ch in
                    Divider()
                    GridRow {
                        cell("\(ch.channel)", bold: ch.isCurrentChannel, color: ch.isCurrentChannel ? .accentColor : .primary)
                        cell(ch.bandDisplay)
                        cell("\(ch.rfScore)", color: Color(hex: ch.rfLevel.color))
                        cell(ch.rfLevel.displayName, color: Color(hex: ch.rfLevel.color))
                        cell("\(ch.apCount)")
                        cell("\(ch.coChannelCount)")
                        cell("\(ch.adjacentCount)")
                        cell(ch.overlapLevel.displayName)
                        cell("\(ch.strongestNeighborRSSI)")
                        cell("\(ch.interferenceScore)")
                        cell(ch.classification != .recommended ? ch.classification.displayName : ch.isRecommended ? "★" : "")
                    }
                    .background(rowBG(ch.id, idx: idx))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedID = ch.id }
                }
            }
            .padding(12)
        }
    }

    private func sortHeader(_ text: String, _ key: SortKey) -> some View {
        Button {
            if sortKey == key { sortAscending.toggle() }
            else { sortKey = key; sortAscending = true }
        } label: {
            HStack(spacing: 2) {
                Text(text)
                if sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(sortKey == key ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5)
    }

    private func rowBG(_ id: String, idx: Int) -> Color {
        if selectedID == id { return .accentColor.opacity(0.25) }
        return idx.isMultiple(of: 2) ? .clear : .primary.opacity(0.04)
    }

    private func cell(_ text: String, bold: Bool = false, color: Color = .primary) -> some View {
        Text(text).font(.system(size: 11, weight: bold ? .semibold : .regular))
            .foregroundColor(color).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 5)
    }
}

// MARK: - Card

private struct ChannelCard: View {
    let channel: ChannelRecommendation

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color(hex: channel.rfLevel.color).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("\(channel.channel)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: channel.rfLevel.color))
                }
                Text(channel.bandDisplay)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(channel.rfLevel.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: channel.rfLevel.color))
                    if channel.rfIsRecommended { badge(String(localized: "channels.badge.recommended", comment: "Star badge marking recommended channel"), color: "#FF9F0A") }
                    if channel.isCurrentChannel { badge(String(localized: "channels.badge.current", comment: "Dot badge marking current channel"), color: "#007AFF") }
                    if channel.classification == .advanced {
                        badge(String(localized: "channels.badge.dfs", comment: "Badge for DFS/advanced classification"), color: "#FF9F0A")
                    } else if channel.classification == .restricted {
                        badge(String(localized: "channels.classification.restricted", comment: "Restricted channel classification"), color: "#FF3B30")
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: channel.rfLevel.color).opacity(0.6), Color(hex: channel.rfLevel.color)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(channel.rfScore) / 100, height: 6)
                    }
                }
                .frame(height: 6)
                Text("\(channel.rfScore)/100")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(String(localized: "channels.card.co_label", comment: "Co-channel label on detail card")).font(.system(size: 9)).foregroundColor(.secondary)
                    Text("\(channel.coChannelCount)").font(.system(size: 12, weight: .medium))
                    Text(String(localized: "channels.card.adj_label", comment: "Adjacent channel label on detail card")).font(.system(size: 9)).foregroundColor(.secondary)
                    Text("\(channel.adjacentCount)").font(.system(size: 12, weight: .medium))
                }
                HStack(spacing: 4) {
                    Image(systemName: "wave.3.right").font(.system(size: 9)).foregroundColor(.secondary)
                    Text("\(channel.strongestNeighborRSSI) dBm").font(.system(size: 11)).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Text(channel.overlapLevel.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(overlapColor(channel.overlapLevel))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(overlapColor(channel.overlapLevel).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(String(localized: "channels.card.overlap_label", comment: "Overlap label on detail card"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func badge(_ text: String, color: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Color(hex: color))
    }

    private func overlapColor(_ level: ChannelQuality.OverlapLevel) -> Color {
        switch level {
        case .low: .green; case .moderate: .orange; case .high: .red
        }
    }
}
