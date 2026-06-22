import Testing
@testable import WiFiLens

@Suite("Observation Models")
struct ModelsTests {
    @Test("WiFiNetworkObservation uses BSSID-based ID when available")
    func bssidBasedID() {
        let ch = WiFiChannel(band: .band5GHz, channelNumber: 36, channelWidthMHz: 20)
        let obs = WiFiNetworkObservation(ssid: "TestNet", bssid: "AA:BB:CC:DD:EE:FF", rssi: -50, channel: ch)
        #expect(obs.id == "AA:BB:CC:DD:EE:FF-36-2")
    }

    @Test("WiFiNetworkObservation uses local fallback ID when BSSID is unknown")
    func localFallbackID() {
        let ch = WiFiChannel(band: .band24GHz, channelNumber: 6, channelWidthMHz: 20)
        let caps = WiFiNetworkCapabilities(phyMode: "ac", channelWidth: 80, supports80211k: false, supports80211r: false, supports80211v: false, supportsWPA3: true, countryCode: nil, isHiddenSSID: false, mcs: nil, nss: nil, security: "WPA2")
        let obs = WiFiNetworkObservation(ssid: "TestNet", bssid: "unknown", rssi: -60, channel: ch, capabilities: caps)
        #expect(obs.id.hasPrefix("local-"))
        #expect(!obs.id.contains("-60")) // RSSI must not be in ID
    }

    @Test("WiFiNetworkCapabilities empty static")
    func emptyCapabilities() {
        let empty = WiFiNetworkCapabilities.empty
        #expect(empty.phyMode == "")
        #expect(empty.channelWidth == 20)
        #expect(empty.supports80211k == false)
    }

    @Test("WiFiObservation defaults")
    func observationDefaults() {
        let obs = WiFiObservation()
        #expect(obs.currentStatus == nil)
        #expect(obs.events.isEmpty)
        #expect(obs.errors.isEmpty)
    }

    @Test("DiagnosticResult unknown static")
    func unknownDiagnostic() {
        let diag = DiagnosticResult.unknown
        #expect(diag.severity == .ok)
    }

    @Test("WiFiQualityLevel display names")
    func qualityLevelDisplay() {
        #expect(WiFiQualityLevel.good.displayName == String(localized: "observation.quality.good"))
        #expect(WiFiQualityLevel.poor.displayName == String(localized: "observation.quality.poor"))
    }
}
