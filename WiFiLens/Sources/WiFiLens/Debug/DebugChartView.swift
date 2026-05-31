import SwiftUI

#if DEBUG

private struct DebugOscillator {
    var phase: Double = 0

    mutating func advance(speed: Double) {
        phase += 0.025 * speed
    }

    func rssi(center: Int, amplitude: Int) -> Int {
        center + Int(Double(amplitude) * sin(phase))
    }
}

struct DebugChartView: View {
    @State private var bandVM = BandChartViewModel(band: .band5GHz)
    @State private var selectedNetworkID: String? = nil
    @State private var timer: Timer?

    // Oscillator
    @State private var oscillator = DebugOscillator()

    // Adjustable parameters
    @State private var centerRSSI: Double = -50
    @State private var amplitude: Double = 30
    @State private var speed: Double = 1.0
    @State private var channel: Int = 52
    @State private var channelWidthMHz: Int = 20
    @State private var selectedBand: ChannelBand = .band5GHz
    @State private var isRunning: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            BandChartView(
                model: bandVM.renderModel,
                selectedNetworkID: $selectedNetworkID,
                onResetZoom: { bandVM.resetZoom() },
                onToggleExpand: { bandVM.toggleExpand() },
                onApplyZoom: { lo, hi in bandVM.applyZoom(lo: lo, hi: hi) }
            )
            .padding(.horizontal, 8)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: selectedBand) { _, band in
            bandVM = BandChartViewModel(band: band)
            oscillator = DebugOscillator()
        }
        .onChange(of: isRunning) { _, running in
            if running { startTimer() } else { stopTimer() }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Button {
                    isRunning.toggle()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .help(isRunning ? "Pause" : "Resume")

                Picker("Band", selection: $selectedBand) {
                    Text("2.4 GHz").tag(ChannelBand.band24GHz)
                    Text("5 GHz").tag(ChannelBand.band5GHz)
                    Text("6 GHz").tag(ChannelBand.band6GHz)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 240)
            }

            HStack(spacing: 12) {
                paramSlider(label: "Center", value: $centerRSSI, range: -90...(-20), format: "%.0f dBm")
                paramSlider(label: "Amplitude", value: $amplitude, range: 0...45, format: "%.0f dB")
                paramSlider(label: "Speed", value: $speed, range: 0.1...5.0, format: "%.1f×")
                channelStepper
            }
        }
        .font(.system(size: 10))
    }

    private func paramSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label): \(String(format: format, value.wrappedValue))")
                .foregroundColor(.secondary)
            Slider(value: value, in: range) {
                Text(label)
            }
            .controlSize(.mini)
            .frame(width: 120)
        }
    }

    private var channelStepper: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Channel: \(channel)")
                    .foregroundColor(.secondary)
                Stepper("", value: $channel, in: 1...selectedBand.maxChannel)
                    .controlSize(.mini)
            }
            widthPicker
        }
    }

    private var widthPicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Width: \(channelWidthMHz) MHz")
                .foregroundColor(.secondary)
            Picker("", selection: $channelWidthMHz) {
                Text("20").tag(20)
                Text("40").tag(40)
                Text("80").tag(80)
                Text("160").tag(160)
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .frame(width: 140)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        oscillator.advance(speed: speed)
        let rssi = oscillator.rssi(center: Int(centerRSSI), amplitude: Int(amplitude))
        let block = ChannelSpanCalculator.channelBlock(
            primaryChannel: channel,
            widthMHz: channelWidthMHz,
            band: selectedBand,
            spanDirection: nil
        )
        let domain = ChartSeriesDomainData(
            id: "debug-signal",
            ssid: "TestSignal",
            bssid: "aa:bb:cc:dd:ee:ff",
            channel: channel,
            left: block.left,
            apex: Double(block.left + block.right) / 2.0,
            right: block.right,
            rssi: rssi,
            phyMode: "",
            channelWidth: "",
            supportsK: false,
            supportsR: false,
            supportsV: false,
            supportsWPA3: false,
            isHiddenSSID: false,
            security: "",
            mcs: "",
            nss: "",
            country: ""
        )
        let render = ChartSeriesRenderState(displayRSSI: Double(rssi), color: .blue, isVisible: true)
        let series = ChartSeriesData(domain: domain, render: render)
        bandVM.debugInject(series: [series])
    }
}

#endif
