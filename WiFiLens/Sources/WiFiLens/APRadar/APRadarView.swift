import SwiftUI

/// AP Radar page: select an access point, track its BSSID, and get audio
/// pulse feedback whose interval follows the smoothed RSSI.
struct APRadarView: View {
    @Bindable var viewModel: APRadarViewModel
    /// True when this is the selected sidebar page. Pages stay mounted in the
    /// detail ZStack, so page switches must be observed explicitly.
    var isActive: Bool
    var onRescan: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSelection = false

    /// Shared layout metrics so every card on the page reads as one system,
    /// matching the rest of the app (see OverviewView).
    private static let contentMaxWidth: CGFloat = 640
    private static let cardRadius: CGFloat = 12
    private static let pagePadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
            Divider()

            switch viewModel.state {
            case .idle:
                idleContent
            case .tracking(let snapshot):
                trackingContent(snapshot)
            case .signalLost(let snapshot):
                signalLostContent(snapshot)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.setActive(isActive)
        }
        .onChange(of: isActive) { _, active in
            viewModel.setActive(active)
        }
        .onDisappear {
            viewModel.setActive(false)
        }
        .sheet(isPresented: $showSelection) {
            APSelectionView(
                viewModel: viewModel,
                onSelect: { option in
                    showSelection = false
                    viewModel.selectTarget(option)
                },
                onRescan: onRescan,
                onCancel: { showSelection = false }
            )
        }
        .accessibilityIdentifier("page-apRadar")
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(String(localized: "nav.apRadar", comment: "AP Radar sidebar navigation item"))
                .font(.title3.weight(.semibold))
            SidebarBadge(style: .experimental)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// Adaptive layout metrics for the page. `regular` is the comfortable
    /// layout at normal window sizes; `compact` tightens spacing and shrinks
    /// the radar so small windows avoid needless scrolling.
    private struct RadarFit {
        var spacing: CGFloat
        var cardSpacing: CGFloat
        var rssiFontSize: CGFloat
        var statusIconSize: CGFloat
        var statusIconContainer: CGFloat
        var isCompact: Bool

        static let regular = RadarFit(
            spacing: 16,
            cardSpacing: 16,
            rssiFontSize: 44,
            statusIconSize: 30,
            statusIconContainer: 72,
            isCompact: false
        )
        static let compact = RadarFit(
            spacing: 10,
            cardSpacing: 10,
            rssiFontSize: 34,
            statusIconSize: 24,
            statusIconContainer: 56,
            isCompact: true
        )
    }

