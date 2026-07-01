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

    @Test("DiagnosticEvaluator: congested message includes recommended channels")
    func congestedDiagnosticIncludesRecommendations() {
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
        let recommendationAQuality = ChannelQuality(
            channel: 1, band: "24", bandDisplay: "2.4 GHz",
            qualityScore: 82, qualityLevel: .good,
            apCount: 1, coChannelCount: 1, adjacentCount: 0,
            interferenceScore: 12, overlapLevel: .low,
            strongestNeighborRSSI: -72
        )
        let recommendationBQuality = ChannelQuality(
            channel: 11, band: "24", bandDisplay: "2.4 GHz",
            qualityScore: 79, qualityLevel: .good,
            apCount: 2, coChannelCount: 1, adjacentCount: 1,
            interferenceScore: 18, overlapLevel: .low,
            strongestNeighborRSSI: -68
        )
        var recommendationA = ChannelRecommendation(from: recommendationAQuality)
        recommendationA.scoreSelected = true
        recommendationA.classification = .recommended
        var recommendationB = ChannelRecommendation(from: recommendationBQuality)
        recommendationB.scoreSelected = true
        recommendationB.classification = .recommended

        let result = DiagnosticEvaluator.evaluate(
            currentStatus: status,
            channelAnalysis: [ch],
            channelRecommendations: [recommendationA, recommendationB]
        )

        #expect(result.severity == .warning)
        #expect(result.message.contains("1 / 11"))
    }
}
