import CFNetwork
import Foundation
import Testing
@testable import WiFi_Lens

@Suite("Network diagnostics models and runner")
struct NetworkDiagnosticsTests {
    @Test("diagnostic identifiers keep path and internet distinct in execution order")
    func diagnosticIdentifierOrder() {
        #expect(NetworkDiagnosticCheckID.allCases == [.path, .dns, .internet, .ipv6, .proxy])
        #expect(NetworkDiagnosticCheckID.path != .internet)
        #expect(Set(NetworkDiagnosticCheckID.allCases).count == 5)
    }

    @Test("blocked and skipped statuses have distinct presentations")
    func blockedAndSkippedPresentation() {
        #expect(NetworkDiagnosticStatus.blocked.presentation == .init(
            labelKey: "network_diagnostics.status.blocked",
            icon: "lock.fill",
            tone: .informational
        ))
        #expect(NetworkDiagnosticStatus.skipped.presentation == .init(
            labelKey: "network_diagnostics.status.skipped",
            icon: "forward.fill",
            tone: .muted
        ))
        #expect(NetworkDiagnosticStatus.blocked.presentation != NetworkDiagnosticStatus.indeterminate.presentation)
        #expect(NetworkDiagnosticStatus.skipped.presentation != NetworkDiagnosticStatus.indeterminate.presentation)
    }

    @Test("a blocked probe does not become an independent network fault")
    func blockedProbeIsNotAbnormal() {
        let result = NetworkDiagnosticResult.blocked(id: .internet, summary: "DNS is unavailable")
        #expect(result.status == .blocked)
        #expect(result.detail == "DNS is unavailable")
    }

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

    @Test("runner blocks downstream probes when the network path is unusable")
    func runnerBlocksDependentChecks() async {
        let invocations = DiagnosticTestRecorder()
        let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
            StubDiagnosticCheck(
                id: id,
                result: NetworkDiagnosticResult(
                    id: id,
                    status: id == .path ? .abnormal : .normal,
                    summary: id.rawValue
                ),
                recorder: invocations
            )
        }

        let results = await DiagnosticRunner(checks: checks).run { _ in }

        #expect(await invocations.values == [.path])
        #expect(results.first?.status == .abnormal)
        #expect(results.dropFirst().allSatisfy { $0.status == .blocked })
        #expect(results.dropFirst().allSatisfy {
            $0.evidence == [.init(code: "blocked.by", value: "path")]
        })
    }

    @Test("runner keeps each check visible for its minimum presentation duration")
    func runnerMinimumPresentationDuration() async {
        let check = StubDiagnosticCheck(
            id: .path,
            result: NetworkDiagnosticResult(id: .path, status: .normal, summary: "ok"),
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

    @Test("system path failure makes the network unavailable")
    func unavailableConclusion() {
        let results = makeResults(path: .abnormal, dns: .normal, internet: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkUnavailable)
    }

    @Test("DNS or proxy failure needs attention")
    func abnormalConclusion() {
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(path: .normal, dns: .abnormal, internet: .normal, proxy: .normal)
        ) == .needsAttention)
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(path: .normal, dns: .normal, internet: .normal, proxy: .abnormal)
        ) == .needsAttention)
    }

    @Test("failed base HTTPS suppresses proxy endpoint symptom")
    func conclusionSuppressesProxySymptom() {
        let results = makeResults(
            path: .normal,
            dns: .indeterminate,
            internet: .abnormal,
            proxy: .abnormal
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkUnavailable)
    }

    @Test("base HTTPS success and explicit proxy failure needs attention")
    func proxyIsIndependentWhenBasePathWorks() {
        let results = makeResults(
            path: .normal,
            dns: .normal,
            internet: .normal,
            proxy: .abnormal
        )

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("captive portal symptom after HTTPS success needs attention")
    func captivePortalSymptomAfterHTTPSSuccess() {
        let results = [
            NetworkDiagnosticResult(id: .path, status: .normal, summary: "path"),
            NetworkDiagnosticResult(id: .dns, status: .normal, summary: "dns"),
            NetworkDiagnosticResult(
                id: .internet,
                status: .abnormal,
                summary: "internet",
                evidence: [
                    .init(code: "https.available", value: "200"),
                    .init(code: "captive-portal.suspected", value: nil),
                ]
            ),
            NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: .normal, summary: "proxy"),
        ]

        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("an indeterminate result needs attention")
    func indeterminateConclusion() {
        let results = makeResults(path: .normal, dns: .indeterminate, internet: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    }

    @Test("normal required results and skipped optional IPv6 make the network normal")
    func fourResultNormalConclusion() {
        let results = makeResults(path: .normal, dns: .normal, internet: .normal, proxy: .normal)
        #expect(NetworkDiagnosticConclusion.evaluate(results) == .networkNormal)
    }

    @Test("no global IPv6 address is skipped without changing a normal conclusion")
    func ipv6SkippedIsConclusionNeutral() async {
        let ipv6 = await IPv6ControlEndpointCheck(
            loader: StubIPv6Loader(.noGlobalAddress)
        ).run()

        #expect(ipv6.id == .ipv6)
        #expect(ipv6.status == .skipped)
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(
                path: .normal,
                dns: .normal,
                internet: .normal,
                ipv6: ipv6.status,
                proxy: .normal
            )
        ) == .networkNormal)
    }

    @Test("IPv6 failure is advisory when base HTTPS succeeds")
    func ipv6IsIndependent() async {
        let ipv6 = await IPv6ControlEndpointCheck(loader: StubIPv6Loader(.failed)).run()

        #expect(ipv6.status == .indeterminate)
        #expect(ipv6.evidence.contains(.init(code: "ipv6.unavailable", value: nil)))
        #expect(NetworkDiagnosticConclusion.evaluate(
            makeResults(
                path: .normal,
                dns: .normal,
                internet: .normal,
                ipv6: ipv6.status,
                proxy: .normal
            )
        ) == .needsAttention)
    }

    @Test("IPv6 control endpoint success is normal")
    func ipv6Success() async {
        let result = await IPv6ControlEndpointCheck(loader: StubIPv6Loader(.succeeded)).run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "ipv6.available", value: nil)))
    }

    @Test("system IPv6 loader connects only to a resolved IPv6 literal")
    func ipv6LoaderForcesResolvedAddress() async {
        let recorder = IPv6LoaderTestRecorder()
        let loader = SystemIPv6ControlEndpointLoader(
            addressSource: StubGlobalIPv6AddressSource(hasAddress: true),
            resolver: StubIPv6AddressResolver(addresses: ["2001:db8::42"]),
            connector: RecordingIPv6HTTPSConnector(succeeds: true, recorder: recorder)
        )
        let endpoint = URL(string: "https://control.example/health")!

        let outcome = await loader.load(url: endpoint, timeout: .seconds(4))

        #expect(outcome == .succeeded)
        let requests = await recorder.requests
        #expect(requests.count == 1)
        #expect(requests.first?.url == endpoint)
        #expect(requests.first?.ipv6Address == "2001:db8::42")
        #expect(requests.first?.serverName == "control.example")
        #expect(requests.first.map { $0.timeout > .zero && $0.timeout <= .seconds(4) } == true)
    }

    @Test("system IPv6 loader tries later resolved addresses")
    func ipv6LoaderFallsBackAcrossAddresses() async {
        let connector = SequencedIPv6HTTPSConnector(successfulAddress: "2001:db8::2")
        let loader = SystemIPv6ControlEndpointLoader(
            addressSource: StubGlobalIPv6AddressSource(hasAddress: true),
            resolver: StubIPv6AddressResolver(addresses: ["2001:db8::1", "2001:db8::2"]),
            connector: connector
        )

        let outcome = await loader.load(
            url: URL(string: "https://control.example/health")!,
            timeout: .seconds(4)
        )

        #expect(outcome == .succeeded)
        #expect(await connector.addresses == ["2001:db8::1", "2001:db8::2"])
        let timeouts = await connector.timeouts
        #expect(timeouts.count == 2)
        #expect(timeouts.first.map { $0 > .zero && $0 <= .seconds(2) } == true)
        #expect(timeouts.last.map { $0 > .zero && $0 <= .seconds(4) } == true)
    }

    @Test("system IPv6 loader skips resolution when no global address is present")
    func ipv6LoaderSkipsWithoutGlobalAddress() async {
        let resolver = RecordingIPv6AddressResolver(addresses: ["2001:db8::42"])
        let loader = SystemIPv6ControlEndpointLoader(
            addressSource: StubGlobalIPv6AddressSource(hasAddress: false),
            resolver: resolver,
            connector: StubIPv6HTTPSConnector(succeeds: true)
        )

        let outcome = await loader.load(
            url: URL(string: "https://control.example/")!,
            timeout: .seconds(4)
        )

        #expect(outcome == .noGlobalAddress)
        #expect(await resolver.hosts.isEmpty)
    }

    @Test("IPv6 DNS configures delivery before the resolver context owns the service")
    func ipv6DNSActivationOrder() {
        var events: [String] = []

        IPv6DNSServiceActivation.configureThenInstall(
            configureDelivery: { events.append("configure") },
            installOwnership: { events.append("install") }
        )

        #expect(events == ["configure", "install"])
    }

    @Test("an incomplete run has no conclusion")
    func incompleteConclusion() {
        let result = NetworkDiagnosticResult(id: .path, status: .normal, summary: "ok")
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
        let path = NetworkDiagnosticResult(
            id: .path,
            status: .normal,
            summary: "connected"
        )
        let executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase] = [
            .path: .completed,
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
            results: [.path: path],
            checkIDs: [.path, .dns, .proxy]
        )
        #expect(runningRows.map(\.id) == [.path, .dns])
        #expect(runningRows[0].result == path)
        #expect(runningRows[1].result == nil)

        let completedResults = Dictionary(uniqueKeysWithValues: makeResults(
            path: .normal,
            dns: .abnormal,
            internet: .normal,
            proxy: .indeterminate
        ).map { ($0.id, $0) })
        let completedRows = NetworkDiagnosticsPresentation.workbenchRows(
            pagePhase: .completed,
            executionPhases: executionPhases,
            results: completedResults,
            checkIDs: [.path, .dns, .proxy]
        )
        #expect(completedRows.map(\.id) == [.path, .dns, .proxy])
    }

    @Test("system path check maps path states")
    func pathMapping() async {
        let satisfied = await NetworkConnectivityCheck(pathSource: StubPathSource(.satisfied)).run()
        #expect(satisfied.id == .path)
        #expect(satisfied.status == .normal)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.unsatisfied)).run().status == .abnormal)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(.requiresConnection)).run().status == .indeterminate)
        #expect(await NetworkConnectivityCheck(pathSource: StubPathSource(nil)).run().status == .indeterminate)
    }

    @Test("a satisfied system path is not an internet-success result")
    func pathCheckReportsPathOnly() async {
        let result = await NetworkConnectivityCheck(pathSource: StubPathSource(.satisfied)).run()

        #expect(result.id == .path)
        #expect(result.id != .internet)
        #expect(result.detail == String(
            localized: "network_diagnostics.path.normal.summary",
            comment: "Network self-check system path success detail"
        ))
    }

    @Test("Microsoft captive-portal probe rejects a rewritten response")
    func captivePortalProbeRejectsRewrittenResponse() async {
        let check = HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 204,
                httpStatus: 200,
                httpBody: "login"
            )
        )

        let result = await check.run()

        #expect(result.id == .internet)
        #expect(result.evidence.contains(.init(code: "captive-portal.suspected", value: nil)))
    }

    @Test("control endpoint success verifies HTTPS and the documented Microsoft body")
    func controlEndpointSuccess() async {
        let check = HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: 200,
                httpBody: "Microsoft Connect Test"
            )
        )

        let result = await check.run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "https.available", value: "200")))
        #expect(result.evidence.contains(.init(code: "captive-portal.clear", value: nil)))
    }

    @Test("Apple HTTPS success and Microsoft HTTP timeout is indeterminate")
    func controlEndpointMicrosoftTimeoutIsIndeterminate() async {
        let result = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: nil,
                httpBody: nil,
                httpErrorCode: String(URLError.timedOut.rawValue)
            )
        ).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "https.available", value: "200")))
        #expect(result.evidence.contains(.init(
            code: "captive-portal.transport-error",
            value: String(URLError.timedOut.rawValue)
        )))
    }

    @Test("Apple HTTPS success and Microsoft HTTP timeout needs attention")
    func controlEndpointMicrosoftTimeoutConclusion() async {
        let internet = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: nil,
                httpBody: nil,
                httpErrorCode: String(URLError.timedOut.rawValue)
            )
        ).run()

        let conclusion = NetworkDiagnosticConclusion.evaluate([
            NetworkDiagnosticResult(id: .path, status: .normal, summary: "path"),
            NetworkDiagnosticResult(id: .dns, status: .normal, summary: "dns"),
            internet,
            NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: .normal, summary: "proxy"),
        ])

        #expect(conclusion == .needsAttention)
        #expect(conclusion != .networkUnavailable)
    }

    @Test("control endpoint failures retain distinct evidence")
    func controlEndpointFailureEvidence() async {
        let transportFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: nil,
                httpsErrorCode: "-1200",
                httpStatus: 200,
                httpBody: "Microsoft Connect Test"
            )
        ).run()
        let httpsStatusFailure = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 503,
                httpStatus: 200,
                httpBody: "Microsoft Connect Test"
            )
        ).run()
        let captivePortalRedirect = await HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: 302,
                httpBody: nil
            )
        ).run()

        #expect(transportFailure.evidence.contains(.init(code: "https.transport-error", value: "-1200")))
        #expect(httpsStatusFailure.evidence.contains(.init(code: "https.http-status", value: "503")))
        #expect(captivePortalRedirect.evidence.contains(.init(code: "captive-portal.redirect", value: "302")))
    }

    @Test("control check loads the approved endpoints with an explicit timeout")
    func controlEndpointRequests() async {
        let recorder = ControlEndpointTestRecorder()
        let check = HTTPSControlEndpointCheck(
            loader: StubControlLoader(
                httpsStatus: 200,
                httpStatus: 200,
                httpBody: "Microsoft Connect Test",
                recorder: recorder
            )
        )

        _ = await check.run()

        #expect(await recorder.urls == [
            "https://www.apple.com/",
            "http://www.msftconnecttest.com/connecttest.txt",
        ])
        #expect(await recorder.timeouts == [.seconds(5), .seconds(5)])
    }

    @Test("system control loader disables caching and connectivity waits")
    func controlEndpointSessionConfiguration() {
        let configuration = SystemControlEndpointLoader.configuration(timeout: .seconds(5))

        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.urlCache == nil)
        #expect(!configuration.waitsForConnectivity)
        #expect(configuration.timeoutIntervalForRequest == 5)
        #expect(configuration.timeoutIntervalForResource == 5)
    }

    @Test("app permits temporary HTTP only for the Microsoft captive-portal endpoint")
    func temporaryCaptivePortalATSException() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any]
        let domains = ats?["NSExceptionDomains"] as? [String: Any]
        let exception = domains?["www.msftconnecttest.com"] as? [String: Any]

        #expect(ats?.count == 1)
        #expect(ats?["NSAllowsArbitraryLoads"] == nil)
        #expect(domains?.count == 1)
        #expect(exception?.count == 1)
        #expect(exception?["NSExceptionAllowsInsecureHTTPLoads"] as? Bool == true)
        #expect(exception?["NSIncludesSubdomains"] == nil)
    }

    @Test("production checks run path DNS HTTPS and proxy in dependency order")
    @MainActor
    func productionCheckOrder() {
        #expect(NetworkDiagnosticsViewModel().checkIDs == [.path, .dns, .internet, .ipv6, .proxy])
    }

    @Test("all successful DNS samples are available")
    func dnsAllSamplesResolved() async {
        let result = await DNSResolutionCheck(resolver: StubDNSResolver(.resolved)).run()

        #expect(result.status == .normal)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "3/3")))
        #expect(result.evidence.contains(.init(code: "dns.failure-count", value: "0/3")))
        #expect(result.evidence.contains(.init(code: "dns.indeterminate-count", value: "0/3")))
    }

    @Test("DNS uses the three temporary third-party probe targets")
    func dnsProbeTargets() {
        let check = DNSResolutionCheck(resolver: StubDNSResolver(.resolved))

        #expect(check.probeTargets == [
            "www.apple.com",
            "www.microsoft.com",
            "www.msftconnecttest.com",
        ])
    }

    @Test("one failed lookup among successful samples is unstable, not unavailable")
    func dnsQuorum() async {
        let check = DNSResolutionCheck(
            resolver: StubDNSResolver(outcomes: [.resolved, .failed, .resolved])
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "2/3")))
        #expect(result.evidence.contains(.init(code: "dns.failure-count", value: "1/3")))
    }

    @Test("all failed DNS samples are unavailable")
    func dnsAllSamplesFailed() async {
        let result = await DNSResolutionCheck(resolver: StubDNSResolver(.failed)).run()

        #expect(result.status == .abnormal)
        #expect(result.evidence.contains(.init(code: "dns.success-count", value: "0/3")))
        #expect(result.evidence.contains(.init(code: "dns.failure-count", value: "3/3")))
    }

    @Test("an indeterminate DNS sample is retried once")
    func dnsIndeterminateSampleRetriesOnce() async {
        let resolver = StubDNSResolver(outcomes: [.indeterminate, .resolved, .resolved, .resolved])
        let result = await DNSResolutionCheck(resolver: resolver).run()

        #expect(result.status == .normal)
        #expect(await resolver.invocationCount == 4)
    }

    @Test("cancelling DNS sampling does not start the remaining hosts")
    func dnsCancellationStopsSampling() async {
        let resolver = CancellationAwareDNSResolver()
        let check = DNSResolutionCheck(resolver: resolver, timeout: .seconds(30))
        let task = Task { await check.run() }

        await resolver.waitForInvocation()
        task.cancel()
        _ = await task.value

        #expect(await resolver.invocationCount == 1)
    }

    @Test("all indeterminate DNS samples cannot be determined")
    func dnsAllSamplesIndeterminate() async {
        let result = await DNSResolutionCheck(resolver: StubDNSResolver(.indeterminate)).run()

        #expect(result.status == .indeterminate)
        #expect(result.evidence.contains(.init(code: "dns.indeterminate-count", value: "3/3")))
    }

    @Test("DNS success result does not expose the test domain")
    func dnsResultHidesTestDomain() async {
        let testDomain = "example.com"
        let result = await DNSResolutionCheck(
            resolver: StubDNSResolver(.resolved),
            probeTargets: [testDomain, "example.net", "example.org"]
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

    @Test("PAC result chooses DIRECT without probing a stale explicit endpoint")
    func pacCanChooseDirect() async {
        let controlURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let recorder = PACResolutionTestRecorder()
        let resolver = SystemProxyResolver(
            pacTimeout: .milliseconds(25),
            configurationResolver: StubProxyConfigurationResolver(.pac(pacURL)),
            pacResolver: StubPACResolver(.direct, recorder: recorder)
        )
        let resolution = await resolver.resolve(for: controlURL)

        #expect(resolution == .direct)
        #expect(await recorder.requests == [
            .init(pacURL: pacURL, targetURL: controlURL, timeout: .milliseconds(25)),
        ])
    }

    @Test("CFNetwork PAC DIRECT result maps to direct egress")
    func pacDirectParsing() {
        let result: NSDictionary = [
            kCFProxyTypeKey as String: kCFProxyTypeNone,
        ]

        #expect(SystemProxyResolver.directive(from: result) == .direct)
    }

    @Test("DIRECT does not probe a stale explicit endpoint or proxy egress")
    func directSkipsStaleProxy() async {
        let connectorRecorder = ProxyConnectorTestRecorder()
        let egressRecorder = ProxyEgressTestRecorder()
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(.direct),
            connector: RecordingProxyConnector(reachable: false, recorder: connectorRecorder),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "unexpected", recorder: egressRecorder)
        )

        let result = await check.run()

        #expect(result.status == .normal)
        #expect(await connectorRecorder.endpoints.isEmpty)
        #expect(await egressRecorder.requests.isEmpty)
    }

    @Test("PAC timeout is reported as PAC unavailable")
    func pacTimeout() async {
        let pacURL = URL(string: "https://proxy.example/config.pac")!
        let check = SystemProxyCheck(
            resolver: SystemProxyResolver(
                configurationResolver: StubProxyConfigurationResolver(.pac(pacURL)),
                pacResolver: StubPACResolver(.unavailable("pac-timeout"))
            ),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200)
        )

        let result = await check.run()

        #expect(result.status == .indeterminate)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.pac_unavailable.summary",
            comment: "Network self-check PAC unavailable result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.pac-unavailable", value: "pac-timeout")))
    }

    @Test("selected proxy endpoint failure is distinct from egress failure")
    func selectedProxyEndpointUnavailable() async {
        let egressRecorder = ProxyEgressTestRecorder()
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: false),
            egressLoader: StubProxyEgressLoader(statusCode: 200, recorder: egressRecorder)
        )

        let result = await check.run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.endpoint_unavailable.summary",
            comment: "Network self-check selected proxy endpoint unavailable result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.endpoint-unavailable", value: nil)))
        #expect(await egressRecorder.requests.isEmpty)
    }

    @Test("HTTP 407 is proxy authentication required")
    func proxyAuthenticationRequired() async {
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 407)
        )

        let result = await check.run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.authentication_required.summary",
            comment: "Network self-check proxy authentication required result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.authentication-required", value: "407")))
        #expect(!result.evidence.contains(where: { $0.code == "proxy.endpoint-unavailable" }))
    }

    @Test("URL loading authentication challenge remains a proxy 407 result")
    func proxyAuthenticationChallenge() {
        let response = SystemProxyEgressLoader.response(
            for: URLError(.userAuthenticationRequired)
        )

        #expect(response == ProxyEgressResponse(statusCode: 407, errorCode: nil))
    }

    @Test("production egress configuration disables selected proxy failover")
    func selectedProxyDoesNotFailOver() throws {
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let configuration = try #require(
            SystemProxyEgressLoader.configuration(for: proxy, timeout: .seconds(3))
        )

        #expect(configuration.proxyConfigurations.count == 1)
        #expect(configuration.proxyConfigurations[0].allowFailover == false)
        #expect(configuration.connectionProxyDictionary?.isEmpty != false)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test("selected proxy transport failure is egress unavailable")
    func proxyEgressUnavailable() async {
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: nil, errorCode: "-1005")
        )

        let result = await check.run()

        #expect(result.status == .abnormal)
        #expect(result.summary == String(
            localized: "network_diagnostics.proxy.egress_unavailable.summary",
            comment: "Network self-check selected proxy egress unavailable result summary"
        ))
        #expect(result.evidence.contains(.init(code: "proxy.egress-unavailable", value: "-1005")))
    }

    @Test("selected HTTP proxy probes the same control URL once")
    func selectedProxyEgressSuccess() async {
        let controlURL = URL(string: "http://www.msftconnecttest.com/connecttest.txt")!
        let proxy = EffectiveProxy.http(ProxyEndpoint(host: "proxy.example", port: 8080))
        let recorder = ProxyEgressTestRecorder()
        let check = SystemProxyCheck(
            resolver: StubProxyResolver(proxy),
            connector: StubProxyConnector(reachable: true),
            egressLoader: StubProxyEgressLoader(statusCode: 200, recorder: recorder),
            controlURL: controlURL
        )

        let result = await check.run()

        #expect(result.status == .normal)
        #expect(await recorder.requests == [.init(url: controlURL, proxy: proxy)])
    }

    @Test("view model starts idle and only runs after start")
    @MainActor
    func viewModelManualStart() async {
        let recorder = DiagnosticTestRecorder()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: makeStubChecks(recorder: recorder),
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor()
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
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor()
        )

        #expect(viewModel.start())
        await viewModel.waitForCompletion()
        #expect(viewModel.conclusion == .networkNormal)

        #expect(viewModel.start())
        #expect(viewModel.conclusion == nil)
        await viewModel.waitForCompletion()
        #expect(await recorder.values.count == 6)
    }

    @Test("a changed fingerprint restarts network probes once and retains configuration results")
    @MainActor
    func fingerprintChangeRestartsOnce() async {
        let initial = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: initial)
        let configurationProbe = RestartableDiagnosticProbe()
        let networkProbe = RestartableDiagnosticProbe(blockFirstInvocation: true)
        let checks: [any DiagnosticCheck] = [
            ProbeDiagnosticCheck(
                id: .proxy,
                result: .init(id: .proxy, status: .normal, summary: "configuration"),
                rerunPolicy: .configurationOnly,
                probe: configurationProbe
            ),
            ProbeDiagnosticCheck(
                id: .path,
                result: .init(id: .path, status: .normal, summary: "network"),
                rerunPolicy: .networkSensitive,
                probe: networkProbe
            ),
        ]
        let viewModel = NetworkDiagnosticsViewModel(
            checks: checks,
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor
        )

        #expect(viewModel.start())
        await networkProbe.waitForInvocationCount(1)
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en1", dnsHash: 2))
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en2", dnsHash: 3))
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.conclusion == .networkNormal)
        #expect(viewModel.automaticRestartCount == 1)
        #expect(await configurationProbe.invocationCount == 1)
        #expect(await networkProbe.invocationCount == 2)
        #expect(viewModel.results[.proxy]?.summary == "configuration")
        #expect(viewModel.results[.path]?.summary == "network")
    }

    @Test("an unchanged fingerprint does not restart an active probe")
    @MainActor
    func unchangedFingerprintDoesNotRestart() async {
        let fingerprint = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: fingerprint)
        let probe = RestartableDiagnosticProbe(blockFirstInvocation: true)
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [
                ProbeDiagnosticCheck(
                    id: .path,
                    result: .init(id: .path, status: .normal, summary: "network"),
                    rerunPolicy: .networkSensitive,
                    probe: probe
                ),
            ],
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        await fingerprintMonitor.send(fingerprint)
        await probe.releaseFirstInvocation()
        await viewModel.waitForCompletion()

        #expect(viewModel.automaticRestartCount == 0)
        #expect(await probe.invocationCount == 1)
    }

    @Test("a second network change during the rerun starts a fresh run")
    @MainActor
    func repeatedFingerprintChangesRestartAgain() async {
        let initial = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let fingerprintMonitor = ControlledNetworkFingerprintMonitor(initial: initial)
        let probe = BlockingDiagnosticProbe()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [BlockingProbeDiagnosticCheck(id: .path, probe: probe)],
            minimumStepDuration: .zero,
            fingerprintMonitor: fingerprintMonitor
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en1", dnsHash: 2))
        await probe.waitForInvocationCount(2)
        await fingerprintMonitor.send(makeFingerprint(interfaceName: "en2", dnsHash: 3))
        await probe.waitForInvocationCount(3)
        await probe.release(invocation: 3)
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.automaticRestartCount == 2)
        #expect(await probe.invocationCount == 3)
    }

    @Test("the controller closes network-change intake before results are published")
    func fingerprintControllerFinalizationGate() async {
        let controller = NetworkDiagnosticRestartController()
        let fingerprint = makeFingerprint(interfaceName: "en1", dnsHash: 2)

        #expect(await controller.completeRun() == false)
        #expect(await controller.observe(fingerprint) == false)
    }

    @Test("a later same-interface path update is still a network change")
    func sameInterfacePathUpdateIsDetected() async {
        let baseline = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let path = NetworkPathFingerprint(
            interfaceType: baseline.interfaceType,
            interfaceName: baseline.interfaceName,
            pathStatus: baseline.pathStatus
        )
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: MutableFingerprintSettingsReader(dnsHash: 1, proxyHash: 7),
            pathSource: FiniteNetworkPathFingerprintSource(values: [path, path]),
            settingsPoller: SilentNetworkFingerprintSettingsPoller()
        )

        var changes: [NetworkFingerprint] = []
        for await fingerprint in monitor.changes(from: baseline) {
            changes.append(fingerprint)
        }

        #expect(changes == [baseline])
    }

    @Test("explicit cancellation stops an active diagnostics session")
    @MainActor
    func viewModelCancellation() async {
        let probe = BlockingDiagnosticProbe()
        let viewModel = NetworkDiagnosticsViewModel(
            checks: [BlockingProbeDiagnosticCheck(id: .path, probe: probe)],
            minimumStepDuration: .zero,
            fingerprintMonitor: DisabledNetworkFingerprintMonitor()
        )

        #expect(viewModel.start())
        await probe.waitForInvocationCount(1)
        viewModel.cancel()
        await viewModel.waitForCompletion()

        #expect(viewModel.phase == .idle)
        #expect(viewModel.conclusion == nil)
    }

    @Test("system fingerprint monitor detects DNS settings changes without a path update")
    func fingerprintDetectsSettingsOnlyChange() async {
        let baseline = makeFingerprint(interfaceName: "en0", dnsHash: 1)
        let settingsReader = MutableFingerprintSettingsReader(dnsHash: 1, proxyHash: 7)
        let monitor = SystemNetworkFingerprintMonitor(
            settingsReader: settingsReader,
            pathSource: SilentNetworkPathFingerprintSource(),
            settingsPoller: ImmediateNetworkFingerprintSettingsPoller(),
            settingsPollInterval: .milliseconds(10)
        )

        settingsReader.setDNSHash(2)
        var changedFingerprint: NetworkFingerprint?
        for await fingerprint in monitor.changes(from: baseline) {
            changedFingerprint = fingerprint
            break
        }

        #expect(changedFingerprint?.interfaceName == "en0")
        #expect(changedFingerprint?.dnsSettingsHash == 2)
        #expect(changedFingerprint?.staticProxySettingsHash == 7)
    }

    @Test("proxy fingerprint includes PAC and automatic discovery settings")
    func proxyFingerprintIncludesAutomaticSettings() {
        let baseline = SystemNetworkFingerprintSettingsReader.proxySettingsHash(for: [
            "ProxyAutoConfigEnable": 0,
            "ProxyAutoConfigURLString": "https://proxy.example/old.pac",
            "ProxyAutoDiscoveryEnable": 0,
        ])
        let changedPAC = SystemNetworkFingerprintSettingsReader.proxySettingsHash(for: [
            "ProxyAutoConfigEnable": 1,
            "ProxyAutoConfigURLString": "https://proxy.example/new.pac",
            "ProxyAutoDiscoveryEnable": 0,
        ])
        let changedDiscovery = SystemNetworkFingerprintSettingsReader.proxySettingsHash(for: [
            "ProxyAutoConfigEnable": 0,
            "ProxyAutoConfigURLString": "https://proxy.example/old.pac",
            "ProxyAutoDiscoveryEnable": 1,
        ])

        #expect(changedPAC != baseline)
        #expect(changedDiscovery != baseline)
    }

    private func makeResults(
        path: NetworkDiagnosticStatus,
        dns: NetworkDiagnosticStatus,
        internet: NetworkDiagnosticStatus,
        ipv6: NetworkDiagnosticStatus = .skipped,
        proxy: NetworkDiagnosticStatus
    ) -> [NetworkDiagnosticResult] {
        [
            NetworkDiagnosticResult(id: .path, status: path, summary: "path"),
            NetworkDiagnosticResult(id: .dns, status: dns, summary: "dns"),
            NetworkDiagnosticResult(id: .internet, status: internet, summary: "internet"),
            NetworkDiagnosticResult(id: .ipv6, status: ipv6, summary: "ipv6"),
            NetworkDiagnosticResult(id: .proxy, status: proxy, summary: "proxy"),
        ]
    }

    private func makeFingerprint(
        interfaceName: String,
        dnsHash: UInt64
    ) -> NetworkFingerprint {
        NetworkFingerprint(
            interfaceType: "wifi",
            interfaceName: interfaceName,
            pathStatus: .satisfied,
            dnsSettingsHash: dnsHash,
            staticProxySettingsHash: 7
        )
    }

    private func makeStubChecks(recorder: DiagnosticTestRecorder) -> [any DiagnosticCheck] {
        [.path, .dns, .proxy].map { id in
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

private actor StubDNSResolver: DNSResolving {
    private var outcomes: [DNSResolutionOutcome]
    private var outcomeIndex = 0
    private(set) var invocationCount = 0

    init(_ outcome: DNSResolutionOutcome) {
        outcomes = [outcome]
    }

    init(outcomes: [DNSResolutionOutcome]) {
        precondition(!outcomes.isEmpty)
        self.outcomes = outcomes
    }

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        invocationCount += 1
        defer { outcomeIndex += 1 }
        return outcomes[min(outcomeIndex, outcomes.endIndex - 1)]
    }
}

private actor CancellationAwareDNSResolver: DNSResolving {
    private var invocationWaiter: CheckedContinuation<Void, Never>?
    private(set) var invocationCount = 0

    func resolve(host: String, timeout: Duration) async -> DNSResolutionOutcome {
        invocationCount += 1
        invocationWaiter?.resume()
        invocationWaiter = nil
        try? await Task.sleep(for: timeout)
        return .indeterminate
    }

    func waitForInvocation() async {
        guard invocationCount == 0 else { return }
        await withCheckedContinuation { invocationWaiter = $0 }
    }
}

private struct StubControlLoader: ControlEndpointLoading {
    let httpsStatus: Int?
    let httpsErrorCode: String?
    let httpStatus: Int?
    let httpBody: String?
    let httpErrorCode: String?
    let recorder: ControlEndpointTestRecorder?

    init(
        httpsStatus: Int?,
        httpsErrorCode: String? = nil,
        httpStatus: Int?,
        httpBody: String?,
        httpErrorCode: String? = nil,
        recorder: ControlEndpointTestRecorder? = nil
    ) {
        self.httpsStatus = httpsStatus
        self.httpsErrorCode = httpsErrorCode
        self.httpStatus = httpStatus
        self.httpBody = httpBody
        self.httpErrorCode = httpErrorCode
        self.recorder = recorder
    }

    func load(url: URL, timeout: Duration) async -> (status: Int?, body: String?, errorCode: String?) {
        await recorder?.record(url: url, timeout: timeout)
        if url.scheme == "https" {
            return (httpsStatus, nil, httpsErrorCode)
        }
        return (httpStatus, httpBody, httpErrorCode)
    }
}

private struct StubIPv6Loader: IPv6ControlEndpointLoading {
    let outcome: IPv6ControlEndpointLoadOutcome

    init(_ outcome: IPv6ControlEndpointLoadOutcome) {
        self.outcome = outcome
    }

    func load(url: URL, timeout: Duration) async -> IPv6ControlEndpointLoadOutcome {
        outcome
    }
}

private struct StubGlobalIPv6AddressSource: GlobalIPv6AddressSourcing {
    let hasAddress: Bool

    func hasGlobalIPv6Address() -> Bool {
        hasAddress
    }
}

private struct StubIPv6AddressResolver: IPv6AddressResolving {
    let addresses: [String]

    func resolveAAAA(host: String, timeout: Duration) async -> [String] {
        addresses
    }
}

private actor RecordingIPv6AddressResolver: IPv6AddressResolving {
    let addresses: [String]
    private(set) var hosts: [String] = []

    init(addresses: [String]) {
        self.addresses = addresses
    }

    func resolveAAAA(host: String, timeout: Duration) async -> [String] {
        hosts.append(host)
        return addresses
    }
}

private struct IPv6LoaderTestRequest: Equatable, Sendable {
    let url: URL
    let ipv6Address: String
    let serverName: String
    let timeout: Duration
}

private actor IPv6LoaderTestRecorder {
    private(set) var requests: [IPv6LoaderTestRequest] = []

    func record(_ request: IPv6LoaderTestRequest) {
        requests.append(request)
    }
}

private struct RecordingIPv6HTTPSConnector: IPv6HTTPSConnecting {
    let succeeds: Bool
    let recorder: IPv6LoaderTestRecorder

    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        await recorder.record(.init(
            url: url,
            ipv6Address: ipv6Address,
            serverName: serverName,
            timeout: timeout
        ))
        return succeeds
    }
}

