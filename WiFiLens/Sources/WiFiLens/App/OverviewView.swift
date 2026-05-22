import SwiftUI

struct OverviewView: View {
    @Bindable var viewModel: ScannerViewModel

    @State private var stableScore = StableScore()
    @State private var displayLevel: ChannelQuality.QualityLevel = .excellent
    @State private var displayScore: Int = 100

    private var wifi: NetworkInterfaceInfo? {
        viewModel.networkInfo.first(where: { $0.ssid != nil })
    }

    private var currentChannelQuality: ChannelQuality? {
        guard wifi?.channel != nil else { return nil }
        return viewModel.channelQualities.first(where: { $0.isCurrentChannel })
    }

    private var recommendedChannels: [ChannelQuality] {
        viewModel.channelQualities.filter(\.isRecommended)
    }

    private var totalNetworks: Int {
        viewModel.bandViewModels.reduce(0) { $0 + $1.renderedAllSeriesData.count }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let wifi {
                    connectionCard(wifi)
                    signalHealthRow(wifi)
                    diagnosticCard(wifi)
                    if let current = currentChannelQuality, displayScore < 70 {
                        channelAdviceCard(current)
                    }
                } else {
                    noConnectionCard
                }
                environmentCard
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: currentChannelQuality?.qualityScore) { _, newRaw in
            let raw = newRaw ?? 100
            displayScore = stableScore.update(score: raw)
            displayLevel = .from(score: displayScore)
        }
    }

    // MARK: - Connection Hero

    private func connectionCard(_ wifi: NetworkInterfaceInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.system(size: 28))
                    .foregroundColor(rssiColor(wifi.rssi ?? -100))

                VStack(alignment: .leading, spacing: 4) {
                    Text(wifi.displaySSID)
                        .font(.title3)
                        .fontWeight(.semibold)
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(String(localized: "Connected"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let ch = wifi.channel {
                            Text("·  \(bandName(ch))  ·  Ch \(ch)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(wifi.rssi ?? -100) dBm")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(rssiColor(wifi.rssi ?? -100))
                    signalBars(wifi.rssi ?? -100)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rssiColor(wifi.rssi ?? -100))
                        .frame(width: geo.size.width * rssiFraction(wifi.rssi ?? -100), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Signal Health Row

    private func signalHealthRow(_ wifi: NetworkInterfaceInfo) -> some View {
        HStack(spacing: 10) {
            healthPill(
                icon: "wave.3.right",
                label: String(localized: "Signal"),
                value: signalLabel(wifi.rssi ?? -100),
                color: rssiColor(wifi.rssi ?? -100)
            )

            if currentChannelQuality != nil {
                healthPill(
                    icon: "chart.bar.fill",
                    label: String(localized: "Channel"),
                    value: displayLevel.displayName,
                    color: Color(hex: displayLevel.color)
                )
            }

            healthPill(
                icon: "lock.shield.fill",
                label: String(localized: "Security"),
                value: securityShort(wifi.security),
                color: wifi.security.contains("WPA3") ? .green : .orange
            )
        }
    }

    private func healthPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Diagnostic Card

    private func diagnosticCard(_ wifi: NetworkInterfaceInfo) -> some View {
        let diag = diagnose(wifi)

        return HStack(spacing: 12) {
            Image(systemName: diag.icon)
                .font(.system(size: 28))
                .foregroundColor(diag.color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(diag.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(diag.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private struct Diagnosis {
        let icon: String
        let title: String
        let message: String
        let color: Color
    }

    private func diagnose(_ wifi: NetworkInterfaceInfo) -> Diagnosis {
        let rssi = wifi.rssi ?? -100
        let chScore = displayScore
        let apCount = currentChannelQuality?.apCount ?? 0
        let sec = wifi.security
        let phy = wifi.phyMode ?? ""

        if rssi >= -55 && chScore >= 70 && sec.contains("WPA3") {
            return Diagnosis(
                icon: "star.fill",
                title: String(localized: "Your connection looks great"),
                message: String(localized: "Strong signal, clean channel, and WPA3 security. You're getting the best experience."),
                color: .green
            )
        }

        if rssi < -75 {
            return Diagnosis(
                icon: "wifi.slash",
                title: String(localized: "Weak signal"),
                message: String(localized: "You're far from the router. Moving closer or adding a mesh node would help."),
                color: .red
            )
        }

        if chScore < 50 {
            let channelNum = wifi.channel ?? 0
            let recList = recommendedChannels.prefix(2).map { "\($0.channel)" }.joined(separator: " / ")
            return Diagnosis(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "Channel is congested"),
                message: String(localized: "Channel \(channelNum) has \(apCount) nearby networks. Try switching to \(recList)."),
                color: .orange
            )
        }

        if chScore < 70 {
            return Diagnosis(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "Channel could be better"),
                message: String(localized: "Your channel has some congestion. Switching could improve performance."),
                color: .orange
            )
        }

        if !sec.contains("WPA3") && sec != "—" && sec != String(localized: "None") {
            return Diagnosis(
                icon: "lock.open.fill",
                title: String(localized: "Security could be stronger"),
                message: String(localized: "Using \(sec). WPA3 is the latest standard. Check if your router supports it."),
                color: .orange
            )
        }

        if phy == "n" || phy == "ac" {
            let version = phy == "n" ? "4" : "5"
            return Diagnosis(
                icon: "speedometer",
                title: String(localized: "Older Wi‑Fi standard"),
                message: String(localized: "You're on Wi‑Fi \(version). Wi‑Fi 6 or 7 would give you faster speeds."),
                color: .orange
            )
        }

        return Diagnosis(
            icon: "checkmark.circle.fill",
            title: String(localized: "Connection is OK"),
            message: String(localized: "You could improve by moving closer to the router or switching channels."),
            color: .mint
        )
    }

    // MARK: - Channel Advice

    private func channelAdviceCard(_ current: ChannelQuality) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(String(localized: "Better Channels"))
                    .font(.system(size: 12, weight: .semibold))
            }

            ForEach(recommendedChannels.prefix(2).filter { $0.channel != current.channel }) { ch in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: ch.qualityLevel.color).opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text("\(ch.channel)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: ch.qualityLevel.color))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(ch.bandDisplay) — \(ch.qualityLevel.displayName)")
                            .font(.system(size: 12, weight: .medium))
                        Text(String(localized: "\(ch.qualityScore)/100 · \(ch.apCount) nearby"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - No Connection

    private var noConnectionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(String(localized: "Not connected to Wi‑Fi"))
                .font(.title3)
                .fontWeight(.semibold)
            Text(String(localized: "Connect to a Wi‑Fi network to see diagnostics and recommendations."))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Environment Summary

    private var environmentCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "\(totalNetworks) networks detected"))
                    .font(.system(size: 13, weight: .semibold))
                Text(bandSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bandSummary: String {
        viewModel.bandViewModels.map { vm in
            let count = vm.renderedAllSeriesData.count
            return "\(vm.band.displayName): \(count)"
        }.joined(separator: "  ·  ")
    }

    // MARK: - Helpers

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -55 { return .green }
        if rssi >= -70 { return .yellow }
        if rssi >= -85 { return .orange }
        return .red
    }

    private func rssiFraction(_ rssi: Int) -> CGFloat {
        max(0, min(1, CGFloat(rssi + 100) / 70))
    }

    private func signalLabel(_ rssi: Int) -> String {
        if rssi >= -55 { return String(localized: "Strong") }
        if rssi >= -70 { return String(localized: "Good") }
        if rssi >= -85 { return String(localized: "Moderate") }
        return String(localized: "Weak")
    }

    private func signalBars(_ rssi: Int) -> some View {
        let active = rssi >= -85 ? (rssi >= -70 ? (rssi >= -55 ? 3 : 2) : 1) : 0
        return HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < active ? rssiColor(rssi) : Color.secondary.opacity(0.15))
                    .frame(width: 4, height: CGFloat(6 + i * 4))
            }
        }
    }

    private func bandName(_ ch: Int) -> String {
        if ch <= 14 { return String(localized: "2.4 GHz") }
        if ch <= 170 { return String(localized: "5 GHz") }
        return String(localized: "6 GHz")
    }

    private func securityShort(_ sec: String) -> String {
        if sec.contains("WPA3") { return "WPA3" }
        if sec.contains("WPA2") { return "WPA2" }
        if sec.contains("WPA") { return "WPA" }
        if sec == "—" || sec == String(localized: "None") { return String(localized: "Open") }
        return sec
    }
}
