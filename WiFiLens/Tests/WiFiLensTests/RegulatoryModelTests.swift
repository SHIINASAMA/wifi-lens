import Testing
import Foundation
@testable import WiFi_Lens

// MARK: - RegulatoryDomain

struct RegulatoryDomainTests {

    @Test func allCasesCount() {
        #expect(RegulatoryDomain.allCases.count == 5)
    }

    @Test func displayNameNonEmpty() {
        for domain in RegulatoryDomain.allCases {
            #expect(!domain.displayName.isEmpty)
        }
    }

    @Test func fromLocaleRegion_US() {
        #expect(RegulatoryDomain.from(localeRegionCode: "US") == .US)
        #expect(RegulatoryDomain.from(localeRegionCode: "CA") == .US)
        #expect(RegulatoryDomain.from(localeRegionCode: "MX") == .US)
    }

    @Test func fromLocaleRegion_JP() {
        #expect(RegulatoryDomain.from(localeRegionCode: "JP") == .JP)
    }

    @Test func fromLocaleRegion_CN() {
        #expect(RegulatoryDomain.from(localeRegionCode: "CN") == .CN)
    }

    @Test func fromLocaleRegion_EU() {
        #expect(RegulatoryDomain.from(localeRegionCode: "GB") == .EU)
        #expect(RegulatoryDomain.from(localeRegionCode: "DE") == .EU)
        #expect(RegulatoryDomain.from(localeRegionCode: "FR") == .EU)
        #expect(RegulatoryDomain.from(localeRegionCode: "NO") == .EU)
        #expect(RegulatoryDomain.from(localeRegionCode: "CH") == .EU)
    }

    @Test func fromLocaleRegion_nilReturnsUnknown() {
        #expect(RegulatoryDomain.from(localeRegionCode: nil) == .unknown)
    }

    @Test func fromLocaleRegion_unknownReturnsUnknown() {
        #expect(RegulatoryDomain.from(localeRegionCode: "ZZ") == .unknown)
        #expect(RegulatoryDomain.from(localeRegionCode: "AU") == .unknown)
    }

    @Test func fromLocaleRegion_caseInsensitive() {
        #expect(RegulatoryDomain.from(localeRegionCode: "us") == .US)
        #expect(RegulatoryDomain.from(localeRegionCode: "jp") == .JP)
    }