private struct StubIPv6HTTPSConnector: IPv6HTTPSConnecting {
    let succeeds: Bool

    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        succeeds
    }
}

private actor SequencedIPv6HTTPSConnector: IPv6HTTPSConnecting {
    let successfulAddress: String
    private(set) var addresses: [String] = []
    private(set) var timeouts: [Duration] = []

    init(successfulAddress: String) {
        self.successfulAddress = successfulAddress
    }

    func load(
        url: URL,
        ipv6Address: String,
        serverName: String,
        timeout: Duration
    ) async -> Bool {
        addresses.append(ipv6Address)
        timeouts.append(timeout)
        return ipv6Address == successfulAddress
    }
}

private actor ControlEndpointTestRecorder {
    private(set) var urls: [String] = []
    private(set) var timeouts: [Duration] = []

    func record(url: URL, timeout: Duration) {
        urls.append(url.absoluteString)
        timeouts.append(timeout)
    }
}

private struct StubProxyConfigurationResolver: ProxyConfigurationResolving {
    let resolution: ProxyResolutionDirective

    init(_ resolution: ProxyResolutionDirective) {
        self.resolution = resolution
    }

    func resolution(for url: URL) -> ProxyResolutionDirective {
        resolution
    }
}

private struct PACResolutionTestRequest: Equatable, Sendable {
    let pacURL: URL
    let targetURL: URL
    let timeout: Duration
}

