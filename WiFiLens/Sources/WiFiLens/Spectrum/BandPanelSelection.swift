import Foundation

enum SpectrumPanelID: String, CaseIterable, Hashable {
    case primary
    case secondary
    case tertiary
}

enum SpectrumPanelViewType: String, CaseIterable, Identifiable {
    case band24 = "24"
    case band5 = "5"
    case band6 = "6"
    case trend = "trend"
    case table = "table"
    case heatmap = "heatmap"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .band24: return String(localized: "spectrum.panel.band.24ghz", comment: "2.4 GHz band label in spectrum panel")
        case .band5: return String(localized: "spectrum.panel.band.5ghz", comment: "5 GHz band label in spectrum panel")
        case .band6: return String(localized: "spectrum.panel.band.6ghz", comment: "6 GHz band label in spectrum panel")
        case .trend: return String(localized: "spectrum.panel.trend", comment: "Trend chart label in spectrum panel")
        case .table: return String(localized: "spectrum.panel.table", comment: "Table view label in spectrum panel")
        case .heatmap: return String(localized: "spectrum.panel.heatmap", comment: "Heatmap label in spectrum panel")
        }
    }

    var icon: String {
        switch self {
        case .band24: return "wave.3.left"
        case .band5: return "wave.3.right"
        case .band6: return "wave.3.right.circle"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .table: return "tablecells"
        case .heatmap: return "square.grid.3x3.fill"
        }
    }
}
