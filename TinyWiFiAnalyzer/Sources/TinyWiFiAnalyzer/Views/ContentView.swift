import SwiftUI
import CoreLocation

struct ContentView: View {
    @Bindable var viewModel: ScannerViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            ScrollView {
                VStack(spacing: 16) {
                    if shouldShowEmptyState {
                        emptyState
                    } else {
                        ForEach(viewModel.bandViewModels, id: \.band.id) { bandVM in
                            BandChartView(viewModel: bandVM)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(minWidth: 600, idealWidth: 900, minHeight: 400)
        .task {
            await viewModel.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.handleSceneDidBecomeActive() }
            }
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle()
                    .fill(authStatusColor)
                    .frame(width: 6, height: 6)
                Text("Location: \(authStatusLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("State: \(accessStateLabel)")
                .font(.caption)
                .foregroundColor(.secondary)

            if !viewModel.interfaceName.isEmpty {
                Text("Interface: \(viewModel.interfaceName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let totalNetworks = viewModel.bandViewModels.reduce(0) { $0 + $1.allSeriesData.count }
            Text("Networks: \(totalNetworks)")
                .font(.caption)
                .foregroundColor(.secondary)

            let ssidCount = viewModel.bandViewModels.reduce(0) { count, vm in
                count + vm.allSeriesData.filter { $0.ssid != "n/a" }.count
            }
            Text("SSIDs: \(ssidCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    private var authStatusColor: Color {
        switch viewModel.locationManager.authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse: .green
        case .denied, .restricted: .red
        case .notDetermined: .orange
        @unknown default: .gray
        }
    }

    private var authStatusLabel: String {
        switch viewModel.locationManager.authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse: "Granted"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Pending"
        @unknown default: "Unknown"
        }
    }

    private var accessStateLabel: String {
        switch viewModel.accessState {
        case .waitingForAuthorization: "Waiting for authorization"
        case .denied: "Permission denied"
        case .scanning: "Scanning"
        case .grantedButSSIDUnavailable: "SSID unavailable"
        case .scanFailed: "Scan failed"
        }
    }

    private var shouldShowEmptyState: Bool {
        switch viewModel.accessState {
        case .waitingForAuthorization, .denied, .scanFailed:
            return true
        case .scanning, .grantedButSSIDUnavailable:
            return false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)

            switch viewModel.accessState {
            case .waitingForAuthorization:
                Text("Waiting for Location Services permission...")
                    .foregroundColor(.orange)
                Button("Open System Settings") {
                    viewModel.locationManager.openLocationPreferences()
                }

            case .denied:
                Text("Location Services permission is required to read Wi-Fi SSIDs.")
                    .foregroundColor(.secondary)
                Button("Open Location Preferences") {
                    viewModel.locationManager.openLocationPreferences()
                }

            case .grantedButSSIDUnavailable:
                Text("Permission is granted, but macOS is still not returning SSIDs.")
                    .foregroundColor(.secondary)
                Button("Open Location Preferences") {
                    viewModel.locationManager.openLocationPreferences()
                }

            case .scanFailed(let message):
                Text("Wi-Fi scan failed")
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .scanning:
                Text("Scanning for Wi-Fi networks...")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(minHeight: 300)
    }
}
