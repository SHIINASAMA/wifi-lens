import Foundation

enum SpectrumPanelID: String, CaseIterable, Hashable {
    case primary
    case secondary
    case tertiary
}

enum SpectrumPanelViewType: String, CaseIterable, Identifiable {
    case spectrum = "spectrum"
    case trend = "trend"
    case table = "table"
    case heatmap = "heatmap"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spectrum: return String(localized: "nav.spectrum", comment: "Spectrum chart label in the spectrum panel")
        case .trend: return String(localized: "spectrum.panel.trend", comment: "Trend chart label in spectrum panel")
        case .table: return String(localized: "spectrum.panel.table", comment: "Table view label in spectrum panel")
        case .heatmap: return String(localized: "spectrum.panel.heatmap", comment: "Heatmap label in spectrum panel")
        }
    }

    var icon: String {
        switch self {
        case .spectrum: return "wave.3.left"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .table: return "tablecells"
        case .heatmap: return "square.grid.3x3.fill"
        }
    }
}
