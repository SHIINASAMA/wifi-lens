import SwiftUI

enum SidebarPage: String, CaseIterable {
    case overview
    case spectrum
    case channels
    case interfaces
    case helpCenter

    var label: String {
        switch self {
        case .overview:   String(localized: "Overview")
        case .spectrum:   String(localized: "Spectrum")
        case .channels:   String(localized: "Channels")
        case .interfaces: String(localized: "Interfaces")
        case .helpCenter: String(localized: "Help Center")
        }
    }

    var icon: String {
        switch self {
        case .overview:   "house"
        case .spectrum:   "antenna.radiowaves.left.and.right"
        case .channels:   "chart.bar.fill"
        case .interfaces: "cable.connector"
        case .helpCenter: "questionmark.circle"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedPage: SidebarPage

    var body: some View {
        List(selection: $selectedPage) {
            Section {
                ForEach(SidebarPage.allCases, id: \.self) { page in
                    Label(page.label, systemImage: page.icon)
                        .tag(page)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160, idealWidth: 180)
        .navigationTitle("WiFi Lens")
    }
}
