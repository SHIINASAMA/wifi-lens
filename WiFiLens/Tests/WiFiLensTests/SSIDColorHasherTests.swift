import Testing
import SwiftUI
@testable import WiFiLens

struct SSIDColorHasherTests {

    let hasher = SSIDColorHasher()

    @Test func sameSSIDReturnsSameColor() {
        let color1 = hasher.color(for: "MyNetwork")
        let color2 = hasher.color(for: "MyNetwork")
        #expect(color1 == color2)
    }

    @Test func differentSSIDsReturnDistinctColors() {
        let color1 = hasher.color(for: "NetworkA")
        let color2 = hasher.color(for: "NetworkB")
        // Extremely unlikely to collide, but not impossible with 16 colors.
        // This is a probabilistic test — if it fails, it's worth investigating.
        #expect(color1 != color2)
    }

    @Test func nilSSIDReturnsGray() {
        let color = hasher.color(for: nil)
        #expect(color == Constants.graySSIDColor)
    }

    @Test func naSSIDReturnsGray() {
        let color = hasher.color(for: "n/a")
        #expect(color == Constants.graySSIDColor)
    }

    @Test func naSSIDCaseInsensitiveReturnsGray() {
        let color = hasher.color(for: "N/A")
        #expect(color == Constants.graySSIDColor)
    }

    @Test func emptySSIDReturnsGray() {
        let color = hasher.color(for: "")
        #expect(color == Constants.graySSIDColor)
    }

    @Test func colorIsFromPalette() {
        let color = hasher.color(for: "test")
        // The returned color should be from the palette (not gray)
        #expect(color != Constants.graySSIDColor)
    }
}
