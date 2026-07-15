import Testing
@testable import WiFi_Lens

@Suite("Network diagnostics models and runner")
struct NetworkDiagnosticsTests {
    @Test("runner executes checks and publishes results in order")
    func runnerOrder() async {
        let invocations = DiagnosticTestRecorder()
        let publications = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(id: id, status: .normal, summary: id.rawValue),
                recorder: invocations
            )
        }

        let results = await DiagnosticRunner(checks: checks).run { result in
            await publications.record(result.id)
        }

        #expect(results.map(\.id) == NetworkDiagnosticCheckID.allCases)
        #expect(await invocations.values == NetworkDiagnosticCheckID.allCases)
        #expect(await publications.values == NetworkDiagnosticCheckID.allCases)
    }

    @Test("runner keeps each check visible for its minimum presentation duration")
    func runnerMinimumPresentationDuration() async {
        let check = StubDiagnosticCheck(
            id: .connectivity,
            result: NetworkDiagnosticResult(id: .connectivity, status: .normal, summary: "ok"),
            recorder: DiagnosticTestRecorder()
        )
        let clock = ContinuousClock()
        let started = clock.now

        _ = await DiagnosticRunner(
            checks: [check],
            minimumStepDuration: .milliseconds(50)
        ).run { _ in }

        #expect(started.duration(to: clock.now) >= .milliseconds(40))
    }

    @Test("production diagnostics present each check for at least 0.8 seconds")
    @MainActor
    func productionMinimumPresentationDuration() {
        #expect(NetworkDiagnosticsViewModel.defaultMinimumStepDuration == .milliseconds(800))
    }

    @Test("network connectivity failure makes the network unavailable")
    func unavailableConclusion() {
        let results = makeResults(connectivity: .abnormal, dns: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkUnavailable)
    }

    @Test("DNS or proxy failure needs attention")
    func abnormalConclusion() {
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(connectivity: .normal, dns: .abnormal, proxy: .normal)
        ) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(connectivity: .normal, dns: .normal, proxy: .abnormal)
        ) == .needsAttention)
    }

    @Test("an indeterminate result needs attention")
    func indeterminateConclusion() {
        let results = makeResults(connectivity: .normal, dns: .indeterminate, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("all normal results make the network normal")
    func normalConclusion() {
        let results = makeResults(connectivity: .normal, dns: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkNormal)
    }

    @Test("an incomplete run has no conclusion")
    func incompleteConclusion() {
        let result = NetworkDiagnosticResult(id: .connectivity, status: .normal, summary: "ok")
        #expect(NetworkDiagnosticConclusion.evaluate([result]) == nil)
    }

    @Test("workbench table adapts columns to available width")
    func adaptiveWorkbenchLayoutMode() {
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 519) == .compact)
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 520) == .condensed)
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 719) == .condensed)
        #expect(NetworkDiagnosticsWorkbenchLayout.mode(for: 720) == .regular)
    }

    @Test("result table uses comfortable rows without alternating empty backgrounds")
    func comfortableResultTablePresentation() {
        #expect(NetworkDiagnosticsTablePresentation.minimumRowHeight == 54)
        #expect(NetworkDiagnosticsTablePresentation.usesAlternatingRowBackgrounds == false)
    }

    @Test("workbench reveals completed and active rows but hides future checks")
    func workbenchRowVisibility() {
        let connectivity = NetworkDiagnosticResult(
            id: .connectivity,
            status: .normal,
            summary: "connected"
        )
        let executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase] = [
            .connectivity: .completed,
            .dns: .checking,
            .proxy: .waiting,
        ]

        #expect(NetworkDiagnosticsPresentation.workbenchRows(
            pagePhase: .idle,
            executionPhases: executionPhases,
            results: [:]
        ).isEmpty)

        let runningRows = NetworkDiagnosticsPresentation.workbenchRows(
            pagePhase: .running,
            executionPhases: executionPhases,
            results: [.connectivity: connectivity]
        )
        #expect(runningRows.map(\.id) == [.connectivity, .dns])
        #expect(runningRows[0].result == connectivity)
        #expect(runningRows[1].result == nil)

        let completedResults = Dictionary(uniqueKeysWithValues: makeResults(
            connectivity: .normal,
            dns: .abnormal,
            proxy: .indeterminate
        ).map { ($0.id, $0) })
        let completedRows = NetworkDiagnosticsPresentation.workbenchRows(
            pagePhase: .completed,
            executionPhases: executionPhases,
            results: completedResults
        )
        #expect(completedRows.map(\.id) == NetworkDiagnosticCheckID.allCases)
    }

    @Test("connectivity check maps path states")
    func connectivityMapping() async {
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.satisfied)).run().status == .normal)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.unsatisfied)).run().status == .abnormal)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.requiresConnection)).run().status == .indeterminate)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(nil)).run().status == .indeterminate)
    }

    @Test("DNS check maps resolver outcomes")
    func dnsMapping() async {
        #expect(await DNSResolutionCheck(resolver: StubDNSResolver(.resolved)).run().status == .normal)
        #expect(await DNSResolutionCheck(resolver: StubDNSResolver(.failed)).run().status == .abnormal)
        #expect(await DNSResolutionCheck(resolver: StubDNSResolver(.indeterminate)).run().status == .indeterminate)
    }

    @Test("DNS success result does not expose the test domain")
    func dnsResultHidesTestDomain() async {
        let testDomain = "example.com"
        let result = await DNSResolutionCheck(
            resolver: StubDNSResolver(.resolved),
            host: testDomain
        ).run()

        #expect(!result.summary.localizedCaseInsensitiveContains(testDomain))
    }

    @Test("proxy parser deduplicates HTTP HTTPS and SOCKS endpoints")
    func proxyParsing() {
        let configuration = SystemProxyConfiguration(settings: [
            "HTTPEnable": 1,
            "HTTPProxy": " Proxy.Example ",
            "HTTPPort": 8080,
            "HTTPSEnable": 1,
            "HTTPSProxy": "proxy.example",
            "HTTPSPort": 8080,
            "SOCKSEnable": 1,
            "SOCKSProxy": "socks.example",
            "SOCKSPort": 1080,
        ])

        #expect(configuration.endpoints == [
            ProxyEndpoint(host: "proxy.example", port: 8080),
            ProxyEndpoint(host: "socks.example", port: 1080),
        ])
        #expect(!configuration.hasInvalidExplicitProxy)
    }

    @Test("proxy parser reads PAC URL and automatic discovery")
    func pacParsing() {
        let configuration = SystemProxyConfiguration(settings: [
            "ProxyAutoConfigEnable": 1,
            "ProxyAutoConfigURLString": "https://proxy.example/config.pac",
            "ProxyAutoDiscoveryEnable": 1,
        ])

        #expect(configuration.pacEnabled)
        #expect(configuration.pacURL == "https://proxy.example/config.pac")
        #expect(configuration.autoDiscoveryEnabled)
    }

    @Test("proxy check treats disabled proxy as normal")
    func proxyDisabled() async {
        let check = SystemProxyCheck(
            settingsReader: StubProxySettingsReader(.disabled),
            connector: StubProxyConnector(reachable: true)
        )
        #expect(await check.run().status == .normal)
    }

    @Test("proxy check reports unreachable explicit endpoint")
    func proxyUnreachable() async {
        let configuration = SystemProxyConfiguration(
            endpoints: [ProxyEndpoint(host: "proxy.example", port: 8080)]
        )
        let check = SystemProxyCheck(
            settingsReader: StubProxySettingsReader(configuration),
            connector: StubProxyConnector(reachable: false)
        )
        #expect(await check.run().status == .abnormal)
    }

    @Test("proxy check reports PAC and malformed explicit settings as indeterminate")
    func proxyIndeterminate() async {
        let pac = SystemProxyCheck(
            settingsReader: StubProxySettingsReader(SystemProxyConfiguration(pacEnabled: true)),
            connector: StubProxyConnector(reachable: true)
        )
        let malformed = SystemProxyCheck(
            settingsReader: StubProxySettingsReader(SystemProxyConfiguration(hasInvalidExplicitProxy: true)),
            connector: StubProxyConnector(reachable: true)
        )

        #expect(await pac.run().status == .indeterminate)
        #expect(await malformed.run().status == .indeterminate)
    }

    @Test("proxy check reports reachable explicit endpoints as normal")
    func proxyReachable() async {
        let configuration = SystemProxyConfiguration(
            endpoints: [ProxyEndpoint(host: "proxy.example", port: 8080)]
        )
        let check = SystemProxyCheck(
            settingsReader: StubProxySettingsReader(configuration),
            connector: StubProxyConnector(reachable: true)
        )
        #expect(await check.run().status == .normal)
    }

    @Test("view model starts idle and only runs after start")
    @MainActor
    func viewModelManualStart() async {
        let recorder = DiagnosticTestRecorder()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
            minimumStepDuration: .zero
        )

        #expect(viewModel.phase == .idle)
        #expect(viewModel.conclusion == nil)
        #expect(await recorder.values.isEmpty)

        #expect(viewModel.start())
        #expect(!viewModel.start())
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.conclusion == .networkNormal)
        #expect(viewModel.results.count == 3)
        #expect(viewModel.executionPhases.values.allSatisfy { $0 == .completed })
    }

    @Test("view model clears the previous conclusion before a rerun")
    @MainActor
    func viewModelRerun() async {
        let recorder = DiagnosticTestRecorder()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
            minimumStepDuration: .zero
        )

        #expect(viewModel.start())
        await viewModel.waitForCompletion()
        #expect(viewModel.conclusion == .networkNormal)

        #expect(viewModel.start())
        #expect(viewModel.conclusion == nil)
        await viewModel.waitForCompletion()
        #expect(await recorder.values.count == 6)
    }

    private func makeResults(
        connectivity: NetworkDiagnosticStatus,
        dns: NetworkDiagnosticStatus,
        proxy: NetworkDiagnosticStatus
    ) -> [NetworkDiagnosticResult] {
        [
            NetworkDiagnosticResult(id: .connectivity, status: connectivity, summary: "connectivity"),
            NetworkDiagnosticResult(id: .dns, status: dns, summary: "dns"),
            NetworkDiagnosticResult(id: .proxy, status: proxy, summary: "proxy"),
        ]
    }

    private func makeStubChecks(recorder: DiagnosticTestRecorder) -> [any DiagnosticCheck] {
        NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(id: id, status: .normal, summary: id.rawValue),
                recorder: recorder
            )
        }
    }
}

