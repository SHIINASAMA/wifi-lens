import Foundation
import Testing
@testable import WiFi_Lens

// MARK: - ChannelBand

struct ChannelBandTests {

    @Test func allCasesCount() {
        #expect(ChannelBand.allCases.count == 3)
    }

    @Test func band24GHzProperties() {
        #expect(ChannelBand.band24GHz.rawValue == 1)
        #expect(ChannelBand.band24GHz.id == "24")
        #expect(ChannelBand.band24GHz.maxChannel == 16)
    }

    @Test func band5GHzProperties() {
        #expect(ChannelBand.band5GHz.rawValue == 2)
        #expect(ChannelBand.band5GHz.id == "5")
        #expect(ChannelBand.band5GHz.maxChannel == 170)
    }

    @Test func band6GHzProperties() {
        #expect(ChannelBand.band6GHz.rawValue == 3)
        #expect(ChannelBand.band6GHz.id == "6")
        #expect(ChannelBand.band6GHz.maxChannel == 233)
    }

    @Test func displayNameNonEmpty() {
        for band in ChannelBand.allCases {
            #expect(!band.displayName.isEmpty)
        }
    }

    @Test func initWithValidID() {
        #expect(ChannelBand(id: "24") == .band24GHz)
        #expect(ChannelBand(id: "5") == .band5GHz)
        #expect(ChannelBand(id: "6") == .band6GHz)
    }

    @Test func initWithInvalidIDReturnsNil() {
        #expect(ChannelBand(id: "invalid") == nil)
        #expect(ChannelBand(id: "") == nil)
        #expect(ChannelBand(id: "2.4") == nil)
    }
}

// MARK: - SpanDirection

struct SpanDirectionTests {

    @Test func rawValues() {
        #expect(SpanDirection.upper.rawValue == "upper")
        #expect(SpanDirection.lower.rawValue == "lower")
    }
}

// MARK: - WiFiChannel (DEBUG init)

struct WiFiChannelTests {

    @Test func basicProperties() {
        let ch = WiFiChannel(band: .band5GHz, channelNumber: 44, channelWidthMHz: 80, spanDirection: .upper)
        #expect(ch.band == .band5GHz)
        #expect(ch.channelNumber == 44)
        #expect(ch.channelWidthMHz == 80)
        #expect(ch.spanDirection == .upper)
    }

    @Test func defaultChannelWidth() {
        let ch = WiFiChannel(band: .band24GHz, channelNumber: 6)
        #expect(ch.channelWidthMHz == 20)
        #expect(ch.spanDirection == nil)
    }

    @Test func nilSpanDirection() {
        let ch = WiFiChannel(band: .band5GHz, channelNumber: 36, spanDirection: nil)
        #expect(ch.spanDirection == nil)
    }

    @Test func differentBands() {
        let ch24 = WiFiChannel(band: .band24GHz, channelNumber: 1)
        let ch5 = WiFiChannel(band: .band5GHz, channelNumber: 36)
        let ch6 = WiFiChannel(band: .band6GHz, channelNumber: 1)
        #expect(ch24.band == .band24GHz)
        #expect(ch5.band == .band5GHz)
        #expect(ch6.band == .band6GHz)
    }
}

// MARK: - WiFiNetwork (DEBUG init)

struct WiFiNetworkTests {

    private func makeChannel(band: ChannelBand = .band5GHz, channel: Int = 44) -> WiFiChannel {
        WiFiChannel(band: band, channelNumber: channel, channelWidthMHz: 20)
    }

    @Test func basicProperties() {
        let channel = makeChannel()
        let network = WiFiNetwork(ssid: "TestNet", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: channel)
        #expect(network.ssid == "TestNet")
        #expect(network.bssid == "aa:bb:cc:dd:ee:ff")
        #expect(network.rssi == -50)
        #expect(network.isIBSS == false)
        #expect(network.ieData == nil)
    }

    @Test func computedID() {
        let channel = makeChannel(band: .band5GHz, channel: 44)
        let network = WiFiNetwork(ssid: "Test", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: channel)
        #expect(network.id == "aa:bb:cc:dd:ee:ff-44-2")
    }

    @Test func nilSSID() {
        let channel = makeChannel()
        let network = WiFiNetwork(ssid: nil, bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: channel)
        #expect(network.ssid == nil)
    }

    @Test func ieDataPreserved() {
        let channel = makeChannel()
        let data = Data([0x01, 0x02, 0x03])
        let network = WiFiNetwork(ssid: "Test", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: channel, ieData: data)
        #expect(network.ieData == data)
    }

    @Test func uniqueIDForDifferentChannels() {
        let ch1 = WiFiChannel(band: .band5GHz, channelNumber: 44)
        let ch2 = WiFiChannel(band: .band5GHz, channelNumber: 48)
        let n1 = WiFiNetwork(ssid: "Net", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: ch1)
        let n2 = WiFiNetwork(ssid: "Net", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: ch2)
        #expect(n1.id != n2.id)
    }

    @Test func uniqueIDForDifferentBands() {
        let ch5 = WiFiChannel(band: .band5GHz, channelNumber: 6)
        let ch24 = WiFiChannel(band: .band24GHz, channelNumber: 6)
        let n1 = WiFiNetwork(ssid: "Net", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: ch5)
        let n2 = WiFiNetwork(ssid: "Net", bssid: "aa:bb:cc:dd:ee:ff", rssi: -50, channel: ch24)
        #expect(n1.id != n2.id)
    }
}