private actor PACResolutionTestRecorder {
    private(set) var requests: [PACResolutionTestRequest] = []

    func record(pacURL: URL, targetURL: URL, timeout: Duration) {
        requests.append(.init(pacURL: pacURL, targetURL: targetURL, timeout: timeout))
    }
}

private struct StubPACResolver: PACResolving {
    let resolution: EffectiveProxy
    let recorder: PACResolutionTestRecorder?

    init(_ resolution: EffectiveProxy, recorder: PACResolutionTestRecorder? = nil) {
        self.resolution = resolution
        self.recorder = recorder
    }

    func resolve(pacURL: URL, targetURL: URL, timeout: Duration) async -> EffectiveProxy {
        await recorder?.record(pacURL: pacURL, targetURL: targetURL, timeout: timeout)
        return resolution
    }
}

private struct StubProxyResolver: ProxyResolving {
    let resolution: EffectiveProxy

    init(_ resolution: EffectiveProxy) {
        self.resolution = resolution
    }

    func resolve(for url: URL) async -> EffectiveProxy {
        resolution
    }
}

private struct ProxyEgressTestRequest: Equatable, Sendable {
    let url: URL
    let proxy: EffectiveProxy
}

private actor ProxyEgressTestRecorder {
    private(set) var requests: [ProxyEgressTestRequest] = []

    func record(url: URL, proxy: EffectiveProxy) {
        requests.append(.init(url: url, proxy: proxy))
    }
}

