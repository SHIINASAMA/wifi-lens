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
        case .bleScanner: "personalhotspot"
        case .help:       "questionmark.circle"
        case .settings:   "gearshape"
#if DEBUG
        case .debugChart: "ladybug"
#endif
        }
    }
}

private struct BluetoothIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Main vertical spine: M128 36V220
        path.move(to: CGPoint(x: w * 0.5, y: h * 36.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 220.0 / 256.0))

        // Upper right diamond: M128 128L190 74L128 36
        path.move(to: CGPoint(x: w * 0.5, y: h * 128.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 190.0 / 256.0, y: h * 74.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 36.0 / 256.0))

        // Lower right diamond: M128 128L190 182L128 220
        path.move(to: CGPoint(x: w * 0.5, y: h * 128.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 190.0 / 256.0, y: h * 182.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 220.0 / 256.0))

        // Left crossing arms: M66 74L128 128L66 182
        path.move(to: CGPoint(x: w * 66.0 / 256.0, y: h * 74.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 128.0 / 256.0))
        path.addLine(to: CGPoint(x: w * 66.0 / 256.0, y: h * 182.0 / 256.0))

        return path
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
                    if page == .bleScanner {
                        Label(title: { Text(page.label) }, icon: {
                            BluetoothIconShape()
                                .stroke(.foreground, style: .init(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                                .frame(width: 16, height: 16)
                        })
                            .tag(page)
                    } else {
                        Label(page.label, systemImage: page.icon)
                            .tag(page)
                    }
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
