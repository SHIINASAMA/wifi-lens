import Foundation
import Testing
@testable import WiFi_Lens

@MainActor
struct MACVendorResolverTests {
    private func makeResolver() -> MACVendorResolver {
        MACVendorResolver(entries: [
            MACVendorEntry(prefix: "001122", prefixLength: 24, organization: "Large Networks"),
            MACVendorEntry(prefix: "0011223", prefixLength: 28, organization: "Medium Networks"),
            MACVendorEntry(prefix: "001122334", prefixLength: 36, organization: "Small Networks"),
        ])
    }

    @Test func usesLongestMatchingPrefix() {
        let resolver = makeResolver()

        #expect(resolver.resolve("00:11:22:33:44:55") == .registered("Small Networks"))
        #expect(resolver.resolve("00:11:22:3f:44:55") == .registered("Medium Networks"))
        #expect(resolver.resolve("00:11:22:ff:44:55") == .registered("Large Networks"))
    }

    @Test func acceptsCommonMACAddressFormats() {
        let resolver = makeResolver()

        #expect(resolver.resolve("00:11:22:33:44:55") == .registered("Small Networks"))
        #expect(resolver.resolve("00-11-22-33-44-55") == .registered("Small Networks"))
        #expect(resolver.resolve("001122334455") == .registered("Small Networks"))
    }

    @Test func bundledDatabaseResolvesKnownRegistration() {
        let resolver = MACVendorResolver()

        #expect(resolver.resolve("00:03:93:00:00:00") == .registered("Apple, Inc."))
    }

    @Test func locallyAdministeredAddressesDoNotUseRegistryMappings() {
        let resolver = MACVendorResolver(entries: [
            MACVendorEntry(prefix: "021122", prefixLength: 24, organization: "Should Not Match"),
        ])

        #expect(resolver.resolve("02:11:22:33:44:55") == .locallyAdministered)
    }

    @Test func distinguishesUnknownFromInvalidAddresses() {
        let resolver = makeResolver()

        #expect(resolver.resolve("10:20:30:40:50:60") == .unknown)
        #expect(resolver.resolve("not-a-mac") == .invalid)
        #expect(resolver.resolve("00:11:22:33:44") == .invalid)
        #expect(resolver.resolve("00x11x22x33x44x55") == .invalid)
        #expect(resolver.resolve("00:11-22:33:44:55") == .invalid)
    }

    @Test func unsupportedDatabaseSchemaFallsBackToAnEmptyDatabase() throws {
        let data = try #require(
            """
            {"schemaVersion":2,"entries":[{"prefix":"001122","prefixLength":24,"organization":"Example"}]}
            """.data(using: .utf8)
        )
        let resolver = MACVendorResolver(databaseData: data)

        #expect(resolver.resolve("00:11:22:33:44:55") == .unknown)
    }

    @Test func scannerProjectsRegisteredVendorIntoTableRows() {
        let resolver = MACVendorResolver(entries: [
            MACVendorEntry(prefix: "001122", prefixLength: 24, organization: "Example Networks"),
        ])
        let viewModel = ScannerViewModel(vendorResolver: resolver)
        let network = WiFiNetwork(
            ssid: "TestWiFi",
            bssid: "00:11:22:33:44:55",
            rssi: -50,
            channel: WiFiChannel(band: .band5GHz, channelNumber: 44)
        )

        viewModel.debugApplyNetworksForTesting([network], supportedBands: [.band5GHz])

        #expect(viewModel.combinedTableRows.first?.vendor == "Example Networks")
    }

    @Test func scannerUsesPlaceholderForNonRegisteredAddresses() {
        let viewModel = ScannerViewModel(vendorResolver: MACVendorResolver(entries: []))
        let unknown = WiFiNetwork(
            ssid: "Unknown",
            bssid: "10:20:30:40:50:60",
            rssi: -50,
            channel: WiFiChannel(band: .band5GHz, channelNumber: 44)
        )

        viewModel.debugApplyNetworksForTesting([unknown], supportedBands: [.band5GHz])

        #expect(viewModel.combinedTableRows.first?.vendor == "—")
    }
}
