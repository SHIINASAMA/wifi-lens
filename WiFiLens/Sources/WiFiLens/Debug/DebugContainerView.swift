import SwiftUI

#if DEBUG

enum DebugPage: String, CaseIterable {
    case spectrum
    case throughput
    case roaming

    var label: String {
        switch self {
        case .spectrum:   "Spectrum"
        case .throughput: "Throughput"
        case .roaming:    "Roaming"
        }
    }
}

struct DebugContainerView: View {
    @State private var selectedPage: DebugPage = .spectrum

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedPage) {
                ForEach(DebugPage.allCases, id: \.self) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 180)
            .padding(.vertical, 6)

            Divider()

            switch selectedPage {
            case .spectrum:
                DebugChartView()
            case .throughput:
                DebugThroughputView()
            case .roaming:
                DebugRoamingChartView()
            }
        }
    }
}

#endif
