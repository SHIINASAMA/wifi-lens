import SwiftUI

#if DEBUG

enum SpectrumDebugPage: String, CaseIterable {
    case singleAP
    case multiAP

    var label: String {
        switch self {
        case .singleAP: "Single AP"
        case .multiAP:  "Multi AP"
        }
    }
}

enum DebugPage: String, CaseIterable {
    case throughput
    case roaming

    var label: String {
        switch self {
        case .throughput: "Throughput"
        case .roaming:    "Roaming"
        }
    }
}

struct SpectrumDebugContainerView: View {
    @State private var selectedPage: SpectrumDebugPage = .singleAP
    @State private var visitedTabs: Set<SpectrumDebugPage> = [.singleAP]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedPage.animation(.bouncy)) {
                ForEach(SpectrumDebugPage.allCases, id: \.self) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .frame(width: 220)
            .padding(.vertical, 6)
            .onChange(of: selectedPage) { _, newTab in
                visitedTabs.insert(newTab)
            }

            Divider()

            ZStack {
                if visitedTabs.contains(.singleAP) {
                    DebugChartView(mode: .singleAP)
                        .opacity(selectedPage == .singleAP ? 1 : 0)
                        .allowsHitTesting(selectedPage == .singleAP)
                        .disabled(selectedPage != .singleAP)
                }

                if visitedTabs.contains(.multiAP) {
                    DebugChartView(mode: .multiAP)
                        .opacity(selectedPage == .multiAP ? 1 : 0)
                        .allowsHitTesting(selectedPage == .multiAP)
                        .disabled(selectedPage != .multiAP)
                }
            }
        }
    }
}

struct DebugContainerView: View {
    @State private var selectedPage: DebugPage = .throughput
    @State private var visitedTabs: Set<DebugPage> = [.throughput]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedPage.animation(.bouncy)) {
                ForEach(DebugPage.allCases, id: \.self) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .frame(width: 220)
            .padding(.vertical, 6)
            .onChange(of: selectedPage) { _, newTab in
                visitedTabs.insert(newTab)
            }

            Divider()

            ZStack {
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
