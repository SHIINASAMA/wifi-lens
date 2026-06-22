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
}
