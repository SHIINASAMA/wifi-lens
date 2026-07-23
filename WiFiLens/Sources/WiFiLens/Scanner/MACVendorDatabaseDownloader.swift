import Foundation

struct MACVendorHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
    let finalURL: URL
}

protocol MACVendorHTTPTransport: Sendable {
    func fetch(_ request: URLRequest, maximumBytes: Int) async throws -> MACVendorHTTPResponse
}

final class URLSessionMACVendorHTTPTransport: Sendable {
    private let session: URLSession

    init() {
        session = URLSession(configuration: Self.makeConfiguration())
    }

    static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        return configuration
    }

    static func isAllowedIEEEURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host?.lowercased() == "standards-oui.ieee.org"
    }
}

extension URLSessionMACVendorHTTPTransport: MACVendorHTTPTransport {
    func fetch(_ request: URLRequest, maximumBytes: Int) async throws -> MACVendorHTTPResponse {
        let redirectDelegate = MACVendorRedirectDelegate()

        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: redirectDelegate)

            if let rejectedURL = redirectDelegate.rejectedURL {
                bytes.task.cancel()
                throw MACVendorDatabaseError.disallowedRedirect(rejectedURL)
            }

            if response.expectedContentLength > Int64(maximumBytes) {
                bytes.task.cancel()
                throw MACVendorHTTPTransportError.maximumBytesExceeded
            }

            var data = Data()
            if response.expectedContentLength > 0 {
                data.reserveCapacity(min(Int(response.expectedContentLength), maximumBytes))
            }

            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < maximumBytes else {
                    bytes.task.cancel()
                    throw MACVendorHTTPTransportError.maximumBytesExceeded
                }
                data.append(byte)
            }

            if let rejectedURL = redirectDelegate.rejectedURL {
                throw MACVendorDatabaseError.disallowedRedirect(rejectedURL)
            }

            let finalURL = response.url ?? request.url
            guard let finalURL else {
                throw MACVendorHTTPTransportError.missingFinalURL
            }

            return MACVendorHTTPResponse(
                data: data,
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                finalURL: finalURL
            )
        } catch {
            if let rejectedURL = redirectDelegate.rejectedURL {
                throw MACVendorDatabaseError.disallowedRedirect(rejectedURL)
            }
            throw error
        }
    }
}

struct MACVendorDatabaseDownloader: Sendable {
    let transport: any MACVendorHTTPTransport
    let maximumFileBytes: Int

    init(
        transport: any MACVendorHTTPTransport = URLSessionMACVendorHTTPTransport(),
        maximumFileBytes: Int = 16 * 1_024 * 1_024
    ) {
        self.transport = transport
        self.maximumFileBytes = maximumFileBytes
    }

    func downloadAll(
        onCompleted: @Sendable (MACVendorRegistry) async -> Void
    ) async throws -> [MACVendorRegistryInput] {
        try await withThrowingTaskGroup(of: DownloadResult.self) { group in
            for registry in MACVendorRegistry.allCases {
                group.addTask {
                    DownloadResult(
                        registry: registry,
                        input: try await download(registry)
                    )
                }
            }

            var inputsByRegistry: [MACVendorRegistry: MACVendorRegistryInput] = [:]
            for try await result in group {
                inputsByRegistry[result.registry] = result.input
                await onCompleted(result.registry)
            }

            return MACVendorRegistry.allCases.compactMap { inputsByRegistry[$0] }
        }
    }

    private func download(_ registry: MACVendorRegistry) async throws -> MACVendorRegistryInput {
        try Task.checkCancellation()
        let request = makeRequest(for: registry)
        let response: MACVendorHTTPResponse

        do {
            response = try await transport.fetch(request, maximumBytes: maximumFileBytes)
        } catch is CancellationError {
            throw CancellationError()
        } catch where Task.isCancelled {
            throw CancellationError()
        } catch MACVendorHTTPTransportError.maximumBytesExceeded {
            throw MACVendorDatabaseError.fileTooLarge(
                file: registry.downloadURL.lastPathComponent,
                maximumBytes: maximumFileBytes
            )
        } catch let error as MACVendorDatabaseError {
            throw error
        } catch {
            throw MACVendorDatabaseError.downloadFailed(registry)
        }

        guard URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(response.finalURL) else {
            throw MACVendorDatabaseError.disallowedRedirect(response.finalURL)
        }
        guard response.statusCode == 200 else {
            throw MACVendorDatabaseError.invalidHTTPStatus(
                registry: registry,
                statusCode: response.statusCode
            )
        }
        guard response.data.count <= maximumFileBytes else {
            throw MACVendorDatabaseError.fileTooLarge(
                file: registry.downloadURL.lastPathComponent,
                maximumBytes: maximumFileBytes
            )
        }

        return MACVendorRegistryInput(
            displayName: registry.downloadURL.lastPathComponent,
            data: response.data
        )
    }

    private func makeRequest(for registry: MACVendorRegistry) -> URLRequest {
        var request = URLRequest(url: registry.downloadURL)
        request.httpMethod = "GET"
        request.httpBody = nil
        request.setValue("text/csv, application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
        return "WiFiLens/\(version) (+https://github.com/SHIINASAMA/wifi-lens)"
    }()

    private struct DownloadResult: Sendable {
        let registry: MACVendorRegistry
        let input: MACVendorRegistryInput
    }
}

private final class MACVendorRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var storedRejectedURL: URL?

    var rejectedURL: URL? {
        lock.withLock { storedRejectedURL }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, URLSessionMACVendorHTTPTransport.isAllowedIEEEURL(url) else {
            lock.withLock {
                storedRejectedURL = request.url
            }
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

private enum MACVendorHTTPTransportError: Error {
    case maximumBytesExceeded
    case missingFinalURL
}