    @Test func codableRoundTrip() throws {
        let original = RegulatoryDomain.JP
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegulatoryDomain.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - InferenceConfidence

struct InferenceConfidenceTests {

    @Test func labelNonEmpty() {
        for confidence in [InferenceConfidence.high, .medium, .low] {
            #expect(!confidence.label.isEmpty)
        }
    }

    @Test func comparisonHighGreaterThanLow() {
        #expect(InferenceConfidence.high < .low)
        #expect(InferenceConfidence.high < .medium)
        #expect(InferenceConfidence.medium < .low)
        #expect(InferenceConfidence.medium > .high)
        #expect(InferenceConfidence.low > .medium)
    }

    @Test func equalConfidences() {
        #expect(InferenceConfidence.high == .high)
        #expect(InferenceConfidence.medium == .medium)
        #expect(InferenceConfidence.low == .low)
    }
}

// MARK: - RegionSource

struct RegionSourceTests {

    @Test func descriptionFormat() {
        let source = RegionSource(
            kind: .systemLocale,
            rawValue: "JP",
            inferredDomain: .JP
        )
        #expect(source.description == "[systemLocale] raw=JP → JP")
    }

    @Test func descriptionWithUnknownDomain() {
        let source = RegionSource(
            kind: .apBeaconCountry,
            rawValue: "XX",
            inferredDomain: nil
        )
        #expect(source.description == "[apBeaconCountry] raw=XX → unknown")
    }

    @Test func userOverrideKind() {
        let source = RegionSource(
            kind: .userOverride,
            rawValue: "US",
            inferredDomain: .US
        )
        #expect(source.description == "[userOverride] raw=US → US")
    }
}

// MARK: - RegionInferenceResult

struct RegionInferenceResultTests {

    @Test func summaryWithContributions() {
        let source = RegionSource(kind: .systemLocale, rawValue: "US", inferredDomain: .US)
        let result = RegionInferenceResult(
            domain: .US,
            confidence: .high,
            contributions: [source],
            conflicts: []
        )
        #expect(result.summary.contains("Region: US"))
        #expect(result.summary.contains(result.confidence.label))
        #expect(result.summary.contains("systemLocale"))
    }

    @Test func summaryWithConflicts() {
        let conflict = RegionConflict(
            sourceA: RegionSource(kind: .systemLocale, rawValue: "JP", inferredDomain: .JP),
            sourceB: RegionSource(kind: .apBeaconCountry, rawValue: "US", inferredDomain: .US),
            resolution: "Locale and AP beacon disagree"
        )
        let result = RegionInferenceResult(
            domain: .unknown,
            confidence: .low,
            contributions: [],
            conflicts: [conflict]
        )
        #expect(result.summary.contains("disagree"))
    }
}

// MARK: - DevicePHYCapabilities

struct DevicePHYCapabilitiesTests {

    @Test func defaultCapabilities() {
        let def = DevicePHYCapabilities.default
        #expect(def.supportsAC == true)
        #expect(def.supportsN == true)
        #expect(def.supportsAX == false)
        #expect(def.supportsBE == false)
        #expect(def.supports6GHz == false)
        #expect(def.supportsDFS == true)
        #expect(def.supports160MHz == false)
    }

    @Test func phySummaryAX() {
        let caps = DevicePHYCapabilities(
            supportsAX: true, supportsAC: true, supportsN: true, supportsBE: false,
            supports6GHz: false, supportsDFS: false, supports160MHz: false
        )
        #expect(caps.phySummary == "ax/ac/n")
    }

    @Test func phySummaryBE() {
        let caps = DevicePHYCapabilities(
            supportsAX: false, supportsAC: false, supportsN: false, supportsBE: true,
            supports6GHz: false, supportsDFS: false, supports160MHz: false
        )
        #expect(caps.phySummary == "be")
    }

    @Test func phySummaryAll() {
        let caps = DevicePHYCapabilities(
            supportsAX: true, supportsAC: true, supportsN: true, supportsBE: true,
            supports6GHz: false, supportsDFS: false, supports160MHz: false
        )
        #expect(caps.phySummary == "be/ax/ac/n")
    }

    @Test func phySummaryUnknown() {
        let caps = DevicePHYCapabilities(
            supportsAX: false, supportsAC: false, supportsN: false, supportsBE: false,
            supports6GHz: false, supportsDFS: false, supports160MHz: false
        )
        #expect(caps.phySummary == "unknown")
    }
}

// MARK: - ChannelRecommendation

struct ChannelRecommendationTests {

    private func makeChannelQuality(
        channel: Int = 44,
        band: String = "5",
        score: Int = 85,
        level: ChannelQuality.QualityLevel = .good,
        isRecommended: Bool = true
    ) -> ChannelQuality {
        ChannelQuality(
            channel: channel,
            band: band,
            bandDisplay: "5 GHz",
            qualityScore: score,
            qualityLevel: level,
            apCount: 1,
            coChannelCount: 1,
            adjacentCount: 0,
            interferenceScore: 15,
            overlapLevel: .low,
            strongestNeighborRSSI: -50,
            isRecommended: isRecommended,
            isCurrentChannel: false,
            showInSimpleView: true
        )
    }

    @Test func initFromChannelQuality() {
        let rf = makeChannelQuality()
        let rec = ChannelRecommendation(from: rf)
        #expect(rec.channel == 44)
        #expect(rec.band == "5")
        #expect(rec.bandDisplay == "5 GHz")
        #expect(rec.rfScore == 85)
        #expect(rec.rfLevel == .good)
        #expect(rec.scoreSelected == true)
        #expect(rec.isRecommended == true)
        #expect(rec.apCount == 1)
    }

    @Test func computedID() {
        let rf = makeChannelQuality(channel: 6, band: "24")
        let rec = ChannelRecommendation(from: rf)
        #expect(rec.id == "24-6")
    }

    @Test func defaultClassification() {
        let rf = makeChannelQuality()
        let rec = ChannelRecommendation(from: rf)
        #expect(rec.classification == .recommended)
    }

    @Test func classificationOrder() {
        #expect(ChannelRecommendation.Classification.recommended.order == 2)
        #expect(ChannelRecommendation.Classification.advanced.order == 1)
        #expect(ChannelRecommendation.Classification.restricted.order == 0)
    }

    @Test func classificationDisplayNameNonEmpty() {
        for c in ChannelRecommendation.Classification.allCases {
            #expect(!c.displayName.isEmpty)
        }
    }

    @Test func defaultDeviceCompatible() {
        let rf = makeChannelQuality()
        let rec = ChannelRecommendation(from: rf)
        #expect(rec.deviceCompatible == true)
        #expect(rec.deviceIncompatibilityReason == nil)
    }

    @Test func mutableProperties() {
        let rf = makeChannelQuality()
        var rec = ChannelRecommendation(from: rf)
        rec.classification = .restricted
        rec.scoreSelected = true
        rec.deviceCompatible = false
        rec.deviceIncompatibilityReason = "DFS required"
        rec.restrictionReasons = [ChannelRecommendation.RestrictionReason(code: "DFS", description: "DFS channel")]
        #expect(rec.classification == .restricted)
        #expect(rec.isRecommended == false)
        #expect(rec.deviceCompatible == false)
        #expect(rec.deviceIncompatibilityReason == "DFS required")
        #expect(rec.restrictionReasons.count == 1)
        #expect(rec.restrictionReasons[0].code == "DFS")
    }

    @Test func recommendationAvailabilityDetectsAvailableRecommendations() {
        let rec = ChannelRecommendation(from: makeChannelQuality(isRecommended: true))
        #expect(ChannelRecommendationAvailability.from([rec]) == .available)
    }

    @Test func recommendationAvailabilityDetectsCurrentGoodEnough() {
        var current = ChannelRecommendation(from: makeChannelQuality(isRecommended: false))
        current.isCurrentChannel = true
        current.recommendationState = .currentGoodEnough
        #expect(ChannelRecommendationAvailability.from([current]) == .currentGoodEnough)
    }

    @Test func recommendationAvailabilityDetectsTargetUnknown() {
        var current = ChannelRecommendation(from: makeChannelQuality(isRecommended: false))
        current.isCurrentChannel = true
        current.recommendationConfidence = .unknown
        current.recommendationState = .targetUnknown
        #expect(ChannelRecommendationAvailability.from([current]) == .targetUnknown)
    }

    @Test func recommendationAvailabilityDetectsRegulatoryFiltered() {
        var candidate = ChannelRecommendation(from: makeChannelQuality(isRecommended: true))
        candidate.scoreSelected = true
        candidate.classification = .advanced
        #expect(ChannelRecommendationAvailability.from([candidate]) == .regulatoryFiltered)
    }

    @Test func recommendationAvailabilityDefaultsToNoSignificantImprovement() {
        var current = ChannelRecommendation(from: makeChannelQuality(isRecommended: false))
        current.isCurrentChannel = true
        current.recommendationConfidence = .exact
        current.recommendationState = .insufficientImprovement
        #expect(ChannelRecommendationAvailability.from([current]) == .noSignificantImprovement)
    }
}
