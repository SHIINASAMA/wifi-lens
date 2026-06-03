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
    @State private var visitedTabs: Set<DebugPage> = [.spectrum]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedPage.animation(.bouncy)) {
                ForEach(DebugPage.allCases, id: \.self) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .frame(width: 180)
            .padding(.vertical, 6)
            .onChange(of: selectedPage) { _, newTab in
                visitedTabs.insert(newTab)
            }

            Divider()

            ZStack {
                if visitedTabs.contains(.spectrum) {
                    DebugChartView()
                        .opacity(selectedPage == .spectrum ? 1 : 0)
                        .allowsHitTesting(selectedPage == .spectrum)
                        .disabled(selectedPage != .spectrum)
                }

                if visitedTabs.contains(.throughput) {
                    DebugThroughputView()
                        .opacity(selectedPage == .throughput ? 1 : 0)
                        .allowsHitTesting(selectedPage == .throughput)
                        .disabled(selectedPage != .throughput)
                }

                if visitedTabs.contains(.roaming) {
                    DebugRoamingChartView()
                        .opacity(selectedPage == .roaming ? 1 : 0)
                        .allowsHitTesting(selectedPage == .roaming)
                        .disabled(selectedPage != .roaming)
                }
            }
        }
    }
}

#endif