private struct StubProxyEgressLoader: ProxyEgressLoading {
    let statusCode: Int?
    let errorCode: String?
    let recorder: ProxyEgressTestRecorder?

    init(
        statusCode: Int?,
        errorCode: String? = nil,
        recorder: ProxyEgressTestRecorder? = nil
    ) {
        self.statusCode = statusCode
        self.errorCode = errorCode
        self.recorder = recorder
    }

    func load(
        url: URL,
        through proxy: EffectiveProxy,
        timeout: Duration
    ) async -> ProxyEgressResponse {
        await recorder?.record(url: url, proxy: proxy)
        return ProxyEgressResponse(statusCode: statusCode, errorCode: errorCode)
    }
}

private struct StubProxyConnector: ProxyEndpointConnecting {
    let reachable: Bool

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        reachable
    }
}

private actor ProxyConnectorTestRecorder {
    private(set) var endpoints: [ProxyEndpoint] = []

    func record(_ endpoint: ProxyEndpoint) {
        endpoints.append(endpoint)
    }
}

private struct RecordingProxyConnector: ProxyEndpointConnecting {
    let reachable: Bool
    let recorder: ProxyConnectorTestRecorder

    func canConnect(to endpoint: ProxyEndpoint, timeout: Duration) async -> Bool {
        await recorder.record(endpoint)
        return reachable
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

private actor RestartableDiagnosticProbe {
    private let blockFirstInvocation: Bool
    private var firstInvocationContinuation: CheckedContinuation<Void, Never>?
    private var invocationWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var invocationCount = 0

    init(blockFirstInvocation: Bool = false) {
        self.blockFirstInvocation = blockFirstInvocation
    }

    func run() async {
        invocationCount += 1
        let completedCount = invocationCount
        let readyWaiters = invocationWaiters.filter { $0.count <= completedCount }
        invocationWaiters.removeAll { $0.count <= completedCount }
        for waiter in readyWaiters {
            waiter.continuation.resume()
        }

        guard blockFirstInvocation, completedCount == 1 else { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                firstInvocationContinuation = continuation
            }
        } onCancel: {
            Task { await self.releaseFirstInvocation() }
        }
    }

    func waitForInvocationCount(_ expectedCount: Int) async {
        guard invocationCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            invocationWaiters.append((expectedCount, continuation))
        }
    }

