import Testing
@testable import WiFi_Lens

struct ChannelSpanCalculatorTests {

    // MARK: - channelHalfSpan

    @Test func channelHalfSpanFor20MHz() {
        #expect(ChannelSpanCalculator.channelHalfSpan(for: 20) == 2)
    }

    @Test func channelHalfSpanFor40MHz() {
        #expect(ChannelSpanCalculator.channelHalfSpan(for: 40) == 4)
    }

    @Test func channelHalfSpanFor80MHz() {
        #expect(ChannelSpanCalculator.channelHalfSpan(for: 80) == 8)
    }

    @Test func channelHalfSpanFor160MHz() {
        #expect(ChannelSpanCalculator.channelHalfSpan(for: 160) == 16)
    }

    // MARK: - 20 MHz (any band)

    @Test func channelBlock20MHz24GHz() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 6, widthMHz: 20, band: .band24GHz, spanDirection: nil)
        #expect(left == 4)
        #expect(right == 8)
    }

    @Test func channelBlock20MHz5GHz() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 100, widthMHz: 20, band: .band5GHz, spanDirection: nil)
        #expect(left == 98)
        #expect(right == 102)
    }

    // MARK: - 2.4 GHz 40 MHz

    @Test func channelBlock24GHz40MHzHT40Plus() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 6, widthMHz: 40, band: .band24GHz, spanDirection: .upper)
        #expect(left == 4)
        #expect(right == 12)
    }

    @Test func channelBlock24GHz40MHzHT40Minus() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 11, widthMHz: 40, band: .band24GHz, spanDirection: .lower)
        #expect(left == 5)
        #expect(right == 13)
    }

    @Test func channelBlock24GHz40MHzFallbackLowChannel() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 6, widthMHz: 40, band: .band24GHz, spanDirection: nil)
        // primary <= 7 defaults to upper
        #expect(left == 4)
        #expect(right == 12)
    }

    @Test func channelBlock24GHz40MHzFallbackHighChannel() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 11, widthMHz: 40, band: .band24GHz, spanDirection: nil)
        // primary > 7 defaults to lower
        #expect(left == 5)
        #expect(right == 13)
    }

    // MARK: - 5 GHz 40 MHz blocks

    @Test func channelBlock5GHz40MHzCh36to40() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 36, widthMHz: 40, band: .band5GHz, spanDirection: nil)
        #expect(left == 34)
        #expect(right == 42)
    }

    @Test func channelBlock5GHz40MHzCh44to48() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 44, widthMHz: 40, band: .band5GHz, spanDirection: nil)
        #expect(left == 42)
        #expect(right == 50)
    }

    @Test func channelBlock5GHz40MHzCh149to153() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 149, widthMHz: 40, band: .band5GHz, spanDirection: nil)
        #expect(left == 147)
        #expect(right == 155)
    }

    // MARK: - 5 GHz 80 MHz blocks

    @Test func channelBlock5GHz80MHzCh36to48() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 36, widthMHz: 80, band: .band5GHz, spanDirection: nil)
        #expect(left == 34)
        #expect(right == 50)
    }

    @Test func channelBlock5GHz80MHzCh100to112() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 100, widthMHz: 80, band: .band5GHz, spanDirection: nil)
        #expect(left == 98)
        #expect(right == 114)
    }

    // MARK: - 5 GHz 160 MHz blocks

    @Test func channelBlock5GHz160MHzCh36to64() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 36, widthMHz: 160, band: .band5GHz, spanDirection: nil)
        #expect(left == 34)
        #expect(right == 66)
    }

    @Test func channelBlock5GHz160MHzCh100to128() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 100, widthMHz: 160, band: .band5GHz, spanDirection: nil)
        #expect(left == 98)
        #expect(right == 130)
    }

    // Channel 144 has no 160 MHz block — falls back to simple spanning
    @Test func channelBlock5GHz160MHzCh144NoBlock() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 144, widthMHz: 160, band: .band5GHz, spanDirection: nil)
        let half = ChannelSpanCalculator.channelHalfSpan(for: 160)
        #expect(left == 144 - half)
        #expect(right == 144 + half)
    }

    // MARK: - Fallback (6 GHz)

    @Test func channelBlock6GHz80MHzFallback() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 50, widthMHz: 80, band: .band6GHz, spanDirection: nil)
        let half = ChannelSpanCalculator.channelHalfSpan(for: 80)
        #expect(left == 50 - half)
        #expect(right == 50 + half)
    }

    @Test func channelBlock6GHz20MHzFallback() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 100, widthMHz: 20, band: .band6GHz, spanDirection: nil)
        #expect(left == 98)
        #expect(right == 102)
    }

    @Test func channelBlock6GHz160MHzFallback() {
        let (left, right) = ChannelSpanCalculator.channelBlock(
            primaryChannel: 100, widthMHz: 160, band: .band6GHz, spanDirection: nil)
        let half = ChannelSpanCalculator.channelHalfSpan(for: 160)
        #expect(left == 100 - half)
        #expect(right == 100 + half)
    }
}
