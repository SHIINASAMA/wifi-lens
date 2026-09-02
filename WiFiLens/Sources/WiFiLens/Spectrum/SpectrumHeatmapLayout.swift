import CoreGraphics

enum SpectrumHeatmapLayout {
    static func columnRects(
        channels: [Int],
        in rect: CGRect
    ) -> [(channel: Int, rect: CGRect)] {
        columnRects(channels: channels, nominalStep: 1, in: rect)
    }

    static func columnRects(
        channels: [Int],
        band: ChannelBand,
        in rect: CGRect
    ) -> [(channel: Int, rect: CGRect)] {
        let nominalStep = band == .band24GHz ? 1 : 4
        return columnRects(channels: channels, nominalStep: nominalStep, in: rect)
    }

    private static func columnRects(
        channels: [Int],
        nominalStep: Int,
        in rect: CGRect
    ) -> [(channel: Int, rect: CGRect)] {
        guard rect.width > 0, rect.height > 0, !channels.isEmpty else { return [] }

        let sortedChannels = Array(Set(channels)).sorted()
        guard sortedChannels.count > 1 else {
            return [(channel: channels[0], rect: rect)]
        }

        let halfStep = CGFloat(max(nominalStep, 1)) / 2
        let domainMin = CGFloat(sortedChannels[0]) - halfStep
        let domainMax = CGFloat(sortedChannels[sortedChannels.count - 1]) + halfStep
        let scale = rect.width / (domainMax - domainMin)

        return channels.map { channel in
            let center = rect.minX + (CGFloat(channel) - domainMin) * scale
            let halfWidth = halfStep * scale
            return (
                channel: channel,
                rect: CGRect(
                    x: center - halfWidth,
                    y: rect.minY,
                    width: halfWidth * 2,
                    height: rect.height
                )
            )
        }
    }

    static func cell(
        at point: CGPoint,
        in rect: CGRect,
        model: SpectrumHeatmapModel
    ) -> (row: Int, channel: Int)? {
        guard rect.contains(point), !model.rows.isEmpty else { return nil }
        guard let column = columnRects(channels: model.channels, band: model.band, in: rect)
            .first(where: { $0.rect.contains(point) }) else { return nil }

        let rowHeight = rect.height / CGFloat(model.rows.count)
        guard rowHeight > 0 else { return nil }
        let row = min(Int((point.y - rect.minY) / rowHeight), model.rows.count - 1)
        guard model.rows[row].cells.contains(where: { $0.channel == column.channel }) else {
            return nil
        }
        return (row: row, channel: column.channel)
    }
}
