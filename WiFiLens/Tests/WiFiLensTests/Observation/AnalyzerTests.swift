import Foundation
import Testing
@testable import WiFi_Lens

@Suite("Observation Analyzers")
struct AnalyzerTests {
    @Test("WiFiQualityEvaluator: strong signal + low latency = good")
    func strongGood() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -45, isConnected: true, isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 20)
        let result = WiFiQualityEvaluator.evaluate(currentStatus: status, gatewayLatency: latency)
        #expect(result.level == .good)
    }

    @Test("WiFiQualityEvaluator: weak signal = poor")
    func weakPoor() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 6,
            rssi: -80, isConnected: true, isWiFiPowerOn: true
        )
        let result = WiFiQualityEvaluator.evaluate(currentStatus: status)
        #expect(result.level == .poor)
    }

    @Test("RoamingEventDetector: BSSID change produces event")
    func bssidChangeEvent() {
        let prev = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB:CC:DD:EE:01",
            channel: 36, rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let cur = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB:CC:DD:EE:02",
            channel: 36, rssi: -55, isConnected: true, isWiFiPowerOn: true
        )
        let events = RoamingEventDetector.detect(previous: prev, current: cur)
        #expect(events.count == 1)
        if case .bssidChange(let from, let to) = events[0].type {
            #expect(from == "AA:BB:CC:DD:EE:01")
            #expect(to == "AA:BB:CC:DD:EE:02")
        } else {
            Issue.record("Expected bssidChange event")
        }
    }

    @Test("RoamingEventDetector: signal drop > 20dBm produces event")
    func signalDropEvent() {
        let prev = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB",
            channel: 6, rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let cur = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB",
            channel: 6, rssi: -75, isConnected: true, isWiFiPowerOn: true
        )
        let events = RoamingEventDetector.detect(previous: prev, current: cur)
        #expect(events.contains { $0.type == .signalDrop(from: -50, to: -75) })
    }

    @Test("DiagnosticEvaluator: excellent when strong + WPA3 + good channel")
    func excellentDiagnostic() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB", channel: 36,
            rssi: -45, security: "WPA3", isConnected: true, isWiFiPowerOn: true
        )
        let ch = ChannelQuality(
            channel: 36, band: "5", bandDisplay: "5 GHz",
            qualityScore: 85, qualityLevel: .good,
            apCount: 1, coChannelCount: 0, adjacentCount: 1,
            interferenceScore: 15, overlapLevel: .low,
            strongestNeighborRSSI: -70, isCurrentChannel: true
        )
        let result = DiagnosticEvaluator.evaluate(
            currentStatus: status, channelAnalysis: [ch]
        )
        #expect(result.severity == .excellent)
    }

    @Test("DiagnosticEvaluator: congested message formats integer inputs")
    func congestedDiagnosticFormatsIntegers() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB", channel: 6,
            rssi: -60, security: "WPA3", isConnected: true, isWiFiPowerOn: true
        )
        let ch = ChannelQuality(
            channel: 6, band: "24", bandDisplay: "2.4 GHz",
            qualityScore: 35, qualityLevel: .congested,
            apCount: 8, coChannelCount: 5, adjacentCount: 3,
            interferenceScore: 65, overlapLevel: .high,
            strongestNeighborRSSI: -50, isCurrentChannel: true
        )
        let result = DiagnosticEvaluator.evaluate(
            currentStatus: status, channelAnalysis: [ch], channelRecommendations: []
        )
        #expect(result.severity == .warning)
        #expect(result.message.contains("6"))
        #expect(result.message.contains("8"))
        #expect(!result.message.contains("%1$"))
        #expect(!result.message.contains("observation.diagnosis"))
    }
}
