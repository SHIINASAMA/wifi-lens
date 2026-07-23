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
        var responses = validResponses()
        responses[MACVendorRegistry.maM.downloadURL] = response(
            for: .maM,
            statusCode: 503
        )
        let transport = RecordingMACVendorHTTPTransport(responses: responses)
        let downloader = MACVendorDatabaseDownloader(transport: transport)

        do {
            _ = try await downloader.downloadAll { _ in }
            Issue.record("Expected status 503 to be rejected")
        } catch let error as MACVendorDatabaseError {
            #expect(error == .invalidHTTPStatus(registry: .maM, statusCode: 503))
        } catch {
            Issue.record("Unexpected HTTP status error: \(error)")
        }

        #expect(Set(await transport.requestedURLs.compactMap { $0 }) == Set(
            MACVendorRegistry.allCases.map(\.downloadURL)
        ))
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

    func fetch(_ request: URLRequest, maximumBytes: Int) async throws -> MACVendorHTTPResponse {
        requests.append(request)
        maximumByteLimits.append(maximumBytes)
        guard let url = request.url, let response = responses[url] else {
            throw RecordingTransportError.missingResponse
        }
        return response
    }
}

private actor SuspendingMACVendorHTTPTransport: MACVendorHTTPTransport {
    private var fetchStarted = false
    private var startContinuation: CheckedContinuation<Void, Never>?

    func fetch(_ request: URLRequest, maximumBytes: Int) async throws -> MACVendorHTTPResponse {
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

    func fetch(_ request: URLRequest, maximumBytes: Int) async throws -> MACVendorHTTPResponse {
        startedCount += 1
        try await Task.sleep(for: .seconds(60))
        throw RecordingTransportError.unexpectedResume
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
