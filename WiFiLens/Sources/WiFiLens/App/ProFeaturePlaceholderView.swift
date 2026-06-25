import SwiftUI

enum ProConstants {
    static let appStoreURL = "https://apps.apple.com/app/wifi-lens-pro/id6776590746"
}

struct ProFeaturePlaceholderView: View {
    let featureName: String
    let featureDescription: String
    let featureIcon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.10, green: 0.12, blue: 0.20), Color.clear]
                        : [Color(red: 0.94, green: 0.95, blue: 0.98), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: featureIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.6)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .accessibilityHidden(true)
                    
                    VStack(spacing: 8) {
                        Text(featureName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(featureDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: 6) {
                        Text("PRO")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    
                    Button {
                        openAppStore()
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(localized: "pro.learn_more", comment: "Learn more button for Pro features"))
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(32)
                .frame(maxWidth: 480)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "pro.accessibility.feature_fmt", comment: "Pro feature accessibility label"), featureName))
    }
    
    private func openAppStore() {
        if let url = URL(string: ProConstants.appStoreURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
