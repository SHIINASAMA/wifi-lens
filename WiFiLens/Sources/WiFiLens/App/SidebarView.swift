import SwiftUI

enum SidebarPage: String, CaseIterable {
    case overview
    case spectrum
    case channels
    case interfaces
    case roaming
    case bleScanner
    case help
    case settings
#if DEBUG
    case debugChart
#endif

    var requiresLocationAuthorization: Bool {
        switch self {
        case .overview, .help, .settings, .bleScanner:
            false
        case .spectrum, .channels, .interfaces, .roaming:
            true
#if DEBUG
        case .debugChart:
            true
#endif
        }
    }

    var label: String {
        switch self {
        case .overview:   String(localized: "Overview")
        case .spectrum:   String(localized: "Spectrum")
        case .channels:   String(localized: "Channels")
        case .interfaces: String(localized: "Interfaces")
        case .roaming:   String(localized: "Roaming Test")
        case .bleScanner: String(localized: "BLE Scanner")
        case .help:       String(localized: "Help")
        case .settings:   String(localized: "Settings")
#if DEBUG
        case .debugChart: "Debug Chart"
#endif
        }
    }

    var icon: String {
        switch self {
        case .overview:   "house"
        case .spectrum:   "antenna.radiowaves.left.and.right"
        case .channels:   "chart.bar.fill"
        case .interfaces: "cable.connector"
        case .roaming:   "arrow.triangle.swap"
        case .bleScanner: "wave.3.right"
        case .help:       "questionmark.circle"
        case .settings:   "gearshape"
#if DEBUG
        case .debugChart: "ladybug"
#endif
        }
    }
}

struct SidebarView: View {
    @Binding var selectedPage: SidebarPage
    var locationManager: LocationPermissionManager

    var body: some View {
        List(selection: $selectedPage) {
            Section {
                Label(SidebarPage.overview.label, systemImage: SidebarPage.overview.icon)
                    .tag(SidebarPage.overview)
            }
            Divider()
            Section {
                ForEach([SidebarPage.spectrum, .channels, .interfaces, .roaming, .bleScanner], id: \.self) { page in
                    Label(page.label, systemImage: page.icon)
                        .tag(page)
                }
#if DEBUG
                Label(SidebarPage.debugChart.label, systemImage: SidebarPage.debugChart.icon)
                    .tag(SidebarPage.debugChart)
#endif
            }
            Divider()
            Section {
//                Label(SidebarPage.help.label, systemImage: SidebarPage.help.icon)
//                    .tag(SidebarPage.help)
                Label(SidebarPage.settings.label, systemImage: SidebarPage.settings.icon)
                    .tag(SidebarPage.settings)
            }
        }
        .background(.ultraThinMaterial)
        .frame(minWidth: 160, idealWidth: 180)
    }
}
