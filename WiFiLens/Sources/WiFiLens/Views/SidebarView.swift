import SwiftUI

enum SidebarPage: String, CaseIterable {
    case spectrum
    case channels
    case interfaces

    var label: String {
        switch self {
        case .spectrum:   String(localized: "Spectrum")
        case .channels:   String(localized: "Channels")
        case .interfaces: String(localized: "Interfaces")
        }
    }

    var icon: String {
        switch self {
        case .spectrum:   "antenna.radiowaves.left.and.right"
        case .channels:   "chart.bar.fill"
        case .interfaces: "cable.connector"
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
