import SwiftUI

enum ProConstants {
    static let appStoreURL = "https://apps.apple.com/app/wifi-lens-pro/id6776590746"
}

struct ProFeaturePlaceholderView<CustomSkeleton: View>: View {
    let featureName: String
    let featureDescription: String
    let featureIcon: String
    @ViewBuilder var customSkeleton: () -> CustomSkeleton
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
                
                VStack(spacing: 18) {
                    customSkeleton()
                        .frame(height: 220)
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

extension ProFeaturePlaceholderView where CustomSkeleton == ProFeatureScreenshotPlaceholder {
    init(featureName: String, featureDescription: String, featureIcon: String) {
        self.featureName = featureName
        self.featureDescription = featureDescription
        self.featureIcon = featureIcon
        self.customSkeleton = { ProFeatureScreenshotPlaceholder(systemImage: featureIcon) }
    }
}

struct ProLockedSettingPreviewRow: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(title)
                    .font(.body)

                Spacer()

                Toggle("", isOn: .constant(false))
                    .labelsHidden()
                    .disabled(true)
                    .accessibilityHidden(true)
            }

            Text(description)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProFeatureScreenshotPlaceholder(systemImage: systemImage)
                .frame(height: 140)
                .padding(.top, 2)

            Button {
                if let url = URL(string: ProConstants.appStoreURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(String(localized: "pro.learn_more", comment: "Learn more button for Pro features"))
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
            .buttonStyle(.link)
            .font(.callout)
        }
        .padding(.vertical, 4)
    }
}

struct ProFeatureScreenshotPlaceholder: View {
    let systemImage: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 18, y: 8)

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Circle().fill(Color.red.opacity(0.75)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.75)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.75)).frame(width: 8, height: 8)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 72, height: 8)
                }

                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.blue.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.30))
                            .frame(width: 138, height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.14))
                            .frame(width: 192, height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 154, height: 8)
                    }

                    Spacer()
                }

                VStack(spacing: 8) {
                    previewLine(widthRatio: 0.92)
                    previewLine(widthRatio: 0.78)
                    previewLine(widthRatio: 0.86)
                }
            }
            .padding(18)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.14, blue: 0.16)
            : Color(red: 0.96, green: 0.97, blue: 0.98)
    }

    private func previewLine(widthRatio: CGFloat) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: geometry.size.width * widthRatio, height: 9)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 9)
    }
}

struct TimelineSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Track line
            Rectangle()
                .fill(Color.primary.opacity(0.16))
                .frame(width: 1)
                .padding(.top, 44)

            VStack(alignment: .leading, spacing: 0) {
                // Section 1 header
                sectionHeader

                // Section 1 rows
                timelineRow(titleWidth: 0.65, subtitleWidth: 0.48, markerOpacity: 0.20)
                timelineRow(titleWidth: 0.55, subtitleWidth: 0.40, markerOpacity: 0.15, showBadge: true)

                Spacer(minLength: 12)

                // Section 2 header
                sectionHeader

                // Section 2 rows
                timelineRow(titleWidth: 0.70, subtitleWidth: 0.52, markerOpacity: 0.12)
                timelineRow(titleWidth: 0.60, subtitleWidth: 0.44, markerOpacity: 0.20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 40, height: 8)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.bottom, 8)
    }

    private func timelineRow(
        titleWidth: CGFloat,
        subtitleWidth: CGFloat,
        markerOpacity: Double,
        showBadge: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Time column
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 78, height: 8)

            // Track marker
            Circle()
                .fill(Color.primary.opacity(markerOpacity))
                .frame(width: 12, height: 12)

            // Event card
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.30))
                                .frame(width: geo.size.width * titleWidth, height: 9)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 9)

                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.14))
                                .frame(width: geo.size.width * subtitleWidth, height: 7)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 7)
                }

                Spacer(minLength: 8)

                if showBadge {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 56, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.055))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.06 : 0.035), radius: 6, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.035), lineWidth: 1)
                    )
            )
        }
        .frame(minHeight: 46, alignment: .top)
        .padding(.bottom, 6)
    }
}
