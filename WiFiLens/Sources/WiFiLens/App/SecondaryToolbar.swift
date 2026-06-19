import SwiftUI

enum SecondaryToolbarItemID: String, Hashable {
    case channelsSimple = "channels-simple"
    case channelsTable = "channels-table"
    case interfacesSimple = "interfaces-simple"
    case interfacesDetails = "interfaces-details"
    case interfacesMonitor = "interfaces-monitor"
#if PRO
    case spectrumLive = "spectrum-live"
    case spectrumRecording = "spectrum-recording"
#endif
}

struct SecondaryToolbarItem: Identifiable, Equatable {
    let id: SecondaryToolbarItemID
    let title: String
}

struct SecondaryToolbarDescriptor: Equatable {
    let items: [SecondaryToolbarItem]
    let defaultSelection: SecondaryToolbarItemID

    func selectionIndex(for id: SecondaryToolbarItemID) -> Int {
        items.firstIndex { $0.id == id } ?? items.firstIndex { $0.id == defaultSelection } ?? 0
    }

    func itemID(at index: Int) -> SecondaryToolbarItemID? {
        guard items.indices.contains(index) else { return nil }
        return items[index].id
    }

    static func forPage(_ page: SidebarPage) -> Self? {
        switch page {
        case .channels:
            Self(
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
            Self(
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
#if PRO
        case .spectrum:
            Self(
                items: [
                    SecondaryToolbarItem(
                        id: .spectrumLive,
                        title: String(localized: "spectrum.mode.live", comment: "Live spectrum mode")
                    ),
                    SecondaryToolbarItem(
                        id: .spectrumRecording,
                        title: String(localized: "spectrum.mode.recording_page", comment: "Recording page mode")
                    ),
                ],
                defaultSelection: .spectrumLive
            )
#endif
        default:
            nil
        }
    }
}

extension SidebarPage {
    var supportsSecondaryToolbar: Bool {
        SecondaryToolbarDescriptor.forPage(self) != nil
    }
}

enum DetailPageRenderPolicy {
    static func shouldRender(_ page: SidebarPage, selectedPage: SidebarPage) -> Bool {
        page == selectedPage
    }

    static func needsConditionalRendering(_ page: SidebarPage) -> Bool {
        switch page {
        case .spectrum, .interfaces:
            return true
        default:
            return false
        }
    }
}
