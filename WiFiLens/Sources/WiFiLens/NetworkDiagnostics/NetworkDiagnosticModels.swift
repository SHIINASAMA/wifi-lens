import Foundation

enum NetworkDiagnosticStatus: String, CaseIterable, Equatable, Sendable {
    case normal
    case abnormal
    case indeterminate
}

enum NetworkDiagnosticCheckID: String, CaseIterable, Equatable, Hashable, Sendable {
    case connectivity
    case dns
    case proxy
}

struct NetworkDiagnosticResult: Equatable, Identifiable, Sendable {
    let id: NetworkDiagnosticCheckID
    let status: NetworkDiagnosticStatus
    let summary: String
    let detail: String?

    init(
        id: NetworkDiagnosticCheckID,
        status: NetworkDiagnosticStatus,
        summary: String,
        detail: String? = nil
    ) {
        self.id = id
        self.status = status
        self.summary = summary
        self.detail = detail
    }
}

enum NetworkDiagnosticConclusion: String, Equatable, Sendable {
    case networkNormal
    case needsAttention
    case networkUnavailable

    static func evaluate(_ results: [NetworkDiagnosticResult]) -> Self? {
        let resultsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        guard Set(resultsByID.keys) == Set(NetworkDiagnosticCheckID.allCases) else {
            return nil
        }

        if resultsByID[.connectivity]?.status == .abnormal {
            return .networkUnavailable
        }
        if resultsByID.values.contains(where: { $0.status != .normal }) {
            return .needsAttention
        }
        return .networkNormal
    }
}