    /// Wraps a state layout so it is centered without scrolling whenever it
    /// fits the available height, then tries a compact layout, and finally
    /// falls back to a scroll view when the window is too small. Prevents
    /// clipped cards and needless scrollbars at the minimum window size.
    ///
    /// Content is centered with `Spacer`s because they collapse to zero during
    /// ideal-size measurement; `.frame(maxHeight: .infinity)` instead claims
    /// to fit any height and defeats the `ViewThatFits` fallback.
    @ViewBuilder
    private func fittingContent<Regular: View, Compact: View>(
        @ViewBuilder regular: () -> Regular,
        @ViewBuilder compact: () -> Compact
    ) -> some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                regular()
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                compact()
                Spacer(minLength: 0)
            }
            ScrollView {
                compact()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Idle

    private var idleContent: some View {
        fittingContent(
            regular: { idleLayout(fit: .regular) },
            compact: { idleLayout(fit: .compact) }
        )
    }

    private func idleLayout(fit: RadarFit) -> some View {
        VStack(spacing: fit.spacing) {
            VStack(spacing: fit.cardSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: fit.statusIconContainer, height: fit.statusIconContainer)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: fit.statusIconSize, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)
                .padding(.top, 6)

                VStack(spacing: 8) {
                    Text(String(localized: "apRadar.description", comment: "AP Radar feature description on the idle page"))
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text(String(localized: "apRadar.disclaimer", comment: "AP Radar disclaimer about RSSI-only guidance"))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 440)

                Button {
                    showSelection = true
                } label: {
                    Label(
                        String(localized: "apRadar.selectTarget", comment: "Button to choose an access point to track"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if viewModel.latestNetworks.isEmpty {
                    emptyScanState
                } else {
                    Label(selectionSummary, systemImage: "wifi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.scanFailed {
                    Label(
                        String(localized: "apRadar.scan.failed", comment: "Message shown when the latest Wi-Fi scan failed"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                if let audioErrorMessage = viewModel.audioErrorMessage {
                    Label(audioErrorMessage, systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .frame(maxWidth: 480)
            .glassBackground(.regular, in: RoundedRectangle(cornerRadius: Self.cardRadius))
        }
        .frame(maxWidth: Self.contentMaxWidth)
        .padding(Self.pagePadding)
    }

    private var selectionSummary: String {
        let count = viewModel.selectionOptions.count
        return String(
            format: String(localized: "apRadar.summary.available", comment: "Summary of APs visible to the selector, e.g. 12 access points available"),
            count
        )
    }

    private var emptyScanState: some View {
        VStack(spacing: 8) {
            Text(String(localized: "apRadar.empty.title", comment: "Empty state when no access points were found"))
                .font(.headline)
            Text(String(localized: "apRadar.empty.description", comment: "Empty state guidance when no access points were found"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onRescan()
            } label: {
                Label(
                    String(localized: "apRadar.rescan", comment: "Button to rescan for access points"),
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(.bordered)
            .padding(.top, 2)
        }
        .frame(maxWidth: 400)
    }

    // MARK: - Tracking

    private func trackingContent(_ snapshot: APRadarSnapshot) -> some View {
        fittingContent(
            regular: { trackingLayout(snapshot, fit: .regular) },
            compact: { trackingLayout(snapshot, fit: .compact) }
        )
        .accessibilityElement(children: .contain)
    }

    private func trackingLayout(_ snapshot: APRadarSnapshot, fit: RadarFit) -> some View {
        VStack(spacing: fit.spacing) {
            targetCard(snapshot)

            VStack(spacing: fit.cardSpacing) {
                radarVisual(snapshot, fit: fit)

                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(rssiNumberText(snapshot.smoothedRSSI))
                            .font(.system(size: fit.rssiFontSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(String(localized: "ble.table.unit.dbm", comment: "dBm unit label"))
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(trendColor(snapshot.trend))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(trendText(snapshot.trend))
                            .font(.headline)
                            .foregroundStyle(trendColor(snapshot.trend))
                            .accessibilityHidden(true)
                    }

                    if let raw = snapshot.rawRSSI {
                        Text(rawSignalText(raw))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }

                strengthMeter(snapshot.smoothedRSSI)
            }
            .padding(16)
            .frame(maxWidth: 480)
            .glassBackground(.regular, in: RoundedRectangle(cornerRadius: Self.cardRadius))

            if let audioErrorMessage = viewModel.audioErrorMessage {
                Label(audioErrorMessage, systemImage: "speaker.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            controlsRow
        }
        .frame(maxWidth: Self.contentMaxWidth)
        .padding(Self.pagePadding)
    }

    /// Radar visual. At normal sizes it shrinks through a `ViewThatFits` chain
    /// as the column narrows; in compact mode it starts smaller so tight
    /// windows still avoid scrolling.
    @ViewBuilder
    private func radarVisual(_ snapshot: APRadarSnapshot, fit: RadarFit) -> some View {
        if fit.isCompact {
            ViewThatFits(in: .horizontal) {
                RadarPulseVisual(
                    smoothedRSSI: snapshot.smoothedRSSI,
                    pulseTick: viewModel.pulseTick,
                    soundEnabled: viewModel.soundEnabled,
                    reduceMotion: reduceMotion,
                    size: 130
                )
                RadarPulseVisual(
                    smoothedRSSI: snapshot.smoothedRSSI,
                    pulseTick: viewModel.pulseTick,
                    soundEnabled: viewModel.soundEnabled,
                    reduceMotion: reduceMotion,
                    size: 100
                )
            }
        } else {
            ViewThatFits(in: .horizontal) {
                RadarPulseVisual(
                    smoothedRSSI: snapshot.smoothedRSSI,
                    pulseTick: viewModel.pulseTick,
                    soundEnabled: viewModel.soundEnabled,
                    reduceMotion: reduceMotion,
                    size: 220
                )
                RadarPulseVisual(
                    smoothedRSSI: snapshot.smoothedRSSI,
                    pulseTick: viewModel.pulseTick,
                    soundEnabled: viewModel.soundEnabled,
                    reduceMotion: reduceMotion,
                    size: 170
                )
                RadarPulseVisual(
                    smoothedRSSI: snapshot.smoothedRSSI,
                    pulseTick: viewModel.pulseTick,
                    soundEnabled: viewModel.soundEnabled,
                    reduceMotion: reduceMotion,
                    size: 130
                )
            }
        }
    }

    private func targetCard(_ snapshot: APRadarSnapshot) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(snapshot.target.currentSSID ?? String(localized: "apRadar.target.hiddenNetwork", comment: "Label for an access point that hides its SSID"))
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    statusPill
                }
                Text(targetSubtitle(snapshot.target))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: 480)
        .glassBackground(.regular, in: RoundedRectangle(cornerRadius: Self.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trackingAccessibilityLabel(snapshot))
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text(String(localized: "apRadar.status.tracking", comment: "Status pill shown while AP Radar is tracking an access point"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .accessibilityHidden(true)
    }

    private func strengthMeter(_ smoothed: Double?) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(String(localized: "apRadar.signal.strength", comment: "Label above the signal strength meter"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(Color.accentColor.gradient)
                        .frame(width: max(6, geo.size.width * normalizedStrength(smoothed)))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
    }

    /// Action row that stays on one line when space allows and stacks
    /// full-width buttons when the window is narrow.
    @ViewBuilder
    private var controlsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                soundToggleButton
                changeTargetButton
                stopTrackingButton
            }
            VStack(spacing: 10) {
                soundToggleButton
                    .frame(maxWidth: .infinity)
                changeTargetButton
                    .frame(maxWidth: .infinity)
                stopTrackingButton
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 480)
        }
        .controlSize(.large)
        .padding(.top, 4)
    }

    private var soundToggleButton: some View {
        Button {
            viewModel.setSoundEnabled(!viewModel.soundEnabled)
        } label: {
            Label(
                viewModel.soundEnabled
                    ? String(localized: "apRadar.sound.on", comment: "Button label when sound is on")
                    : String(localized: "apRadar.sound.off", comment: "Button label when sound is off"),
                systemImage: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
            )
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("ap-radar-sound-toggle")
    }

    private var changeTargetButton: some View {
        Button {
            showSelection = true
        } label: {
            Label(
                String(localized: "apRadar.changeTarget", comment: "Button to pick a different access point"),
                systemImage: "arrow.triangle.2.circlepath"
            )
        }
        .buttonStyle(.bordered)
    }

    private var stopTrackingButton: some View {
        Button(role: .destructive) {
            viewModel.stopTracking()
        } label: {
            Label(
                String(localized: "apRadar.stopTracking", comment: "Button to stop tracking the current access point"),
                systemImage: "stop.fill"
            )
        }
        .buttonStyle(.bordered)
    }

    private func targetSubtitle(_ target: TrackedAccessPoint) -> String {
        let band = target.band?.displayName ?? ""
        let channel = target.channel.map {
            String(format: String(localized: "apRadar.target.channel", comment: "Access point channel, e.g. Channel 149"), $0)
        } ?? ""
        return [target.bssid, band, channel]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func trackingAccessibilityLabel(_ snapshot: APRadarSnapshot) -> String {
        let target = snapshot.target
        let ssid = target.currentSSID ?? String(localized: "apRadar.target.hiddenNetwork", comment: "Label for an access point that hides its SSID")
        let trend = trendText(snapshot.trend)
        let soundState = viewModel.soundEnabled
            ? String(localized: "apRadar.sound.state.on", comment: "VoiceOver text when sound is enabled")
            : String(localized: "apRadar.sound.state.off", comment: "VoiceOver text when sound is disabled")
        let signalStrength = snapshot.smoothedRSSI.map {
            String(
                format: String(localized: "apRadar.signal.dbm", comment: "Smoothed signal value with dBm unit for the VoiceOver summary"),
                Int($0.rounded())
            )
        } ?? "—"
        return String(
            format: String(localized: "apRadar.accessibility.tracking", comment: "VoiceOver summary of the tracked access point"),
            ssid,
            target.bssid,
            signalStrength,
            trend,
            soundState
        )
    }

    // MARK: - Signal lost

    private func signalLostContent(_ snapshot: APRadarLostSnapshot) -> some View {
        fittingContent(
            regular: { signalLostLayout(snapshot, fit: .regular) },
            compact: { signalLostLayout(snapshot, fit: .compact) }
        )
        .accessibilityElement(children: .contain)
    }

    private func signalLostLayout(_ snapshot: APRadarLostSnapshot, fit: RadarFit) -> some View {
        VStack(spacing: fit.spacing) {
            targetCard(snapshot: snapshot)

            VStack(spacing: fit.cardSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: fit.statusIconContainer, height: fit.statusIconContainer)
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: fit.statusIconSize, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .accessibilityHidden(true)
                .padding(.top, 6)

                VStack(spacing: 6) {
                    Text(String(localized: "apRadar.signalLost.title", comment: "Signal lost title"))
                        .font(.title3.weight(.semibold))
                    Text(String(localized: "apRadar.signalLost.description", comment: "Signal lost explanation"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 400)

                Text(String(
                    format: String(localized: "apRadar.signalLost.lastSeen", comment: "Time the access point was last seen"),
                    Self.lastSeenFormatter.string(from: snapshot.lastSeenAt)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "apRadar.signalLost.rescanning", comment: "Status shown while waiting for the next scan"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: 480)
            .glassBackground(.regular, in: RoundedRectangle(cornerRadius: Self.cardRadius))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(signalLostAccessibilityLabel(snapshot))

            HStack(spacing: 12) {
                changeTargetButton
                stopTrackingButton
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: Self.contentMaxWidth)
        .padding(Self.pagePadding)
    }

    private func targetCard(snapshot: APRadarLostSnapshot) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(snapshot.target.currentSSID ?? String(localized: "apRadar.target.hiddenNetwork", comment: "Label for an access point that hides its SSID"))
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(targetSubtitle(snapshot.target))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: 480)
        .glassBackground(.regular, in: RoundedRectangle(cornerRadius: Self.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(signalLostAccessibilityLabel(snapshot))
    }

    private func signalLostAccessibilityLabel(_ snapshot: APRadarLostSnapshot) -> String {
        let ssid = snapshot.target.currentSSID ?? String(localized: "apRadar.target.hiddenNetwork", comment: "Label for an access point that hides its SSID")
        return String(
            format: String(localized: "apRadar.accessibility.signalLost", comment: "VoiceOver summary for the signal lost state"),
            ssid,
            snapshot.target.bssid
        )
    }

    // MARK: - Shared bits

    private func rssiNumberText(_ smoothed: Double?) -> String {
        guard let smoothed else {
            return "—"
        }
        return "\(Int(smoothed.rounded()))"
    }

    private func rawSignalText(_ raw: Int) -> String {
        String(
            format: String(localized: "apRadar.signal.raw", comment: "Raw (un-smoothed) signal value with dBm unit"),
            raw
        )
    }

    private func trendText(_ trend: SignalTrend) -> String {
        switch trend {
        case .measuring:
            String(localized: "apRadar.trend.measuring", comment: "Trend while enough samples are being gathered")
        case .gettingCloser:
            String(localized: "apRadar.trend.gettingCloser", comment: "Trend when signal is getting stronger")
        case .stable:
            String(localized: "apRadar.trend.stable", comment: "Trend when signal is stable")
        case .movingAway:
            String(localized: "apRadar.trend.movingAway", comment: "Trend when signal is getting weaker")
        }
    }

    private func trendColor(_ trend: SignalTrend) -> Color {
        switch trend {
        case .measuring:
            .secondary
        case .gettingCloser:
            .green
        case .stable:
            .secondary
        case .movingAway:
            .orange
        }
    }

    /// Normalized 0...1 signal strength used only for visuals.
    private func normalizedStrength(_ smoothed: Double?) -> Double {
        guard let smoothed else { return 0 }
        return min(max((smoothed + 90) / 48, 0), 1)
    }

    private static let lastSeenFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Radar pulse visual

private struct RadarPulseVisual: View {
    let smoothedRSSI: Double?
    let pulseTick: Int
    let soundEnabled: Bool
    let reduceMotion: Bool
    /// Canvas side length. Smaller sizes are selected by `ViewThatFits` so the
    /// visual never overflows a narrow detail column.
    var size: CGFloat = 220

    @State private var rings: [Ring] = []
    @State private var liveSmoothedRSSI: Double?
    @State private var silentLoop: Task<Void, Never>?

    private struct Ring: Identifiable {
        let id = UUID()
    }

    /// Scales a design value defined at 220 pt to the current canvas size.
    private func s(_ value: CGFloat) -> CGFloat {
        value * size / 220
    }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
                    .frame(width: s(110 + CGFloat(index) * 45), height: s(110 + CGFloat(index) * 45))
            }

            ForEach(rings) { ring in
                PulseRingView(reduceMotion: reduceMotion, size: size)
                    .id(ring.id)
            }

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: s(64), height: s(64))
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: s(28), weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .opacity(centerOpacity)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: s(7))
            .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .onAppear {
            liveSmoothedRSSI = smoothedRSSI
            if !soundEnabled {
                startSilentLoop()
            }
        }
        .onDisappear {
            silentLoop?.cancel()
            silentLoop = nil
            rings.removeAll()
        }
        .onChange(of: pulseTick) { _, _ in
            guard soundEnabled else { return }
            spawnRing()
        }
        .onChange(of: soundEnabled) { _, enabled in
            if enabled {
                silentLoop?.cancel()
                silentLoop = nil
            } else {
                startSilentLoop()
            }
        }
        .onChange(of: smoothedRSSI) { _, newValue in
            liveSmoothedRSSI = newValue
        }
        .accessibilityHidden(true)
    }

    private var normalizedStrength: Double {
        guard let smoothedRSSI else { return 0 }
        return min(max((smoothedRSSI + 90) / 48, 0), 1)
    }

    private var centerOpacity: Double {
        0.45 + 0.55 * normalizedStrength
    }

    private func spawnRing() {
        let ring = Ring()
        rings.append(ring)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            rings.removeAll { $0.id == ring.id }
        }
    }

    /// Visual-only pulse cadence used while sound is muted. Drives the same
    /// ring visual from the same RSSI-to-interval mapping so muted users keep
    /// a non-audio feedback channel. Runs only while this view is visible and
    /// sound is off, and is cancelled when the view disappears.
    private func startSilentLoop() {
        guard silentLoop == nil, !soundEnabled else { return }
        silentLoop = Task {
            while !Task.isCancelled {
                spawnRing()
                // Mirror the audio scheduler: wait in small steps and pull the
                // next ring forward when a fresh sample shortens the interval,
                // so muted visuals react to a stronger signal promptly too.
                var deadline = ContinuousClock.now.advanced(
                    by: .seconds(APRadarPulseInterval.intervalSeconds(
                        forRSSI: liveSmoothedRSSI ?? -90
                    ))
                )
                while !Task.isCancelled {
                    let remaining = deadline - ContinuousClock.now
                    guard remaining > .zero else { break }
                    try? await Task.sleep(for: min(remaining, .milliseconds(100)))
                    let desired = ContinuousClock.now.advanced(
                        by: .seconds(APRadarPulseInterval.intervalSeconds(
                            forRSSI: liveSmoothedRSSI ?? -90
                        ))
                    )
                    if desired < deadline {
                        deadline = desired
                    }
                }
            }
        }
    }
}

private struct PulseRingView: View {
    let reduceMotion: Bool
    var size: CGFloat

    @State private var progress: Double = 0

    private func s(_ value: CGFloat) -> CGFloat {
        value * size / 220
    }

    var body: some View {
        Circle()
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: s(64), height: s(64))
            .scaleEffect(reduceMotion ? 1 : 0.25 + 1.9 * progress)
            .opacity(reduceMotion ? 0.6 * (1 - progress) : (1 - progress) * 0.9)
            .shadow(color: Color.accentColor.opacity(0.45), radius: s(4))
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.35 : 0.7)) {
                    progress = 1
                }
            }
    }
}
