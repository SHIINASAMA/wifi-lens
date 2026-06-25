import Foundation

enum SpectrumPanelID: String, CaseIterable, Hashable {
    case primary
    case secondary
}

enum BandPanelSelection: String, CaseIterable, Identifiable {
    case band24 = "24"
    case band5 = "5"
    case band6 = "6"
    case trend = "trend"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .band24: return String(localized: "spectrum.panel.band.24ghz", comment: "2.4 GHz band label in spectrum panel")
        case .band5: return String(localized: "spectrum.panel.band.5ghz", comment: "5 GHz band label in spectrum panel")
        case .band6: return String(localized: "spectrum.panel.band.6ghz", comment: "6 GHz band label in spectrum panel")
        case .trend: return String(localized: "spectrum.panel.trend", comment: "Trend chart label in spectrum panel")
        }
    }
    
    var icon: String {
        switch self {
        case .band24: return "wave.3.left"
        case .band5: return "wave.3.right"
        case .band6: return "wave.3.right.circle"
        case .trend: return "chart.line.uptrend.xyaxis"
        }
    }
}
