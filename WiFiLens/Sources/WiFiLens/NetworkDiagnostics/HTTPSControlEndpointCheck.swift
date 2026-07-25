import Foundation

protocol ControlEndpointLoading: Sendable {
    func load(
        url: URL,
        timeout: Duration
    ) async -> (status: Int?, body: String?, errorCode: String?)
}

struct SystemControlEndpointLoader: ControlEndpointLoading {
    static func configuration(timeout: Duration) -> URLSessionConfiguration {
        let timeoutInterval = timeout.controlEndpointTimeInterval
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        return configuration
    }

    func load(
        url: URL,
        timeout: Duration
    ) async -> (status: Int?, body: String?, errorCode: String?) {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout.controlEndpointTimeInterval
        )
        request.httpMethod = "GET"

        let session = URLSession(
            configuration: Self.configuration(timeout: timeout),
            delegate: ControlEndpointRedirectDelegate(),
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return (nil, nil, "non-http-response")
            }
            return (response.statusCode, String(data: data, encoding: .utf8), nil)
        } catch let error as URLError {
            return (nil, nil, String(error.code.rawValue))
        } catch {
            return (nil, nil, String(describing: type(of: error)))
        }
    }
}

struct HTTPSControlEndpointCheck: DiagnosticCheck {
    static let stableHTTPSEndpoint = URL(string: "https://www.apple.com/")!

    let id = NetworkDiagnosticCheckID.internet
    let httpsEndpoint = Self.stableHTTPSEndpoint
    let captivePortalEndpoint = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
    let expectedCaptivePortalBody = "Microsoft Connect Test"

    private let loader: any ControlEndpointLoading
    private let timeout: Duration

    init(
        loader: any ControlEndpointLoading = SystemControlEndpointLoader(),
        timeout: Duration = .seconds(5)
    ) {
        self.loader = loader
        self.timeout = timeout
    }

    func run() async -> NetworkDiagnosticResult {
        let httpsResponse = await loader.load(url: httpsEndpoint, timeout: timeout)
        let captivePortalResponse = await loader.load(url: captivePortalEndpoint, timeout: timeout)
        let httpsEvaluation = evaluateHTTPS(httpsResponse)
        let captivePortalEvaluation = evaluateCaptivePortal(captivePortalResponse)
        let status: NetworkDiagnosticStatus
        if httpsEvaluation.succeeded && captivePortalEvaluation.succeeded {
            status = .normal
        } else if httpsEvaluation.succeeded && captivePortalEvaluation.isIndeterminate {
            status = .indeterminate
        } else {
            status = .abnormal
        }

        return NetworkDiagnosticResult(
            id: id,
            status: status,
            summary: localizedSummary(for: status),
            detail: localizedDetail(for: status),
            evidence: [httpsEvaluation.evidence, captivePortalEvaluation.evidence]
        )
    }

    private func evaluateHTTPS(
        _ response: (status: Int?, body: String?, errorCode: String?)
    ) -> EndpointEvaluation {
        if let errorCode = response.errorCode {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "https.transport-error", value: errorCode)
            )
        }
        guard let status = response.status else {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "https.transport-error", value: "unknown")
            )
        }
        guard (200..<300).contains(status) else {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "https.http-status", value: String(status))
            )
        }
        return EndpointEvaluation(
            succeeded: true,
            evidence: .init(code: "https.available", value: String(status))
        )
    }

    private func evaluateCaptivePortal(
        _ response: (status: Int?, body: String?, errorCode: String?)
    ) -> EndpointEvaluation {
        if let errorCode = response.errorCode {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "captive-portal.transport-error", value: errorCode),
                isIndeterminate: errorCode == String(URLError.timedOut.rawValue)
            )
        }
        guard let status = response.status else {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "captive-portal.transport-error", value: "unknown")
            )
        }
        if (300..<400).contains(status) {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "captive-portal.redirect", value: String(status))
            )
        }
        guard status == 200 else {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "captive-portal.http-status", value: String(status))
            )
        }
        guard response.body == expectedCaptivePortalBody else {
            return EndpointEvaluation(
                succeeded: false,
                evidence: .init(code: "captive-portal.suspected", value: nil)
            )
        }
        return EndpointEvaluation(
            succeeded: true,
            evidence: .init(code: "captive-portal.clear", value: nil)
        )
    }

    private func localizedSummary(for status: NetworkDiagnosticStatus) -> String {
        switch status {
        case .normal:
            String(localized: "network_diagnostics.internet.normal.summary", comment: "Network self-check HTTPS control endpoint result summary")
        case .indeterminate:
            String(localized: "network_diagnostics.internet.indeterminate.summary", comment: "Network self-check HTTPS control endpoint result summary")
        case .abnormal, .blocked, .skipped:
            String(localized: "network_diagnostics.internet.abnormal.summary", comment: "Network self-check HTTPS control endpoint result summary")
        }
    }

    private func localizedDetail(for status: NetworkDiagnosticStatus) -> String {
        switch status {
        case .normal:
            String(localized: "network_diagnostics.internet.normal.detail", comment: "Network self-check HTTPS control endpoint result detail")
        case .indeterminate:
            String(localized: "network_diagnostics.internet.indeterminate.detail", comment: "Network self-check HTTPS control endpoint result detail")
        case .abnormal, .blocked, .skipped:
            String(localized: "network_diagnostics.internet.abnormal.detail", comment: "Network self-check HTTPS control endpoint result detail")
        }
    }
}

private struct EndpointEvaluation {
    let succeeded: Bool
    let evidence: NetworkDiagnosticEvidence
    let isIndeterminate: Bool

    init(
        succeeded: Bool,
        evidence: NetworkDiagnosticEvidence,
        isIndeterminate: Bool = false
    ) {
        self.succeeded = succeeded
        self.evidence = evidence
        self.isIndeterminate = isIndeterminate
    }
}

private final class ControlEndpointRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private extension Duration {
    var controlEndpointTimeInterval: TimeInterval {
        let components = self.components
        return max(
            0.001,
            Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        )
    }
}
