import Foundation

enum NetworkDiagnosticStatus: String, CaseIterable, Equatable, Sendable {
    case normal, abnormal, indeterminate, blocked, skipped
}

enum NetworkDiagnosticCheckID: String, CaseIterable, Equatable, Hashable, Sendable {
    case path, dns, internet, ipv6, proxy
}

enum NetworkDiagnosticStatusTone: Equatable, Sendable {
    case success
    case error
    case caution
    case informational
    case muted
}

struct NetworkDiagnosticStatusPresentation: Equatable, Sendable {
    let labelKey: String
    let icon: String
    let tone: NetworkDiagnosticStatusTone
}

extension NetworkDiagnosticStatus {
    var presentation: NetworkDiagnosticStatusPresentation {
        switch self {
        case .normal:
            .init(labelKey: "network_diagnostics.status.normal", icon: "checkmark.circle.fill", tone: .success)
        case .abnormal:
            .init(labelKey: "network_diagnostics.status.abnormal", icon: "xmark.circle.fill", tone: .error)
        case .indeterminate:
            .init(labelKey: "network_diagnostics.status.indeterminate", icon: "questionmark.circle.fill", tone: .caution)
        case .blocked:
            .init(labelKey: "network_diagnostics.status.blocked", icon: "lock.fill", tone: .informational)
        case .skipped:
            .init(labelKey: "network_diagnostics.status.skipped", icon: "forward.fill", tone: .muted)
        }
    }
}

struct NetworkDiagnosticEvidence: Equatable, Sendable {
    let code: String
    let value: String?
}

struct NetworkDiagnosticResult: Equatable, Identifiable, Sendable {
    let id: NetworkDiagnosticCheckID
    let status: NetworkDiagnosticStatus
    let summary: String
    let detail: String?
    let evidence: [NetworkDiagnosticEvidence]

    init(
        id: NetworkDiagnosticCheckID,
        status: NetworkDiagnosticStatus,
        summary: String,
        detail: String? = nil,
        evidence: [NetworkDiagnosticEvidence] = []
    ) {
        self.id = id
        self.status = status
        self.summary = summary
        self.detail = detail
        self.evidence = evidence
    }

    static func blocked(id: NetworkDiagnosticCheckID, summary: String) -> Self {
        .init(id: id, status: .blocked, summary: summary, detail: summary)
    }
}

enum NetworkDiagnosticConclusion: String, Equatable, Sendable {
    case networkNormal
    case needsAttention
    case networkUnavailable

    static func evaluate(
        _ results: [NetworkDiagnosticResult],
        requiredIDs: Set<NetworkDiagnosticCheckID> = Set(NetworkDiagnosticCheckID.allCases)
    ) -> Self? {
        let resultsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        guard Set(resultsByID.keys) == requiredIDs else {
            return nil
        }

        if resultsByID[.path]?.status == .abnormal {
            return .networkUnavailable
        }
        if let internet = resultsByID[.internet],
           internet.status == .abnormal,
           !internet.evidence.contains(where: { $0.code == "https.available" }),
           !hasAvailableHTTPSProxy(resultsByID[.proxy]),
           internet.evidence.contains(where: { $0.code == "https.connectivity-error" }) {
            return .networkUnavailable
        }
        if resultsByID.values.contains(where: { result in
            result.status != .normal
                && !(result.id == .ipv6 && result.status == .skipped)
                && !isUnverifiedDirectRouteNeutral(
                    result,
                    internet: resultsByID[.internet]
                )
        }) {
            return .needsAttention
        }
        return .networkNormal
    }

    private static func hasAvailableHTTPSProxy(_ result: NetworkDiagnosticResult?) -> Bool {
        guard result?.status == .normal else { return false }
        return result?.evidence.contains { evidence in
            guard evidence.code == "proxy.https.egress-status",
                  let value = evidence.value,
                  let statusCode = Int(value) else {
                return false
            }
            return (200..<300).contains(statusCode)
        } == true
    }

    private static func isUnverifiedDirectRouteNeutral(
        _ result: NetworkDiagnosticResult,
        internet: NetworkDiagnosticResult?
    ) -> Bool {
        result.id == .proxy
            && result.status == .indeterminate
            && internet?.status == .normal
            && result.evidence.contains { evidence in
                evidence.code.hasSuffix(".egress-status") && evidence.value == "base-check"
            }
    }
}
