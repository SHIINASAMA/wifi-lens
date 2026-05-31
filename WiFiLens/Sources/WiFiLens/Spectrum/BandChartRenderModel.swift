import Foundation
import SwiftUI

struct BandChartRenderModel {
    let xDataMin: Int
    let xDataMax: Int
    let yMin: Double
    let visibleSeriesData: [ChartSeriesData]
    let displayedSeriesData: [ChartSeriesData]
    let strongestRSSI: Int
    let isEmpty: Bool
    let zoomMin: Double?
    let zoomMax: Double?
    let isExpanded: Bool
    let axisTickStartChannel: Int
}
