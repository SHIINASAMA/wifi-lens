import CFNetwork
import Foundation
import Network
import SystemConfiguration

struct NetworkFingerprint: Equatable, Sendable {
    let interfaceType: String?
    let interfaceName: String?
    let pathStatus: NetworkPathState
    let dnsSettingsHash: UInt64
    let staticProxySettingsHash: UInt64
}

protocol NetworkFingerprintMonitoring: Sendable {
    func currentFingerprint() async -> NetworkFingerprint?
    func changes(from baseline: NetworkFingerprint) -> AsyncStream<NetworkFingerprint>
}

struct DisabledNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    func currentFingerprint() async -> NetworkFingerprint? {
        nil
    }

    func changes(from baseline: NetworkFingerprint) -> AsyncStream<NetworkFingerprint> {
        AsyncStream { $0.finish() }
    }
}

protocol NetworkFingerprintSettingsReading: Sendable {
    func dnsSettingsHash() -> UInt64
    func staticProxySettingsHash() -> UInt64
}

struct SystemNetworkFingerprintSettingsReader: NetworkFingerprintSettingsReading {
    private static let dnsKeys: Set<String> = [
        "DomainName", "Options", "SearchDomains", "SearchOrder",
        "ServerAddresses", "ServerPort", "ServerTimeout", "SortList",
        "SupplementalMatchDomains", "SupplementalMatchDomainsNoSearch",
    ]
    private static let staticProxyKeys = [
        "HTTPEnable", "HTTPProxy", "HTTPPort",
        "HTTPSEnable", "HTTPSProxy", "HTTPSPort",
        "SOCKSEnable", "SOCKSProxy", "SOCKSPort",
        "ExceptionsList", "ExcludeSimpleHostnames",
    ]

    func dnsSettingsHash() -> UInt64 {
        let patterns = ["State:/Network/(Global|Service/.+)/DNS"] as CFArray
        let settings = SCDynamicStoreCopyMultiple(nil, nil, patterns) as? [String: Any]
        let dnsSettings = (settings ?? [:]).mapValues { value -> Any in
            guard let dictionary = value as? [String: Any] else { return value }
            return dictionary.filter { Self.dnsKeys.contains($0.key) }
        }
        return StableNetworkSettingsHash.value(for: dnsSettings)
    }

    func staticProxySettingsHash() -> UInt64 {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return StableNetworkSettingsHash.value(for: [:])
        }
        let staticSettings = Dictionary(uniqueKeysWithValues: Self.staticProxyKeys.compactMap { key in
            settings[key].map { (key, $0) }
        })
        return StableNetworkSettingsHash.value(for: staticSettings)
    }
}

struct SystemNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    private let settingsReader: any NetworkFingerprintSettingsReading

    init(
        settingsReader: any NetworkFingerprintSettingsReading = SystemNetworkFingerprintSettingsReader()
    ) {
        self.settingsReader = settingsReader
    }

    func currentFingerprint() async -> NetworkFingerprint? {
        for await fingerprint in fingerprintStream() {
            return fingerprint
        }
        return nil
    }

    func changes(from baseline: NetworkFingerprint) -> AsyncStream<NetworkFingerprint> {
        AsyncStream { continuation in
            let task = Task {
                for await fingerprint in fingerprintStream() {
                    guard !Task.isCancelled else { break }
                    guard fingerprint != baseline else { continue }
                    continuation.yield(fingerprint)
                    continuation.finish()
                    return
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func fingerprintStream() -> AsyncStream<NetworkFingerprint> {
        let monitor = NWPathMonitor()
        let settingsReader = settingsReader
        return AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                let activeInterface = path.availableInterfaces
                    .filter { path.usesInterfaceType($0.type) }
                    .sorted { lhs, rhs in
                        if lhs.type.fingerprintName != rhs.type.fingerprintName {
                            return lhs.type.fingerprintName < rhs.type.fingerprintName
                        }
                        return lhs.name < rhs.name
                    }
                    .first
                continuation.yield(NetworkFingerprint(
                    interfaceType: activeInterface?.type.fingerprintName,
                    interfaceName: activeInterface?.name,
                    pathStatus: path.status.fingerprintState,
                    dnsSettingsHash: settingsReader.dnsSettingsHash(),
                    staticProxySettingsHash: settingsReader.staticProxySettingsHash()
                ))
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(
                label: "io.github.kaoru.wifi-lens.network-diagnostics.fingerprint"
            ))
        }
    }
}

private enum StableNetworkSettingsHash {
    static func value(for value: Any) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in canonical(value).utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func canonical(_ value: Any) -> String {
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().map { key in
                "\(key)=\(canonical(dictionary[key] as Any))"
            }.joined(separator: "|")
        }
        if let dictionary = value as? NSDictionary {
            let swiftDictionary = dictionary.reduce(into: [String: Any]()) { result, item in
                result[String(describing: item.key)] = item.value
            }
            return canonical(swiftDictionary)
        }
        if let array = value as? [Any] {
            return array.map(canonical).joined(separator: ",")
        }
        if let data = value as? Data {
            return data.base64EncodedString()
        }
        return String(describing: value)
    }
}

private extension NWInterface.InterfaceType {
    var fingerprintName: String {
        switch self {
        case .wifi: "wifi"
        case .wiredEthernet: "wiredEthernet"
        case .cellular: "cellular"
        case .loopback: "loopback"
        case .other: "other"
        @unknown default: "unknown"
        }
    }
}

private extension NWPath.Status {
    var fingerprintState: NetworkPathState {
        switch self {
        case .satisfied: .satisfied
        case .unsatisfied: .unsatisfied
        case .requiresConnection: .requiresConnection
        @unknown default: .requiresConnection
        }
    }
}
