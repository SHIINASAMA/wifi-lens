import SwiftUI

enum SecondaryToolbarItemID: String, Hashable {
    case channelsSimple = "channels-simple"
    case channelsTable = "channels-table"
    case interfacesSimple = "interfaces-simple"
    case interfacesDetails = "interfaces-details"
    case interfacesMonitor = "interfaces-monitor"
    case spectrumLive = "spectrum-live"
    case spectrumRecording = "spectrum-recording"
    case timelineAll = "timeline-all"
    case timelineToday = "timeline-today"
    case timelineYesterday = "timeline-yesterday"
    case timelineThisWeek = "timeline-this-week"
    case timelineCustom = "timeline-custom"
}

struct SecondaryToolbarItem: Identifiable, Equatable {
    let id: SecondaryToolbarItemID
    let title: String
    var isLocked: Bool = false
}

struct SecondaryToolbarDescriptor: Equatable {
    let items: [SecondaryToolbarItem]
    let defaultSelection: SecondaryToolbarItemID

    func selectionIndex(for id: SecondaryToolbarItemID) -> Int {
        items.firstIndex { $0.id == id } ?? items.firstIndex { $0.id == defaultSelection } ?? 0
    }

    static func forPage(_ page: SidebarPage) -> Self? {
        switch page {
        case .channels:
            return Self(
                items: [
                    SecondaryToolbarItem(
                        id: .channelsSimple,
                        title: String(localized: "channels.mode.simple", comment: "Simple view mode for channel quality")
                    ),
                    SecondaryToolbarItem(
                        id: .channelsTable,
                        title: String(localized: "channels.mode.professional", comment: "Professional view mode for channel quality")
                    ),
                ],
                defaultSelection: .channelsSimple
            )
        case .interfaces:
            return Self(
                items: [
                    SecondaryToolbarItem(
                        id: .interfacesSimple,
                        title: String(localized: "channels.mode.simple", comment: "Simple view mode for interfaces")
                    ),
                    SecondaryToolbarItem(
                        id: .interfacesDetails,
                        title: String(localized: "common.label.details", comment: "Details view mode label")
                    ),
                    SecondaryToolbarItem(
                        id: .interfacesMonitor,
                        title: String(localized: "interfaces.mode.monitor", comment: "Throughput monitor view mode")
                    ),
                ],
                defaultSelection: .interfacesSimple
            )
        case .spectrum:
#if PRO
            let recordingLocked = false
#else
            let recordingLocked = true
#endif
            return Self(
                items: [
                    SecondaryToolbarItem(
                        id: .spectrumLive,
                        title: String(localized: "spectrum.mode.live", comment: "Live spectrum mode")
                    ),
                    SecondaryToolbarItem(
                        id: .spectrumRecording,
                        title: String(localized: "spectrum.mode.recording_page", comment: "Recording page mode"),
                        isLocked: recordingLocked
                    ),
                ],
                defaultSelection: .spectrumLive
            )
        case .timeline:
#if PRO
            return Self(
                items: [
                    SecondaryToolbarItem(
                        id: .timelineAll,
                        title: String(localized: "timeline.filter.all", comment: "Timeline filter for all events")
                    ),
                    SecondaryToolbarItem(
                        id: .timelineToday,
                        title: String(localized: "timeline.filter.today", comment: "Timeline filter for today's events")
                    ),
                    SecondaryToolbarItem(
                        id: .timelineYesterday,
                        title: String(localized: "timeline.filter.yesterday", comment: "Timeline filter for yesterday's events")
                    ),
                    SecondaryToolbarItem(
                        id: .timelineThisWeek,
                        title: String(localized: "timeline.filter.this_week", comment: "Timeline filter for this week's events")
                    ),
                    SecondaryToolbarItem(
                        id: .timelineCustom,
                        title: String(localized: "timeline.filter.custom", comment: "Timeline filter for custom date range")
                    ),
                ],
                defaultSelection: .timelineToday
            )
#else
            return nil
#endif
        default:
            return nil
        }
    }
}

struct SecondaryToolbarSelections: Equatable {
    var channels: SecondaryToolbarItemID = .channelsSimple
    var interfaces: SecondaryToolbarItemID = .interfacesSimple
    var spectrum: SecondaryToolbarItemID = .spectrumLive
    var timeline: SecondaryToolbarItemID = .timelineToday

    func selection(for page: SidebarPage) -> SecondaryToolbarItemID? {
        switch page {
        case .channels:
            channels
        case .interfaces:
            interfaces
        case .spectrum:
            spectrum
        case .timeline:
            timeline
        default:
            nil
        }
    }

    mutating func setSelection(_ selection: SecondaryToolbarItemID, for page: SidebarPage) {
        switch page {
        case .channels:
            channels = selection
        case .interfaces:
            interfaces = selection
        case .spectrum:
            spectrum = selection
        case .timeline:
            timeline = selection
        default:
            break
        }
    }
}