    func releaseFirstInvocation() {
        firstInvocationContinuation?.resume()
        firstInvocationContinuation = nil
    }
}

private struct ProbeDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID
    let result: NetworkDiagnosticResult
    let rerunPolicy: DiagnosticCheckRerunPolicy
    let probe: RestartableDiagnosticProbe

    func run() async -> NetworkDiagnosticResult {
        await probe.run()
        return result
    }
}

private actor BlockingDiagnosticProbe {
    private var continuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var invocationWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var invocationCount = 0

    func run() async {
        invocationCount += 1
        let invocation = invocationCount
        let readyWaiters = invocationWaiters.filter { $0.count <= invocation }
        invocationWaiters.removeAll { $0.count <= invocation }
        readyWaiters.forEach { $0.continuation.resume() }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuations[invocation] = $0 }
        } onCancel: {
            Task { await self.release(invocation: invocation) }
        }
    }

    func waitForInvocationCount(_ expectedCount: Int) async {
        guard invocationCount < expectedCount else { return }
        await withCheckedContinuation {
            invocationWaiters.append((expectedCount, $0))
        }
    }

    func release(invocation: Int) {
        continuations.removeValue(forKey: invocation)?.resume()
    }
}

private struct BlockingProbeDiagnosticCheck: DiagnosticCheck {
    let id: NetworkDiagnosticCheckID
    let probe: BlockingDiagnosticProbe

