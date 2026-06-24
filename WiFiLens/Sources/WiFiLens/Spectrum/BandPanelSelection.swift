import Foundation

enum BandPanelSelection: String, CaseIterable, Identifiable {
    case band24 = "24"
    case band5 = "5"
    case band6 = "6"
    case trend = "trend"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .band24: return "2.4 GHz"
        case .band5: return "5 GHz"
        case .band6: return "6 GHz"
        case .trend: return "Trend"
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
