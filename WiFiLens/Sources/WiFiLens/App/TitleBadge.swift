import SwiftUI

/// Title bar badge that reflects the current build configuration.
struct TitleBadge: View {
    let config: BuildConfig

    @State private var shimmerOffset: CGFloat = 0

    var body: some View {
        switch config {
        case .oss:
            ossBadge
        case .pro:
            proBadge
        }
    }

    // MARK: - OSS Badge

    private var ossBadge: some View {
        Button {
            // no action yet
        } label: {
            Text(String(localized: "WiFi Lens OSS"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 130/255, green: 89/255, blue: 221/255))
                .frame(height: 34)
                .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
        .background(Color(red: 245/255, green: 213/255, blue: 250/255), in: Capsule())
        .overlay {
            Capsule().stroke(Color(red: 130/255, green: 89/255, blue: 221/255), lineWidth: 1)
        }
    }

    // MARK: - PRO Badge

    private var proBadge: some View {
        let goldColor = Color(red: 218/255, green: 165/255, blue: 32/255)

        return Button {
            // no action yet
        } label: {
            Label {
                Text(String(localized: "WiFi Lens Pro"))
                    .font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
            }
            .foregroundColor(Color(red: 180/255, green: 130/255, blue: 30/255))
            .frame(height: 34)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
        .background(Color(red: 255/255, green: 245/255, blue: 220/255), in: Capsule())
        .overlay {
            Capsule().stroke(goldColor, lineWidth: 1.5)
        }
        .shadow(color: goldColor.opacity(0.3), radius: 6, y: 2)
        .overlay {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.4), .clear],
                        startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                    )
                )
                .mask(Capsule())
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}