    func run() async -> NetworkDiagnosticResult {
        await probe.run()
        return .init(id: id, status: .normal, summary: id.rawValue)
    }
}

private actor ControlledNetworkFingerprintMonitor: NetworkFingerprintMonitoring {
    let initial: NetworkFingerprint
    private var lastFingerprint: NetworkFingerprint
    private var continuation: AsyncStream<NetworkFingerprint>.Continuation?
    private var pending: [NetworkFingerprint] = []

    init(initial: NetworkFingerprint) {
        self.initial = initial
        self.lastFingerprint = initial
    }

    func currentFingerprint() async -> NetworkFingerprint? {
        initial
    }

    nonisolated func changes(
        from baseline: NetworkFingerprint
    ) -> AsyncStream<NetworkFingerprint> {
        AsyncStream { continuation in
            Task { await self.install(continuation) }
        }
    }

    func send(_ fingerprint: NetworkFingerprint) {
        guard fingerprint != lastFingerprint else { return }
        lastFingerprint = fingerprint
        guard let continuation else {
            pending.append(fingerprint)
            return
        }
        continuation.yield(fingerprint)
    }

    private func install(_ continuation: AsyncStream<NetworkFingerprint>.Continuation) {
        self.continuation = continuation
        for fingerprint in pending {
            continuation.yield(fingerprint)
        }
        pending = []
    }
}

