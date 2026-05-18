import SwiftUI

enum Constants {
    static let scanInterval: Duration = .seconds(3)
    static let uiUpdateInterval: Duration = .milliseconds(300)

    /// ApexCharts default color palette, matched for visual consistency.
    static let palette: [Color] = [
        Color(hex: "#008FFB"),
        Color(hex: "#00E396"),
        Color(hex: "#FEB019"),
        Color(hex: "#FF4560"),
        Color(hex: "#775DD0"),
        Color(hex: "#00D9E9"),
        Color(hex: "#546E7A"),
        Color(hex: "#26a69a"),
        Color(hex: "#D10CE8"),
        Color(hex: "#FF66C4"),
        Color(hex: "#FFC300"),
        Color(hex: "#93D500"),
        Color(hex: "#3B76D4"),
        Color(hex: "#A149FA"),
        Color(hex: "#1DE4BD"),
        Color(hex: "#FF6666"),
    ]

    static let graySSIDColor: Color = Color(hex: "#888888")
    static let filteredOutOpacity: Double = 0.15
    static let minZoomRange: Int = 2
    static let rssiNoiseFloor: Int = -100
}