private struct StubPathSource: NetworkPathChecking {
    let state: NetworkPathState?

    init(_ state: NetworkPathState?) {
        self.state = state
    }

    func currentState(timeout: Duration) async -> NetworkPathState? {
        state
    }
}

private struct StubDNSResolver: DNSResolving {
    let outcome: DNSResolutionOutcome

    init(_ outcome: DNSResolutionOutcome) {
        self.outcome = outcome
    }

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        outcome
    }
}

private struct StubProxySettingsReader: SystemProxySettingsReading {
    let configuration: SystemProxyConfiguration?

    init(_ configuration: SystemProxyConfiguration?) {
        self.configuration = configuration
    }

    func read() -> SystemProxyConfiguration? {
        configuration
    }
}

private struct StubProxyConnector: ProxyEndpointConnecting {
    let reachable: Bool

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        reachable
    }
}

private actor DiagnosticTestRecorder {
    private(set) var values: [NetworkDiagnosticCheckID] = []

    func record(_ value: NetworkDiagnosticCheckID) {
        values.append(value)
    }
}

private struct StubDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID
    let result: NetworkDiagnosticResult
    let recorder: DiagnosticTestRecorder

    func run() async -> NetworkDiagnosticResult {
        await recorder.record(id)
        return result
    }
}
