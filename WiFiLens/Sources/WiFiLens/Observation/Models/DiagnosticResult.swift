import SwiftUI

struct DiagnosticResult: Equatable, Sendable {
    var icon: String
    var title: String
    var message: String
    var severity: DiagnosticSeverity

    static let unknown = DiagnosticResult(
        icon: "questionmark.circle",
        title: String(localized: "observation.diagnosis.unknown.title", comment: "Unknown diagnosis title"),
        message: String(localized: "observation.diagnosis.unknown.message", comment: "Unknown diagnosis message"),
        severity: .ok
    )
}

enum DiagnosticSeverity: String, Sendable, CaseIterable {
    case excellent, warning, critical, ok

    var color: Color {
        switch self {
        case .excellent: return .green
        case .warning: return .orange
        case .critical: return .red
        case .ok: return .mint
        }
    }
}
