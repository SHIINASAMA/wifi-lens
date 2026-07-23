import SwiftUI

struct MACVendorDatabaseSettingsSection: View {
    @Bindable var manager: MACVendorDatabaseManager
    @AppStorage("remindWhenMACVendorDatabaseEmpty") private var remindWhenEmpty = true
    @State private var showsUpdateSheet = false
    @State private var showsClearConfirmation = false

    private var clearIsDisabled: Bool {
        guard manager.operation == .idle else { return true }
        switch manager.availability {
        case .loading, .notInstalled:
            return true
        case .installed, .unavailable:
            return false
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { !showsUpdateSheet && manager.presentedError != nil },
            set: { isPresented in
                if !isPresented {
                    manager.dismissPresentedError()
                }
            }
        )
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                availabilityContent

                Divider()

                Toggle(
                    String(localized: "settings.mac_vendor.remind_when_empty", comment: "Remind the user when the MAC vendor database is empty"),
                    isOn: $remindWhenEmpty
                )
                .accessibilityLabel(String(localized: "settings.mac_vendor.remind_when_empty", comment: "Remind the user when the MAC vendor database is empty"))
                .accessibilityValue(
                    remindWhenEmpty
                        ? String(localized: "common.label.on", comment: "Enabled toggle accessibility value")
                        : String(localized: "common.label.off", comment: "Disabled toggle accessibility value")
                )
                .accessibilityHint(String(localized: "settings.mac_vendor.remind_when_empty_hint", comment: "Show a reminder when no local MAC vendor database is installed"))
                .accessibilityIdentifier("settings-mac-vendor-reminder-toggle")

                HStack(spacing: 8) {
                    Button(String(localized: "settings.mac_vendor.update_action", comment: "Open the MAC vendor database update sheet")) {
                        showsUpdateSheet = true
                    }
                    .disabled(manager.operation != .idle || manager.availability == .loading)
                    .accessibilityLabel(String(localized: "settings.mac_vendor.update_action", comment: "Open the MAC vendor database update sheet"))
                    .accessibilityHint(String(localized: "settings.mac_vendor.update_action_hint", comment: "Choose an IEEE download or manual CSV import"))
                    .accessibilityIdentifier("settings-mac-vendor-update-button")

                    Button(
                        String(localized: "settings.mac_vendor.clear_action", comment: "Open confirmation to clear the local MAC vendor database"),
                        role: .destructive
                    ) {
                        showsClearConfirmation = true
                    }
                    .disabled(clearIsDisabled)
                    .accessibilityLabel(String(localized: "settings.mac_vendor.clear_action", comment: "Open confirmation to clear the local MAC vendor database"))
                    .accessibilityHint(String(localized: "settings.mac_vendor.clear_action_hint", comment: "Remove local vendor registry data without changing the reminder preference"))
                    .accessibilityIdentifier("settings-mac-vendor-clear-button")
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "settings.mac_vendor.header", comment: "MAC vendor database settings section heading"))
        } footer: {
            Text(String(localized: "settings.mac_vendor.footer", comment: "The MAC vendor database stays on this Mac and is only updated manually"))
        }
        .sheet(isPresented: $showsUpdateSheet) {
            MACVendorDatabaseUpdateSheet(manager: manager)
        }
        .confirmationDialog(
            String(localized: "settings.mac_vendor.clear_confirmation_title", comment: "Confirm clearing the local MAC vendor database"),
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "settings.mac_vendor.clear_confirmation_action", comment: "Confirm removal of the local MAC vendor database"),
                role: .destructive
            ) {
                Task { await manager.clear() }
            }
            Button(String(localized: "common.action.cancel", comment: "Cancel clearing the MAC vendor database"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.mac_vendor.clear_confirmation_message", comment: "Clearing removes local vendor names but preserves the reminder preference"))
        }
        .alert(
            manager.presentedError?.localizedTitle
                ?? String(localized: "settings.mac_vendor.error.title", comment: "Generic MAC vendor database error title"),
            isPresented: errorIsPresented,
            presenting: manager.presentedError
        ) { _ in
            Button(String(localized: "common.action.dismiss", comment: "Dismiss an error alert"), role: .cancel) {}
        } message: { error in
            Text(error.localizedMessage)
        }
    }

    @ViewBuilder
    private var availabilityContent: some View {
        switch manager.availability {
        case .loading:
            statusRow(
                icon: "clock",
                status: String(localized: "settings.mac_vendor.status_loading", comment: "MAC vendor database status while loading"),
                color: .secondary
            )
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(String(localized: "settings.mac_vendor.status_loading", comment: "MAC vendor database status while loading"))
        case .notInstalled:
            statusRow(
                icon: "tray",
                status: String(localized: "settings.mac_vendor.status_not_installed", comment: "MAC vendor database is not installed"),
                color: .secondary
            )
        case let .installed(summary):
            statusRow(
                icon: "checkmark.circle.fill",
                status: String(localized: "settings.mac_vendor.status_installed", comment: "MAC vendor database is installed"),
                color: .green
            )
            installedDetailRows(summary)
        case let .unavailable(error):
            statusRow(
                icon: "exclamationmark.triangle.fill",
                status: String(localized: "settings.mac_vendor.status_unavailable", comment: "MAC vendor database could not be loaded"),
                color: .orange
            )
            Text(error.localizedMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(String(localized: "settings.mac_vendor.unavailable_reason", comment: "Reason the MAC vendor database is unavailable"))
                .accessibilityValue(error.localizedMessage)
        }
    }

    private func statusRow(icon: String, status: String, color: Color) -> some View {
        LabeledContent(String(localized: "settings.mac_vendor.status_label", comment: "MAC vendor database status field label")) {
            Label(status, systemImage: icon)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "settings.mac_vendor.status_label", comment: "MAC vendor database status field label"))
        .accessibilityValue(status)
    }

    @ViewBuilder
    private func installedDetailRows(_ summary: MACVendorDatabaseSummary) -> some View {
        let source = localizedSource(summary.source)
        let date = summary.createdAt.formatted(date: .abbreviated, time: .shortened)
        let count = summary.totalRecordCount.formatted()

        LabeledContent(String(localized: "settings.mac_vendor.source_label", comment: "MAC vendor database source field label"), value: source)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "settings.mac_vendor.source_label", comment: "MAC vendor database source field label"))
            .accessibilityValue(source)

        LabeledContent(String(localized: "settings.mac_vendor.updated_label", comment: "MAC vendor database update date field label"), value: date)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "settings.mac_vendor.updated_label", comment: "MAC vendor database update date field label"))
            .accessibilityValue(date)

        LabeledContent(String(localized: "settings.mac_vendor.records_label", comment: "MAC vendor database record count field label"), value: count)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "settings.mac_vendor.records_label", comment: "MAC vendor database record count field label"))
            .accessibilityValue(count)
    }

    private func localizedSource(_ source: MACVendorDatabaseSource) -> String {
        switch source {
        case .ieeeDownload:
            String(localized: "settings.mac_vendor.source_ieee", comment: "Database source: downloaded directly from IEEE")
        case .manualImport:
            String(localized: "settings.mac_vendor.source_manual", comment: "Database source: manually imported IEEE CSV files")
        }
    }
}

#if DEBUG
private struct MACVendorDatabaseSettingsSectionPreview: View {
    @State private var manager = MACVendorDatabasePreviewFactory.makeManager()

    var body: some View {
        Form {
            MACVendorDatabaseSettingsSection(manager: manager)
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 480)
        .task {
            await manager.loadInstalledDatabase()
        }
    }
}

#Preview("MAC vendor database settings") {
    MACVendorDatabaseSettingsSectionPreview()
}
#endif
