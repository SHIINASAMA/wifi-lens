import SwiftUI
import SceneKit

struct OverviewView: View {
    @Bindable var viewModel: ScannerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var stableScore = StableScore()
    @State private var displayLevel: ChannelQuality.QualityLevel = .excellent
    @State private var displayScore: Int = 100

    private var wifi: NetworkInterfaceInfo? {
        viewModel.networkInfo.first(where: { $0.ssid != nil })
    }

    private var currentChannelQuality: ChannelRecommendation? {
        guard wifi?.channel != nil else { return nil }
        return viewModel.channelRecommendations.first(where: { $0.isCurrentChannel })
    }

    private var recommendedChannels: [ChannelRecommendation] {
        viewModel.channelRecommendations.filter(\.isRecommended)
    }

    private var totalNetworks: Int {
        guard viewModel.isWiFiAvailable else { return 0 }
        return viewModel.bandViewModels.reduce(0) { $0 + $1.allSeriesData.count }
    }

    var body: some View {
        ZStack {
            // Subtle gradient behind hero — breaks the "all system materials" feel
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.10, green: 0.12, blue: 0.20), Color.clear]
                    : [Color(red: 0.94, green: 0.95, blue: 0.98), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 360)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 16) {
                        // State icon — rotating 3D Earth
                        let stateColor = wifi != nil ? rssiColor(wifi!.rssi ?? -100) : Color.secondary
                        EarthGlobeView(color: stateColor)
                            .frame(width: 240, height: 240)

                        if !viewModel.locationManager.isAuthorizedForSSID {
                            authorizationCard
                        }

                        if !viewModel.isWiFiAvailable {
                            wifiOffCard
                        } else if let wifi {
                            connectionCard(wifi)
                            signalHealthRow(wifi)
                            diagnosticCard(wifi)
                            if let current = currentChannelQuality, hasBetterChannel(current) {
                                channelAdviceCard(current)
                            }
                        } else {
                            noConnectionCard
                        }
                        if viewModel.locationManager.isAuthorizedForSSID && viewModel.isWiFiAvailable {
                            environmentCard
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(maxWidth: 640)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
            .onChange(of: currentChannelQuality?.rfScore) { _, newRaw in
            let raw = newRaw ?? 100
            displayScore = stableScore.update(score: raw)
            displayLevel = .from(score: displayScore)
        }
        } // ZStack
    }

    // MARK: - Connection Hero

    private func connectionCard(_ wifi: NetworkInterfaceInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wifi.displaySSID)
                        .font(.title3)
                        .fontWeight(.semibold)
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(String(localized: "common.label.connected", comment: "Connected state indicator"))
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
                label: String(localized: "overview.health.signal_label", comment: "Signal strength health indicator label"),
                value: signalLabel(wifi.rssi ?? -100),
                color: rssiColor(wifi.rssi ?? -100)
            )

            if currentChannelQuality != nil {
                healthPill(
                    icon: "chart.bar.fill",
                    label: String(localized: "overview.health.channel_label", comment: "Channel quality health indicator label"),
                    value: displayLevel.displayName,
                    color: Color(hex: displayLevel.color)
                )
            }

            healthPill(
                icon: "lock.shield.fill",
                label: String(localized: "overview.health.security_label", comment: "Security health indicator label"),
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
        .background(Color.primary.opacity(0.04))
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
        .background(Color.primary.opacity(0.04))
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
                title: String(localized: "overview.diagnosis.great.title", comment: "Diagnosis title: excellent connection"),
                message: String(localized: "overview.diagnosis.great.message", comment: "Diagnosis message: excellent connection"),
                color: .green
            )
        }

        if rssi < -75 {
            return Diagnosis(
                icon: "wifi.slash",
                title: String(localized: "overview.diagnosis.weak_signal.title", comment: "Diagnosis title: weak signal"),
                message: String(localized: "overview.diagnosis.weak_signal.message", comment: "Diagnosis message: weak signal advice"),
                color: .red
            )
        }

        if chScore < 50 {
            let channelNum = wifi.channel ?? 0
            let recList = recommendedChannels.prefix(2).map { "\($0.channel)" }.joined(separator: " / ")
            return Diagnosis(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "overview.diagnosis.congested.title", comment: "Diagnosis title: congested channel"),
                message: String(format: String(localized: "overview.diagnosis.congested.message_fmt", comment: "Congested channel diagnosis with channel number, AP count, and recommended channels"), channelNum, apCount, recList),
                color: .orange
            )
        }

        if chScore < 70 {
            return Diagnosis(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "overview.diagnosis.medium_channel.title", comment: "Diagnosis title: mediocre channel"),
                message: String(localized: "overview.diagnosis.medium_channel.message", comment: "Diagnosis message: channel improvement advice"),
                color: .orange
            )
        }

        if !sec.contains("WPA3") && sec != "—" && sec != String(localized: "common.label.none", comment: "Generic none/empty value label") {
            return Diagnosis(
                icon: "lock.open.fill",
                title: String(localized: "overview.diagnosis.security.title", comment: "Diagnosis title: weak security"),
                message: String(format: String(localized: "overview.diagnosis.security.message_fmt", comment: "Diagnosis message: security upgrade advice with current security type"), sec),
                color: .orange
            )
        }

        if phy == "n" || phy == "ac" {
            let version = phy == "n" ? "4" : "5"
            return Diagnosis(
                icon: "speedometer",
                title: String(localized: "overview.diagnosis.old_phy.title", comment: "Diagnosis title: older Wi-Fi generation"),
                message: String(format: String(localized: "overview.diagnosis.old_phy.message_fmt", comment: "Diagnosis message: Wi-Fi generation upgrade advice"), version),
                color: .orange
            )
        }

        return Diagnosis(
            icon: "checkmark.circle.fill",
            title: String(localized: "overview.diagnosis.ok.title", comment: "Diagnosis title: acceptable connection"),
            message: String(localized: "overview.diagnosis.ok.message", comment: "Diagnosis message: general improvement advice"),
            color: .mint
        )
    }

    // MARK: - Channel Advice

    private func channelAdviceCard(_ current: ChannelRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(String(localized: "overview.channel_advice.header", comment: "Header for recommended channels card"))
                    .font(.system(size: 12, weight: .semibold))
            }

            ForEach(recommendedChannels.prefix(2).filter { $0.channel != current.channel }) { ch in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: ch.rfLevel.color).opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text("\(ch.channel)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: ch.rfLevel.color))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("\(ch.bandDisplay) — \(ch.rfLevel.displayName)")
                                .font(.system(size: 12, weight: .medium))
                            if !ch.recommendationReasons.isEmpty {
                                ReasonPopover(reasons: ch.recommendationReasons)
                            }
                        }
                        Text(String(format: String(localized: "format.network_score_with_ap_count", comment: "Network score display with nearby AP count"), ch.rfScore, ch.apCount))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - No Connection

    private var noConnectionCard: some View {
        VStack(spacing: 12) {
            Text(String(localized: "overview.status.not_connected", comment: "Empty state when not connected to any Wi-Fi network"))
                .font(.title3)
                .fontWeight(.semibold)
            Text(String(localized: "overview.status.connect_prompt", comment: "Prompt to connect to Wi-Fi for diagnostics"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var wifiOffCard: some View {
        WiFiOffView()
            .padding(.horizontal, 0)
    }

    // MARK: - Authorization Card

    private var authorizationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.circle")
                .font(.title2)
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "permission.location.services_required_title", comment: "Alert title: Location Services permission needed"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(String(localized: "permission.location.macos_requires", comment: "Explanation of macOS LS requirement with privacy reassurance"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(String(localized: "common.action.authorize", comment: "Authorize/request permission button")) {
                viewModel.requestAuthorization()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Environment Summary

    private var environmentCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "overview.environment.summary_fmt", comment: "Banner showing count of detected networks"), totalNetworks))
                    .font(.system(size: 13, weight: .semibold))
                Text(bandSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bandSummary: String {
        viewModel.bandViewModels.map { vm in
            let count = vm.allSeriesData.count
            return "\(vm.band.displayName): \(count)"
        }.joined(separator: "  ·  ")
    }

    // MARK: - Helpers

    private func hasBetterChannel(_ current: ChannelRecommendation) -> Bool {
        recommendedChannels.contains(where: { $0.channel != current.channel && $0.rfScore > current.rfScore })
    }

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
        if rssi >= -55 { return String(localized: "overview.signal.strong", comment: "Strong signal level label") }
        if rssi >= -70 { return String(localized: "overview.signal.good", comment: "Good signal level label") }
        if rssi >= -85 { return String(localized: "channels.quality.moderate", comment: "Moderate channel quality tier") }
        return String(localized: "overview.signal.weak", comment: "Weak signal level label")
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
        if ch <= 14 { return String(localized: "wifi.band.24ghz", comment: "2.4 GHz Wi-Fi band name") }
        if ch <= 170 { return String(localized: "wifi.band.5ghz", comment: "5 GHz Wi-Fi band name") }
        return String(localized: "wifi.band.6ghz", comment: "6 GHz Wi-Fi band name")
    }

    private func securityShort(_ sec: String) -> String {
        if sec.contains("WPA3") { return "WPA3" }
        if sec.contains("WPA2") { return "WPA2" }
        if sec.contains("WPA") { return "WPA" }
        if sec == "—" || sec == String(localized: "common.label.none", comment: "Generic none/empty value label") { return String(localized: "wifi.security.open", comment: "Open/no password security type") }
        return sec
    }
}

// MARK: - 3D Earth Globe

private struct EarthGlobeView: NSViewRepresentable {
    let color: Color

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let scene = SCNScene()

        // Axial tilt container — Earth rotates at 23.5° from orbital plane
        let tiltNode = SCNNode()
        tiltNode.eulerAngles = SCNVector3(0.41, 0, 0)
        tiltNode.name = "tilt"
        scene.rootNode.addChildNode(tiltNode)

        // Earth sphere with mipmapped texture for anti-aliasing
        let earth = SCNSphere(radius: 1)
        earth.segmentCount = 96
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0.08, green: 0.12, blue: 0.35, alpha: 1)
        
        let image = NSImage(named: "Earth")
        material.diffuse.contents = image
        
        material.diffuse.mipFilter = .linear
        material.diffuse.maxAnisotropy = 4
        material.lightingModel = .constant
        earth.materials = [material]
        let earthNode = SCNNode(geometry: earth)
        earthNode.name = "earth"
        tiltNode.addChildNode(earthNode)

        // Pole caps — cover equirectangular projection artifacts
        let capGeom = SCNCylinder(radius: 0.04, height: 0.02)
        capGeom.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.10, blue: 0.28, alpha: 1)
        let northCap = SCNNode(geometry: capGeom)
        northCap.position = SCNVector3(0, 0.99, 0)
        earthNode.addChildNode(northCap)
        let southCap = SCNNode(geometry: capGeom)
        southCap.position = SCNVector3(0, -0.99, 0)
        earthNode.addChildNode(southCap)

        // Atmosphere glows — on tilt container so they tilt with Earth
        let innerGlow = SCNSphere(radius: 1.03)
        innerGlow.segmentCount = 64
        let innerGlowMat = SCNMaterial()
        innerGlowMat.diffuse.contents = NSColor.blue.withAlphaComponent(0.04)
        innerGlowMat.transparency = 0.15
        innerGlowMat.isDoubleSided = true
        innerGlow.materials = [innerGlowMat]
        let innerGlowNode = SCNNode(geometry: innerGlow)
        innerGlowNode.name = "innerGlow"
        tiltNode.addChildNode(innerGlowNode)

        let glow = SCNSphere(radius: 1.08)
        glow.segmentCount = 64
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor.blue.withAlphaComponent(0.06)
        glowMat.transparency = 0.2
        glowMat.isDoubleSided = true
        glow.materials = [glowMat]
        let glowNode = SCNNode(geometry: glow)
        glowNode.name = "glow"
        tiltNode.addChildNode(glowNode)

        // ---- Data-flow visualization on earthNode (rotates with Earth) ----

        let hubColor = NSColor.systemCyan.withAlphaComponent(0.9)
        let tubeColor = NSColor.systemCyan.withAlphaComponent(0.10)
        let arcRadius: CGFloat = 1.028
        let hubRadius: CGFloat = 1.025

        // lat/lon → unit 3D point
        func spherePoint(lat: CGFloat, lon: CGFloat) -> SCNVector3 {
            let latR = lat * .pi / 180; let lonR = lon * .pi / 180
            return SCNVector3(cos(latR) * cos(lonR), sin(latR), cos(latR) * sin(lonR))
        }

        // Hub cities
        let hubs: [(CGFloat, CGFloat)] = [
            (37.4, -122.1), (40.7, -74.0), (51.5, -0.1), (35.7, 139.8),
            (1.3, 103.8), (50.1, 8.7), (-33.9, 151.2), (-23.5, -46.6),
        ]
        let hubPairs: [(Int, Int)] = [(0,1),(1,2),(2,5),(3,4),(4,7),(5,3),(0,3),(6,4),(7,0),(2,3)]

        // Create hub dots + store unit positions for tubes
        var hubUnitPos: [SCNVector3] = []
        for (lat, lon) in hubs {
            let p = spherePoint(lat: lat, lon: lon)
            hubUnitPos.append(p)

            let dot = SCNSphere(radius: 0.014)
            dot.firstMaterial?.diffuse.contents = hubColor
            dot.firstMaterial?.emission.contents = hubColor
            let node = SCNNode(geometry: dot)
            node.position = SCNVector3(p.x * hubRadius, p.y * hubRadius, p.z * hubRadius)
            earthNode.addChildNode(node)

            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.3; pulse.toValue = 1.0; pulse.duration = 1.2
            pulse.autoreverses = true; pulse.repeatCount = .greatestFiniteMagnitude
            node.addAnimation(pulse, forKey: "pulse")
        }

        // Connection tubes between hub pairs
        for (a, b) in hubPairs {
            let fromU = hubUnitPos[a]; let toU = hubUnitPos[b]
            let fromP = SCNVector3(fromU.x * arcRadius, fromU.y * arcRadius, fromU.z * arcRadius)
            let toP   = SCNVector3(toU.x   * arcRadius, toU.y   * arcRadius, toU.z   * arcRadius)
            let midP  = SCNVector3((fromP.x+toP.x)/2, (fromP.y+toP.y)/2, (fromP.z+toP.z)/2)
            let dx = toP.x - fromP.x; let dy = toP.y - fromP.y; let dz = toP.z - fromP.z
            let chordLen = sqrt(dx*dx + dy*dy + dz*dz)

            let tube = SCNCylinder(radius: 0.0012, height: chordLen)
            tube.firstMaterial?.diffuse.contents = tubeColor
            let tubeNode = SCNNode(geometry: tube)
            tubeNode.position = midP
            tubeNode.look(at: toP, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
            earthNode.addChildNode(tubeNode)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.15; fade.toValue = 0.45; fade.duration = Double.random(in: 2...4)
            fade.autoreverses = true; fade.repeatCount = .greatestFiniteMagnitude
            tubeNode.addAnimation(fade, forKey: "flow")
        }

        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 40
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 3.5)
        scene.rootNode.addChildNode(cameraNode)

        // Rotation
        let rotate = CABasicAnimation(keyPath: "rotation")
        rotate.fromValue = SCNVector4(0, 1, 0, 0)
        rotate.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
        rotate.duration = 60
        rotate.repeatCount = .greatestFiniteMagnitude
        earthNode.addAnimation(rotate, forKey: "rotate")
        innerGlowNode.addAnimation(rotate, forKey: "rotate")
        glowNode.addAnimation(rotate, forKey: "rotate")

        context.coordinator.scene = scene

        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.isJitteringEnabled = true
        scnView.antialiasingMode = .multisampling8X
        scnView.preferredFramesPerSecond = 0

        scnView.scene = scene
        scnView.isPlaying = false
        DispatchQueue.main.async { scnView.isPlaying = true }
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard let tilt = nsView.scene?.rootNode.childNode(withName: "tilt", recursively: false) else { return }
        if let innerGlow = tilt.childNode(withName: "innerGlow", recursively: false) {
            innerGlow.geometry?.materials.first?.diffuse.contents = NSColor(color).withAlphaComponent(0.06)
        }
        if let glow = tilt.childNode(withName: "glow", recursively: false) {
            glow.geometry?.materials.first?.diffuse.contents = NSColor(color).withAlphaComponent(0.08)
        }
    }

    class Coordinator { var scene: SCNScene? }
}
