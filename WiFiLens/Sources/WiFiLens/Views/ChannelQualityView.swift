import SwiftUI

enum ChannelViewMode: String, CaseIterable {
    case simple = "Simple"
    case table  = "Professional"
}

struct ChannelQualityView: View {
    let channels: [ChannelQuality]
    @State private var mode: ChannelViewMode = .simple
    @State private var sortKey: SortKey = .qualityScore
    @State private var sortAscending: Bool = false

    enum SortKey: String { case channel, bandDisplay, qualityScore, qualityLevel, apCount, coChannelCount, adjacentCount, overlapLevel, strongestNeighborRSSI, interferenceScore }

    private var displayed: [ChannelQuality] {
        let base = mode == .simple ? channels.filter(\.showInSimpleView) : channels
        return base.sorted { a, b in
            let cmp: Bool = switch sortKey {
            case .channel:              a.channel < b.channel
            case .bandDisplay:          a.bandDisplay < b.bandDisplay
            case .qualityScore:         a.qualityScore < b.qualityScore
            case .qualityLevel:         a.qualityScore < b.qualityScore
            case .apCount:              a.apCount < b.apCount
            case .coChannelCount:       a.coChannelCount < b.coChannelCount
            case .adjacentCount:        a.adjacentCount < b.adjacentCount
            case .overlapLevel:         a.overlapLevel.rawValue < b.overlapLevel.rawValue
            case .strongestNeighborRSSI: a.strongestNeighborRSSI < b.strongestNeighborRSSI
            case .interferenceScore:    a.interferenceScore < b.interferenceScore
            }
            return sortAscending ? cmp : !cmp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle
            HStack {
                Picker("", selection: $mode) {
                    ForEach(ChannelViewMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 160)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if channels.isEmpty {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No channel data available")
                    .foregroundColor(.secondary)
                Spacer()
            } else if mode == .simple {
                simpleList
            } else {
                tableView
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
                    sortHeader("CH", .channel)
                    sortHeader("Band", .bandDisplay)
                    sortHeader("Score", .qualityScore)
                    sortHeader("Level", .qualityLevel)
                    sortHeader("APs", .apCount)
                    sortHeader("Co-Ch", .coChannelCount)
                    sortHeader("Adj", .adjacentCount)
                    sortHeader("Overlap", .overlapLevel)
                    sortHeader("RSSI", .strongestNeighborRSSI)
                    sortHeader("Intf", .interferenceScore)
                    tableHeader("Rec")
                }
                .background(.bar)

                ForEach(Array(displayed.enumerated()), id: \.element.id) { idx, ch in
                    Divider()
                    GridRow {
                        cell("\(ch.channel)", bold: ch.isCurrentChannel, color: ch.isCurrentChannel ? .accentColor : .primary)
                        cell(ch.bandDisplay)
                        cell("\(ch.qualityScore)", color: Color(hex: ch.qualityLevel.color))
                        cell(ch.qualityLevel.rawValue, color: Color(hex: ch.qualityLevel.color))
                        cell("\(ch.apCount)")
                        cell("\(ch.coChannelCount)")
                        cell("\(ch.adjacentCount)")
                        cell(ch.overlapLevel.rawValue)
                        cell("\(ch.strongestNeighborRSSI)")
                        cell("\(ch.interferenceScore)")
                        cell(ch.isRecommended ? "★" : ch.isCurrentChannel ? "●" : "")
                    }
                    .background(idx.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
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

    private func tableHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 5)
    }

    private func cell(_ text: String, bold: Bool = false, color: Color = .primary) -> some View {
        Text(text).font(.system(size: 11, weight: bold ? .semibold : .regular))
            .foregroundColor(color).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 5)
    }

    private func tableCell(_ text: String, bold: Bool = false, color: Color = .primary) -> some View {
        Text(text)
            .font(.system(size: 10, weight: bold ? .semibold : .regular))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
    }
}

// MARK: - Card

private struct ChannelCard: View {
    let channel: ChannelQuality

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color(hex: channel.qualityLevel.color).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("\(channel.channel)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: channel.qualityLevel.color))
                }
                Text(channel.bandDisplay)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(channel.qualityLevel.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: channel.qualityLevel.color))
                    if channel.isRecommended { badge("★ Recommended", color: "#FF9F0A") }
                    if channel.isCurrentChannel { badge("● Current", color: "#007AFF") }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: channel.qualityLevel.color).opacity(0.6), Color(hex: channel.qualityLevel.color)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(channel.qualityScore) / 100, height: 6)
                    }
                }
                .frame(height: 6)
                Text("\(channel.qualityScore)/100")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Co:").font(.system(size: 9)).foregroundColor(.secondary)
                    Text("\(channel.coChannelCount)").font(.system(size: 12, weight: .medium))
                    Text("· Adj:").font(.system(size: 9)).foregroundColor(.secondary)
                    Text("\(channel.adjacentCount)").font(.system(size: 12, weight: .medium))
                }
                HStack(spacing: 4) {
                    Image(systemName: "wave.3.right").font(.system(size: 9)).foregroundColor(.secondary)
                    Text("\(channel.strongestNeighborRSSI) dBm").font(.system(size: 11)).foregroundColor(.secondary)
                }
                Text(channel.overlapLevel.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(overlapColor(channel.overlapLevel))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(overlapColor(channel.overlapLevel).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(width: 100)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4))
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
