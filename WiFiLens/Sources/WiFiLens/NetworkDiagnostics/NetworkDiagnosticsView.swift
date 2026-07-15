import SwiftUI

struct NetworkDiagnosticsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: NetworkDiagnosticsViewModel

    var body: some View {
        GeometryReader { geometry in
            let layoutMode = NetworkDiagnosticsWorkbenchLayout.mode(for: geometry.size.width)

            VStack(spacing: 0) {
                commandBar
                Divider()

                if viewModel.phase == .running {
                    progressStrip
                    Divider()
                } else if let conclusion = viewModel.conclusion {
                    conclusionStrip(conclusion)
                    Divider()
                }

                workspace(layoutMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: viewModel.phase)
    }

    private var commandBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                commandIdentity
                Spacer(minLength: 20)
                stateIndicator
                actionButton
            }

            VStack(alignment: .leading, spacing: 12) {
                commandIdentity
                HStack(spacing: 12) {
                    stateIndicator
                    Spacer(minLength: 12)
                    actionButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var commandIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(String(localized: "nav.network_diagnostics", comment: "Network Self-Check page title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "stethoscope")
                    .foregroundStyle(Color.accentColor)
            }

            Text(String(localized: "network_diagnostics.description", comment: "Network self-check page description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.phase {
        case .idle:
            Label(
                String(localized: "network_diagnostics.state.waiting", comment: "Network self-check waiting state"),
                systemImage: "circle.dotted"
            )
            .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(String(localized: "network_diagnostics.state.checking", comment: "Network self-check running state"))
            }
        case .completed:
            if let conclusion = viewModel.conclusion {
                Label(conclusionTitle(conclusion), systemImage: conclusionIcon(conclusion))
                    .foregroundStyle(conclusionColor(conclusion))
            }
        }
    }

    private var actionButton: some View {
        Button {
            viewModel.start()
        } label: {
            Label(actionTitle, systemImage: actionIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(viewModel.phase == .running)
        .fixedSize()
        .accessibilityIdentifier("network-diagnostics-run")
    }

    private var progressStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: activeCheckID.map(checkIcon) ?? "stethoscope")
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)

                if let activeCheckID {
                    Text(checkTitle(activeCheckID))
                        .font(.callout.weight(.semibold))
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 16)

                Text("\(viewModel.results.count)/\(NetworkDiagnosticCheckID.allCases.count)")
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(viewModel.results.count),
                total: Double(NetworkDiagnosticCheckID.allCases.count)
            )
            .progressViewStyle(.linear)
            .accessibilityLabel(String(localized: "network_diagnostics.state.checking", comment: "Network self-check running state"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.06))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("network-diagnostics-progress")
    }

    private func conclusionStrip(_ conclusion: NetworkDiagnosticConclusion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: conclusionIcon(conclusion))
                .font(.title3.weight(.semibold))
                .foregroundStyle(conclusionColor(conclusion))
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(conclusionTitle(conclusion))
                    .font(.callout.weight(.semibold))
                Text(conclusionMessage(conclusion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(conclusionColor(conclusion).opacity(0.06))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("network-diagnostics-conclusion")
    }

    @ViewBuilder
    private func workspace(_ mode: NetworkDiagnosticsWorkbenchLayoutMode) -> some View {
        if viewModel.phase == .idle {
            readyWorkspace
        } else {
            resultTable(mode)
        }
    }

    private var readyWorkspace: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "network_diagnostics.state.waiting", comment: "Network self-check ready state"))
                    .font(.callout.weight(.semibold))
                Text(String(localized: "network_diagnostics.ready.message", comment: "Instructions shown before running network diagnostics"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func resultTable(_ mode: NetworkDiagnosticsWorkbenchLayoutMode) -> some View {
        Group {
            switch mode {
            case .regular:
                Table(workbenchRows) {
                    TableColumn(columnCheckTitle) { row in
                        checkCell(row)
                            .padding(.vertical, 7)
                    }
                    .width(min: 150, ideal: 190)

                    TableColumn(columnStatusTitle) { row in
                        statusCell(row)
                            .padding(.vertical, 7)
                    }
                    .width(min: 112, ideal: 132)

                    TableColumn(columnResultTitle) { row in
                        resultCell(row)
                            .padding(.vertical, 7)
                    }
                }
            case .condensed:
                Table(workbenchRows) {
                    TableColumn(columnCheckTitle) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            checkCell(row)
                            statusCell(row)
                        }
                        .padding(.vertical, 7)
                    }
                    .width(min: 178, ideal: 220)

                    TableColumn(columnResultTitle) { row in
                        resultCell(row)
                            .padding(.vertical, 7)
                    }
                }
            case .compact:
                Table(workbenchRows) {
                    TableColumn(columnResultTitle) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 12) {
                                checkCell(row)
                                Spacer(minLength: 8)
                                statusCell(row)
                            }
                            resultCell(row)
                        }
                        .padding(.vertical, 7)
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, NetworkDiagnosticsTablePresentation.minimumRowHeight)
        .alternatingRowBackgrounds(
            NetworkDiagnosticsTablePresentation.usesAlternatingRowBackgrounds ? .enabled : .disabled
        )
    }

    private func checkCell(_ row: NetworkDiagnosticsWorkbenchRow) -> some View {
        Label {
            Text(checkTitle(row.id))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: checkIcon(row.id))
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func statusCell(_ row: NetworkDiagnosticsWorkbenchRow) -> some View {
        if let result = row.result {
            Label(statusTitle(result.status), systemImage: statusIcon(result.status))
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor(result.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(result.status).opacity(0.10), in: Capsule())
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(String(localized: "network_diagnostics.state.checking", comment: "Network self-check item running state"))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.10), in: Capsule())
        }
    }

    @ViewBuilder
    private func resultCell(_ row: NetworkDiagnosticsWorkbenchRow) -> some View {
        if let result = row.result {
            Text(result.summary)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workbenchRows: [NetworkDiagnosticsWorkbenchRow] {
        NetworkDiagnosticsPresentation.workbenchRows(
            pagePhase: viewModel.phase,
            executionPhases: viewModel.executionPhases,
            results: viewModel.results
        )
    }

    private var activeCheckID: NetworkDiagnosticCheckID? {
        NetworkDiagnosticCheckID.allCases.first {
            viewModel.executionPhases[$0] == .checking
        }
    }

    private var columnCheckTitle: String {
        String(localized: "network_diagnostics.report.column.check", comment: "Diagnostic workbench check column title")
    }

    private var columnStatusTitle: String {
        String(localized: "network_diagnostics.report.column.status", comment: "Diagnostic workbench status column title")
    }

    private var columnResultTitle: String {
        String(localized: "network_diagnostics.report.column.result", comment: "Diagnostic workbench result column title")
    }

    private var actionTitle: String {
        switch viewModel.phase {
        case .idle:
            String(localized: "network_diagnostics.action.run", comment: "Start the network self-check button")
        case .running:
            String(localized: "network_diagnostics.state.checking", comment: "Network self-check running state")
        case .completed:
            String(localized: "network_diagnostics.action.run_again", comment: "Run the network self-check again button")
        }
    }

    private var actionIcon: String {
        switch viewModel.phase {
        case .idle: "play.fill"
        case .running: "hourglass"
        case .completed: "arrow.clockwise"
        }
    }

    private func checkTitle(_ id: NetworkDiagnosticCheckID) -> String {
        switch id {
        case .connectivity:
            String(localized: "network_diagnostics.check.connectivity.title", comment: "Network connectivity check title")
        case .dns:
            String(localized: "network_diagnostics.check.dns.title", comment: "DNS resolution check title")
        case .proxy:
            String(localized: "network_diagnostics.check.proxy.title", comment: "System proxy check title")
        }
    }

    private func checkIcon(_ id: NetworkDiagnosticCheckID) -> String {
        switch id {
        case .connectivity: "network"
        case .dns: "globe"
        case .proxy: "arrow.triangle.branch"
        }
    }

    private func statusTitle(_ status: NetworkDiagnosticStatus) -> String {
        switch status {
        case .normal:
            String(localized: "network_diagnostics.status.normal", comment: "Normal network self-check status")
        case .abnormal:
            String(localized: "network_diagnostics.status.abnormal", comment: "Abnormal network self-check status")
        case .indeterminate:
            String(localized: "network_diagnostics.status.indeterminate", comment: "Indeterminate network self-check status")
        }
    }

    private func statusIcon(_ status: NetworkDiagnosticStatus) -> String {
        switch status {
        case .normal: "checkmark.circle.fill"
        case .abnormal: "xmark.circle.fill"
        case .indeterminate: "questionmark.circle.fill"
        }
    }

    private func statusColor(_ status: NetworkDiagnosticStatus) -> Color {
        switch status {
        case .normal: .green
        case .abnormal: .red
        case .indeterminate: .orange
        }
    }

    private func conclusionTitle(_ conclusion: NetworkDiagnosticConclusion) -> String {
        switch conclusion {
        case .networkNormal:
            String(localized: "network_diagnostics.conclusion.normal.title", comment: "Network self-check normal conclusion title")
        case .needsAttention:
            String(localized: "network_diagnostics.conclusion.attention.title", comment: "Network self-check attention conclusion title")
        case .networkUnavailable:
            String(localized: "network_diagnostics.conclusion.unavailable.title", comment: "Network self-check unavailable conclusion title")
        }
    }

    private func conclusionMessage(_ conclusion: NetworkDiagnosticConclusion) -> String {
        switch conclusion {
        case .networkNormal:
            String(localized: "network_diagnostics.conclusion.normal.message", comment: "Network self-check normal conclusion message")
        case .needsAttention:
            String(localized: "network_diagnostics.conclusion.attention.message", comment: "Network self-check attention conclusion message")
        case .networkUnavailable:
            String(localized: "network_diagnostics.conclusion.unavailable.message", comment: "Network self-check unavailable conclusion message")
        }
    }

    private func conclusionIcon(_ conclusion: NetworkDiagnosticConclusion) -> String {
        switch conclusion {
        case .networkNormal: "checkmark.circle.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .networkUnavailable: "wifi.slash"
        }
    }

    private func conclusionColor(_ conclusion: NetworkDiagnosticConclusion) -> Color {
        switch conclusion {
        case .networkNormal: .green
        case .needsAttention: .orange
        case .networkUnavailable: .red
        }
    }
}
