import SwiftUI

struct BLEScannerView: View {
    @Bindable var viewModel: BLEViewModel

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Divider()

            if viewModel.bluetoothState == .poweredOff {
                bluetoothOffView
            } else if viewModel.bluetoothState == .unauthorized
                        || viewModel.bluetoothPermission.authorizationStatus == .denied
                        || viewModel.bluetoothPermission.authorizationStatus == .restricted {
                unauthorizedView
            } else if viewModel.bluetoothPermission.authorizationStatus == .notDetermined {
                permissionRequiredView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.devices.isEmpty, viewModel.isScanning {
                scanningEmptyView
            } else if viewModel.devices.isEmpty {
                idleView
            } else {
                contentView
            }
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    Task { await viewModel.startScanning() }
                }
            } label: {
                Image(systemName: viewModel.isScanning ? "stop.fill" : "play.fill")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(viewModel.isScanning ? "Stop scanning" : "Start scanning")
            .disabled(viewModel.bluetoothState != .poweredOn)

            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            Text(stateLabel)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if !viewModel.devices.isEmpty {
                Text(String(localized: "\(viewModel.devices.count) devices"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            deviceTable
            if let history = viewModel.selectedDeviceHistory, history.count >= 2 {
                Divider()
                trendChartSection(history)
            }
        }
    }

    private var deviceTable: some View {
        Table(viewModel.displayedDevices, selection: $viewModel.selectedDeviceID) {
            TableColumn("Name") { device in
                HStack(spacing: 4) {
                    Circle()
                        .fill(rssiColor(device.smoothedRSSI))
                        .frame(width: 6, height: 6)
                    Text(device.displayName)
                        .font(.body)
                        .lineLimit(1)
                }
            }
            .width(min: 120, ideal: 160)

            TableColumn("Identifier") { device in
                Text(device.shortIdentifier)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("RSSI") { device in
                HStack(spacing: 4) {
                    Text("\(device.rssi)")
                        .font(.body.monospaced().bold())
                    Text("dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 60, ideal: 70)

            TableColumn("Smoothed") { device in
                Text(String(format: "%.0f dBm", device.smoothedRSSI))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Ads") { device in
                Text("\(device.advertisementCount)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            .width(min: 30, ideal: 40)

            TableColumn("Last Seen") { device in
                Text(formatTimeAgo(device.lastSeen))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 60, ideal: 80)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
    }

    private func trendChartSection(_ history: [BLERSSISample]) -> some View {
        let chartColor = rssiColor(viewModel.selectedDevice?.smoothedRSSI ?? -50)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let device = viewModel.selectedDevice {
                    Circle()
                        .fill(chartColor)
                        .frame(width: 8, height: 8)
                    Text("\(device.displayName) — RSSI history")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(chartColor.opacity(0.3)).frame(width: 6, height: 6)
                        Text("Raw").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(chartColor).frame(width: 6, height: 6)
                        Text("Smooth").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)

            BLETrendChartView(
                samples: history,
                color: chartColor
            )
            .id(viewModel.selectedDeviceID ?? "")
            .padding(.horizontal, 16)

            HStack(spacing: 16) {
                if let first = history.first {
                    LabeledContent("First") {
                        Text("\(first.rawRSSI) dBm")
                            .font(.caption.monospaced())
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                if let last = history.last {
                    LabeledContent("Latest") {
                        Text("\(last.rawRSSI) dBm")
                            .font(.caption.monospaced())
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                if let device = viewModel.selectedDevice {
                    LabeledContent("Samples") {
                        Text("\(history.count)")
                            .font(.caption.monospaced())
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    LabeledContent("EMA") {
                        Text(String(format: "%.0f dBm", device.smoothedRSSI))
                            .font(.caption.monospaced().bold())
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Empty / error states

    private var idleView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Tap play to start scanning for BLE devices")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var scanningEmptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Scanning for BLE devices…")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var bluetoothOffView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Bluetooth is turned off")
                .font(.body)
                .foregroundColor(.secondary)
            Text("Enable Bluetooth in System Settings to scan for BLE devices.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
            Spacer()
        }
    }

    private var unauthorizedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Bluetooth Permission Denied")
                .font(.body)
                .foregroundColor(.secondary)
            Text("Grant Bluetooth permission in Settings to scan for BLE devices.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var permissionRequiredView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Bluetooth Permission Required")
                .font(.body)
                .foregroundColor(.secondary)
            Text("Grant Bluetooth permission in Settings → Permissions to scan for nearby BLE devices.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch viewModel.bluetoothState {
        case .poweredOn where viewModel.isScanning:
            .green
        case .poweredOn:
            .blue
        case .poweredOff, .unsupported:
            .red
        case .unauthorized:
            .orange
        default:
            .gray
        }
    }

    private var stateLabel: String {
        viewModel.isScanning ? String(localized: "Scanning") : viewModel.bluetoothState.label
    }

    private func rssiColor(_ rssi: Double) -> Color {
        switch rssi {
        case ..<(-80): .red
        case ..<(-60): .yellow
        default:       .green
        }
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let delta = Date().timeIntervalSince(date)
        switch delta {
        case ..<1:   return String(localized: "now")
        case ..<60:  return String(localized: "\(Int(delta))s ago")
        case ..<3600: return String(localized: "\(Int(delta / 60))m ago")
        default:     return "—"
        }
    }
}