private struct SilentNetworkPathFingerprintSource: NetworkPathFingerprintSourcing {
    func currentPathFingerprint() async -> NetworkPathFingerprint? {
        nil
    }

    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        AsyncStream { $0.finish() }
    }
}

private struct FiniteNetworkPathFingerprintSource: NetworkPathFingerprintSourcing {
    let values: [NetworkPathFingerprint]

    func currentPathFingerprint() async -> NetworkPathFingerprint? {
        values.first
    }

    func pathFingerprintChanges() -> AsyncStream<NetworkPathFingerprint> {
        AsyncStream { continuation in
            values.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

private struct ImmediateNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.yield(())
            continuation.finish()
        }
    }
}

private struct SilentNetworkFingerprintSettingsPoller: NetworkFingerprintSettingsPolling {
    func ticks(every interval: Duration) -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

private final class MutableFingerprintSettingsReader: NetworkFingerprintSettingsReading, @unchecked Sendable {
    private let lock = NSLock()
    private var dnsHash: UInt64
    private let proxyHash: UInt64

    init(dnsHash: UInt64, proxyHash: UInt64) {
        self.dnsHash = dnsHash
        self.proxyHash = proxyHash
    }

    func dnsSettingsHash() -> UInt64 {
        lock.withLock { dnsHash }
    }

    func staticProxySettingsHash() -> UInt64 {
        proxyHash
    }

    func setDNSHash(_ value: UInt64) {
        lock.withLock { dnsHash = value }
    }
}
