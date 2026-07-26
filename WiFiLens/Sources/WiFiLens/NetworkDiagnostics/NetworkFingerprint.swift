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

struct NetworkPathFingerprint: Equatable, Sendable {
    let interfaceType: String?
    let interfaceName: String?
    let pathStatus: NetworkPathState
}

protocol NetworkPathFingerprintSourcing: Sendable {
    func currentPathFingerprint() async -> NetworkPathFingerprint?
    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint>
}

protocol NetworkFingerprintSettingsPolling: Sendable {
    func ticks(every interval: Duration) -> AsyncStream<Void>
}

struct SystemNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { break }
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct SystemNetworkPathFingerprintSource: NetworkPathFingerprintSourcing {
    func currentPathFingerprint() async -> NetworkPathFingerprint? {
        for await fingerprint in pathFingerprintStream() {
            return fingerprint
        }
        return nil
    }

    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        pathFingerprintStream()
    }

    private func pathFingerprintStream() -> AsyncStream<NetworkPathFingerprint> {
        let monitor = NWPathMonitor()
        return AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(Self.fingerprint(for: path))
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(
                label: "io.github.kaoru.wifi-lens.network-diagnostics.fingerprint-path"
            ))
        }
    }

    private static func fingerprint(for path: NWPath) -> NetworkPathFingerprint {
        let activeInterface = path.availableInterfaces
            .filter { path.usesInterfaceType($0.type) }
            .sorted { lhs, rhs in
                if lhs.type.fingerprintName != rhs.type.fingerprintName {
                    return lhs.type.fingerprintName < rhs.type.fingerprintName
                }
                return lhs.name < rhs.name
            }
            .first
        return NetworkPathFingerprint(
            interfaceType: activeInterface?.type.fingerprintName,
            interfaceName: activeInterface?.name,
            pathStatus: path.status.fingerprintState
        )
    }
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
        "ProxyAutoConfigEnable", "ProxyAutoConfigURLString", "ProxyAutoDiscoveryEnable",
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
            return Self.proxySettingsHash(for: [:])
        }
        return Self.proxySettingsHash(for: settings)
    }

    static func proxySettingsHash(for settings: [String: Any]) -> UInt64 {
        let staticSettings = Dictionary(uniqueKeysWithValues: Self.staticProxyKeys.compactMap { key in
            settings[key].map { (key, $0) }
        })
        return StableNetworkSettingsHash.value(for: staticSettings)
    }
}

struct SystemNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    private let settingsReader: any NetworkFingerprintSettingsReading
    private let pathSource: any NetworkPathFingerprintSourcing
    private let settingsPoller: any NetworkFingerprintSettingsPolling
    private let settingsPollInterval: Duration

    init(
        settingsReader: any NetworkFingerprintSettingsReading = SystemNetworkFingerprintSettingsReader(),
        pathSource: any NetworkPathFingerprintSourcing = SystemNetworkPathFingerprintSource(),
        settingsPoller: any NetworkFingerprintSettingsPolling = SystemNetworkFingerprintSettingsPoller(),
        settingsPollInterval: Duration = .milliseconds(250)
    ) {
        self.settingsReader = settingsReader
        self.pathSource = pathSource
        self.settingsPoller = settingsPoller
        self.settingsPollInterval = settingsPollInterval
    }

    func currentFingerprint() async -> NetworkFingerprint? {
        guard let path = await pathSource.currentPathFingerprint() else { return nil }
        return fingerprint(path: path)
    }

    func changes(from baseline: NetworkFingerprint) -> AsyncStream<NetworkFingerprint> {
        AsyncStream { continuation in
            let emissionState = NetworkFingerprintEmissionState(baseline: baseline)
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await path in pathSource.pathFingerprintChanges() {
                            guard !Task.isCancelled else { return }
                            let fingerprint = fingerprint(path: path)
                            if await emissionState.shouldEmitPath(fingerprint) {
                                continuation.yield(fingerprint)
                            }
                        }
                    }
                    group.addTask {
                        for await _ in settingsPoller.ticks(every: settingsPollInterval) {
                            guard !Task.isCancelled else { return }
                            let fingerprint = fingerprint(
                                path: NetworkPathFingerprint(
                                    interfaceType: baseline.interfaceType,
                                    interfaceName: baseline.interfaceName,
                                    pathStatus: baseline.pathStatus
                                )
                            )
                            if await emissionState.shouldEmitSettings(fingerprint) {
                                continuation.yield(fingerprint)
                            }
                        }
                    }
                    await group.waitForAll()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func fingerprint(path: NetworkPathFingerprint) -> NetworkFingerprint {
        NetworkFingerprint(
            interfaceType: path.interfaceType,
            interfaceName: path.interfaceName,
            pathStatus: path.pathStatus,
            dnsSettingsHash: settingsReader.dnsSettingsHash(),
            staticProxySettingsHash: settingsReader.staticProxySettingsHash()
        )
    }
}

private actor NetworkFingerprintEmissionState {
    private let baseline: NetworkFingerprint
    private var lastEmitted: NetworkFingerprint
    private var receivedInitialPath = false

    init(baseline: NetworkFingerprint) {
        self.baseline = baseline
        self.lastEmitted = baseline
    }

    func shouldEmitPath(_ fingerprint: NetworkFingerprint) -> Bool {
        if !receivedInitialPath {
            receivedInitialPath = true
            guard !fingerprint.hasSamePath(as: baseline) else { return false }
        }
        lastEmitted = fingerprint
        return true
    }

    func shouldEmitSettings(_ fingerprint: NetworkFingerprint) -> Bool {
        guard
            fingerprint.dnsSettingsHash != lastEmitted.dnsSettingsHash
                || fingerprint.staticProxySettingsHash != lastEmitted.staticProxySettingsHash
        else {
            return false
        }
        lastEmitted = fingerprint
        return true
    }
}

private extension NetworkFingerprint {
    func hasSamePath(as other: NetworkFingerprint) -> Bool {
        interfaceType == other.interfaceType
            && interfaceName == other.interfaceName
            && pathStatus == other.pathStatus
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
