import Foundation
import Testing
@testable import WiFi_Lens

struct MACVendorDatabaseDownloaderTests {
    @Test func downloadsOnlyTheFourFixedRegistryURLs() async throws {
        let transport = RecordingMACVendorHTTPTransport(responses: validResponses())
        let downloader = MACVendorDatabaseDownloader(transport: transport)

        let inputs = try await downloader.downloadAll { _ in }
        let requests = await transport.requests

        #expect(inputs.count == 4)
        #expect(inputs.map(\.displayName) == ["oui.csv", "mam.csv", "oui36.csv", "iab.csv"])
        #expect(Set(requests.compactMap(\.url)) == Set(MACVendorRegistry.allCases.map(\.downloadURL)))
        #expect(requests.allSatisfy { request in
            request.httpMethod == "GET"
                && request.httpBody == nil
                && request.value(forHTTPHeaderField: "Cookie") == nil
        })
        #expect(await transport.maximumByteLimits == Array(repeating: 16 * 1_024 * 1_024, count: 4))
    }

    @Test func sendsOnlyRequiredStaticHeadersAndNoScanData() async throws {
        let transport = RecordingMACVendorHTTPTransport(responses: validResponses())
        let downloader = MACVendorDatabaseDownloader(transport: transport)

        _ = try await downloader.downloadAll { _ in }

        for request in await transport.requests {
            #expect(request.value(forHTTPHeaderField: "Accept") == "text/csv, application/octet-stream")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
            let userAgent = request.value(forHTTPHeaderField: "User-Agent")
            #expect(userAgent?.hasPrefix("WiFiLens/") == true)
            #expect(userAgent?.hasSuffix(" (+https://github.com/SHIINASAMA/wifi-lens)") == true)

            let serializedRequest = [
                request.url?.absoluteString,
                request.allHTTPHeaderFields?.description,
                request.httpBody.flatMap { String(data: $0, encoding: .utf8) },
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            #expect(!serializedRequest.contains("Nearby Network"))
            #expect(!serializedRequest.contains("AA:BB:CC:DD:EE:FF"))
            #expect(!serializedRequest.contains("-42"))
        }
    }

    @Test func startsAllRegistryDownloadsWithoutWaitingForEarlierFiles() async {
        let transport = BlockingMACVendorHTTPTransport()
        let downloader = MACVendorDatabaseDownloader(transport: transport)
        let task = Task {
            try await downloader.downloadAll { _ in }
        }

        try? await Task.sleep(for: .milliseconds(100))

        #expect(await transport.startedCount == MACVendorRegistry.allCases.count)
        task.cancel()
        _ = try? await task.value
    }

    @Test func reportsEveryCompletedRegistry() async throws {
        let transport = RecordingMACVendorHTTPTransport(responses: validResponses())
        let completions = RegistryCompletionRecorder()
        let downloader = MACVendorDatabaseDownloader(transport: transport)

        _ = try await downloader.downloadAll { registry in
            await completions.append(registry)
        }

        #expect(Set(await completions.registries) == Set(MACVendorRegistry.allCases))
        #expect(await completions.registries.count == MACVendorRegistry.allCases.count)
    }

    @Test func rejectsNonOKResponseAndCancelsTheDownloadGroup() async {
        let transport = FailingAndSuspendingMACVendorHTTPTransport()
        let downloader = MACVendorDatabaseDownloader(transport: transport)
        let clock = ContinuousClock()
        let startedAt = clock.now

        do {
            _ = try await downloader.downloadAll { _ in }
            Issue.record("Expected status 503 to be rejected")
        } catch let error as MACVendorDatabaseError {
            #expect(error == .invalidHTTPStatus(registry: .maL, statusCode: 503))
        } catch {
            Issue.record("Unexpected HTTP status error: \(error)")
        }

        // Leave enough headroom for a loaded CI runner while still proving that
        // the downloader does not wait for the suspended peer requests.
        #expect(clock.now - startedAt < .seconds(5))
        #expect(await transport.startedCount == MACVendorRegistry.allCases.count)
        #expect(await transport.cancelledCount == MACVendorRegistry.allCases.count - 1)
    }

    @Test func rejectsResponseOverPerFileLimit() async {
        var responses = Dictionary(uniqueKeysWithValues: MACVendorRegistry.allCases.map { registry in
            (
                registry.downloadURL,
                MACVendorHTTPResponse(
                    data: Data([0x41]),
                    statusCode: 200,
                    finalURL: registry.downloadURL
                )
            )
        })
        responses[MACVendorRegistry.maL.downloadURL] = MACVendorHTTPResponse(
            data: Data(repeating: 0x41, count: 17),
            statusCode: 200,
            finalURL: MACVendorRegistry.maL.downloadURL
        )
        let transport = RecordingMACVendorHTTPTransport(responses: responses)
        let downloader = MACVendorDatabaseDownloader(transport: transport, maximumFileBytes: 16)

        do {
            _ = try await downloader.downloadAll { _ in }
            Issue.record("Expected an oversized response to be rejected")
        } catch let error as MACVendorDatabaseError {
            #expect(error == .fileTooLarge(file: "oui.csv", maximumBytes: 16))
        } catch {
            Issue.record("Unexpected response-size error: \(error)")
        }

        #expect(await transport.maximumByteLimits == Array(repeating: 16, count: 4))
    }

    @Test func rejectsAggregateResponsesOverTotalDownloadLimit() async {
        let responses = Dictionary(uniqueKeysWithValues: MACVendorRegistry.allCases.map { registry in
            (
                registry.downloadURL,
                MACVendorHTTPResponse(
                    data: Data(repeating: 0x41, count: 9),
                    statusCode: 200,
                    finalURL: registry.downloadURL
                )
            )
        })
        let transport = RecordingMACVendorHTTPTransport(responses: responses)
        let downloader = MACVendorDatabaseDownloader(
            transport: transport,
            maximumFileBytes: 16,
            maximumTotalBytes: 32
        )

        do {
            _ = try await downloader.downloadAll { _ in }
            Issue.record("Expected aggregate download size to be rejected")
        } catch let error as MACVendorDatabaseError {
            #expect(error == .totalSizeExceeded(maximumBytes: 32))
        } catch {
            Issue.record("Unexpected aggregate-size error: \(error)")
        }
    }

    @Test func concurrentFailuresUseStableRegistryPriority() async {
        let transport = OrderedFailureMACVendorHTTPTransport()
        let downloader = MACVendorDatabaseDownloader(transport: transport)

        do {
            _ = try await downloader.downloadAll { _ in }
            Issue.record("Expected registry download failures")
        } catch let error as MACVendorDatabaseError {
            #expect(error == .invalidHTTPStatus(registry: .maL, statusCode: 503))
        } catch {
            Issue.record("Unexpected concurrent failure: \(error)")
        }
    }

    @Test func rejectsDisallowedFinalHost() async {
        var responses = validResponses()
        responses[MACVendorRegistry.maL.downloadURL] = MACVendorHTTPResponse(
            data: fixtureCSV,
            statusCode: 200,
            finalURL: URL(string: "https://example.com/oui.csv")!
        )
        let transport = RecordingMACVendorHTTPTransport(responses: responses)
        let downloader = MACVendorDatabaseDownloader(transport: transport)

        do {
            _ = try await downloader.downloadAll { _ in }
            Issue.record("Expected a disallowed final host to be rejected")
        } catch let error as MACVendorDatabaseError {
            #expect(error == .disallowedRedirect(URL(string: "https://example.com/oui.csv")!))
        } catch {
            Issue.record("Unexpected redirect error: \(error)")
        }
    }

    @Test func cancellationStopsTheActiveDownload() async {
        let transport = SuspendingMACVendorHTTPTransport()
        let downloader = MACVendorDatabaseDownloader(transport: transport)
        let task = Task {
            try await downloader.downloadAll { _ in }
        }

        await transport.waitUntilFetchStarts()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected the active download to be cancelled")
        } catch is CancellationError {
            // Expected cancellation path.
        } catch {
            Issue.record("Unexpected cancellation error: \(error)")
        }
    }

    @Test func productionSessionConfigurationDoesNotPersistRequestState() {
        let configuration = URLSessionMACVendorHTTPTransport.makeConfiguration()

        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.timeoutIntervalForRequest == 60)
        #expect(configuration.timeoutIntervalForResource == 300)
    }

    @Test func productionURLPolicyAllowsOnlyHTTPSOnTheIEEERegistryHost() {
        #expect(URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(
            URL(string: "https://standards-oui.ieee.org/oui/oui.csv")!
        ))
        #expect(!URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(
            URL(string: "http://standards-oui.ieee.org/oui/oui.csv")!
        ))
        #expect(!URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(
            URL(string: "https://standards-oui.ieee.org.example.com/oui.csv")!
        ))
        #expect(!URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(
            URL(string: "https://user@standards-oui.ieee.org/oui/oui.csv")!
        ))
        #expect(!URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(
            URL(string: "https://standards-oui.ieee.org:444/oui/oui.csv")!
        ))
    }

    @Test func productionTransportPreservesChunkedResponseData() async throws {
        let url = productionTestURL("chunked")
        MACVendorStubURLProtocol.register(url: url) { stub in
            stub.respond(chunks: [Data("alpha".utf8), Data("beta".utf8)])
        }
        defer { MACVendorStubURLProtocol.unregister(url: url) }

        let response = try await productionTransport().fetch(
            URLRequest(url: url),
            maximumBytes: 32,
            byteBudget: MACVendorDownloadByteBudget(maximumBytes: 32)
        )

        #expect(response.data == Data("alphabeta".utf8))
        #expect(response.statusCode == 200)
        #expect(response.finalURL == url)
    }

    @Test func productionTransportEnforcesPerFileLimitWhileReceiving() async {
        let url = productionTestURL("file-limit")
        MACVendorStubURLProtocol.register(url: url) { stub in
            stub.respond(chunks: [Data(repeating: 0x41, count: 6), Data(repeating: 0x42, count: 6)])
        }
        defer { MACVendorStubURLProtocol.unregister(url: url) }

        do {
            _ = try await productionTransport().fetch(
                URLRequest(url: url),
                maximumBytes: 8,
                byteBudget: MACVendorDownloadByteBudget(maximumBytes: 32)
            )
            Issue.record("Expected production transport to enforce its per-file limit")
        } catch MACVendorHTTPTransportError.maximumBytesExceeded {
            // Expected.
        } catch {
            Issue.record("Unexpected per-file transport error: \(error)")
        }
    }

    @Test func productionTransportEnforcesAggregateLimitWhileReceiving() async {
        let url = productionTestURL("aggregate-limit")
        MACVendorStubURLProtocol.register(url: url) { stub in
            stub.respond(chunks: [Data(repeating: 0x41, count: 6), Data(repeating: 0x42, count: 6)])
        }
        defer { MACVendorStubURLProtocol.unregister(url: url) }

        do {
            _ = try await productionTransport().fetch(
                URLRequest(url: url),
                maximumBytes: 16,
                byteBudget: MACVendorDownloadByteBudget(maximumBytes: 8)
            )
            Issue.record("Expected production transport to enforce the aggregate limit")
        } catch MACVendorHTTPTransportError.totalBytesExceeded(8) {
            // Expected.
        } catch {
            Issue.record("Unexpected aggregate transport error: \(error)")
        }
    }

    @Test func productionTransportPropagatesMidResponseFailure() async {
        let url = productionTestURL("mid-response-failure")
        MACVendorStubURLProtocol.register(url: url) { stub in
            stub.respond(chunks: [Data("partial".utf8)], finish: false)
            stub.fail(with: URLError(.networkConnectionLost))
        }
        defer { MACVendorStubURLProtocol.unregister(url: url) }

        do {
            _ = try await productionTransport().fetch(
                URLRequest(url: url),
                maximumBytes: 32,
                byteBudget: MACVendorDownloadByteBudget(maximumBytes: 32)
            )
            Issue.record("Expected the mid-response failure to propagate")
        } catch let error as URLError {
            #expect(error.code == .networkConnectionLost)
        } catch {
            Issue.record("Unexpected mid-response error: \(error)")
        }
    }

    @Test func productionTransportCancellationStopsLoading() async {
        let url = productionTestURL("cancellation")
        let stopped = LockedFlag()
        MACVendorStubURLProtocol.register(url: url) { stub in
            stub.onStop = { stopped.set() }
            stub.respond(chunks: [Data("partial".utf8)], finish: false)
        }
        defer { MACVendorStubURLProtocol.unregister(url: url) }
        let transport = productionTransport()
        let task = Task {
            try await transport.fetch(
                URLRequest(url: url),
                maximumBytes: 32,
                byteBudget: MACVendorDownloadByteBudget(maximumBytes: 32)
            )
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = try? await task.value

        for _ in 0..<20 where !stopped.value {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(stopped.value)
    }

}

private actor RecordingMACVendorHTTPTransport: MACVendorHTTPTransport {
    private let responses: [URL: MACVendorHTTPResponse]
    private(set) var requests: [URLRequest] = []
    private(set) var maximumByteLimits: [Int] = []

    init(responses: [URL: MACVendorHTTPResponse]) {
        self.responses = responses
    }

    var requestedURLs: [URL?] {
        requests.map(\.url)
    }

    func fetch(
        _ request: URLRequest,
        maximumBytes: Int,
        byteBudget: MACVendorDownloadByteBudget
    ) async throws -> MACVendorHTTPResponse {
        requests.append(request)
        maximumByteLimits.append(maximumBytes)
        guard let url = request.url, let response = responses[url] else {
            throw RecordingTransportError.missingResponse
        }
        try byteBudget.consume(response.data.count)
        return response
    }
}

private actor SuspendingMACVendorHTTPTransport: MACVendorHTTPTransport {
    private var fetchStarted = false
    private var startContinuation: CheckedContinuation<Void, Never>?

    func fetch(
        _ request: URLRequest,
        maximumBytes: Int,
        byteBudget: MACVendorDownloadByteBudget
    ) async throws -> MACVendorHTTPResponse {
        fetchStarted = true
        startContinuation?.resume()
        startContinuation = nil
        do {
            try await Task.sleep(for: .seconds(60))
        } catch is CancellationError {
            throw URLError(.cancelled)
        }
        throw RecordingTransportError.unexpectedResume
    }

    func waitUntilFetchStarts() async {
        guard !fetchStarted else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }
}

private actor BlockingMACVendorHTTPTransport: MACVendorHTTPTransport {
    private(set) var startedCount = 0

    func fetch(
        _ request: URLRequest,
        maximumBytes: Int,
        byteBudget: MACVendorDownloadByteBudget
    ) async throws -> MACVendorHTTPResponse {
        startedCount += 1
        try await Task.sleep(for: .seconds(60))
        throw RecordingTransportError.unexpectedResume
    }
}

private actor FailingAndSuspendingMACVendorHTTPTransport: MACVendorHTTPTransport {
    private(set) var startedCount = 0
    private(set) var cancelledCount = 0

    func fetch(
        _ request: URLRequest,
        maximumBytes: Int,
        byteBudget: MACVendorDownloadByteBudget
    ) async throws -> MACVendorHTTPResponse {
        startedCount += 1
        let url = try #require(request.url)
        let registry = try #require(MACVendorRegistry.allCases.first { $0.downloadURL == url })
        if registry == .maL {
            return response(for: registry, statusCode: 503)
        }
        do {
            try await Task.sleep(for: .seconds(30))
            return response(for: registry)
        } catch is CancellationError {
            cancelledCount += 1
            throw CancellationError()
        }
    }
}

private actor OrderedFailureMACVendorHTTPTransport: MACVendorHTTPTransport {
    func fetch(
        _ request: URLRequest,
        maximumBytes: Int,
        byteBudget: MACVendorDownloadByteBudget
    ) async throws -> MACVendorHTTPResponse {
        let url = try #require(request.url)
        let registry = try #require(MACVendorRegistry.allCases.first { $0.downloadURL == url })
        if registry == .maL {
            try await Task.sleep(for: .milliseconds(50))
            return response(for: registry, statusCode: 503)
        }
        if registry == .maM {
            return response(for: registry, statusCode: 502)
        }
        return response(for: registry)
    }
}

private actor RegistryCompletionRecorder {
    private(set) var registries: [MACVendorRegistry] = []

    func append(_ registry: MACVendorRegistry) {
        registries.append(registry)
    }
}

private enum RecordingTransportError: Error {
    case missingResponse
    case unexpectedResume
}

private final class MACVendorStubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (MACVendorStubURLProtocol) -> Void

    private static let handlersLock = NSLock()
    nonisolated(unsafe) private static var handlers: [URL: Handler] = [:]

    private let stateLock = NSLock()
    private var stopped = false
    var onStop: (@Sendable () -> Void)?

    static func register(url: URL, handler: @escaping Handler) {
        handlersLock.withLock { handlers[url] = handler }
    }

    static func unregister(url: URL) {
        handlersLock.withLock { handlers[url] = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return handlersLock.withLock { handlers[url] != nil }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let handler = Self.handlersLock.withLock({ Self.handlers[url] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        handler(self)
    }

    override func stopLoading() {
        stateLock.withLock { stopped = true }
        onStop?()
    }

    func respond(chunks: [Data], finish: Bool = true) {
        guard !isStopped, let url = request.url else { return }
        let length = chunks.reduce(0) { $0 + $1.count }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": String(length)]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in chunks where !isStopped {
            client?.urlProtocol(self, didLoad: chunk)
        }
        if finish, !isStopped { client?.urlProtocolDidFinishLoading(self) }
    }

    func fail(with error: Error) {
        guard !isStopped else { return }
        client?.urlProtocol(self, didFailWithError: error)
    }

    private var isStopped: Bool {
        stateLock.withLock { stopped }
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool { lock.withLock { storedValue } }
    func set() { lock.withLock { storedValue = true } }
}

private func productionTestURL(_ name: String) -> URL {
    URL(string: "https://standards-oui.ieee.org/codex-tests/\(name).csv")!
}

private func productionTransport() -> URLSessionMACVendorHTTPTransport {
    let configuration = URLSessionMACVendorHTTPTransport.makeConfiguration()
    configuration.protocolClasses = [MACVendorStubURLProtocol.self]
    return URLSessionMACVendorHTTPTransport(configuration: configuration)
}

private let fixtureCSV = Data("Registry,Assignment,Organization Name\nMA-L,001122,Example Networks\n".utf8)

private func response(
    for registry: MACVendorRegistry,
    statusCode: Int = 200,
    finalURL: URL? = nil
) -> MACVendorHTTPResponse {
    MACVendorHTTPResponse(
        data: fixtureCSV,
        statusCode: statusCode,
        finalURL: finalURL ?? registry.downloadURL
    )
}

private func validResponses() -> [URL: MACVendorHTTPResponse] {
    Dictionary(uniqueKeysWithValues: MACVendorRegistry.allCases.map { registry in
        (registry.downloadURL, response(for: registry))
    })
}
