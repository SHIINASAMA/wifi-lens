import SwiftUI

/// What's New sheet displayed after a version update. Loads the appropriate
/// Markdown file based on the current locale and renders it via AttributedString.
struct WhatsNewSheetView: View {
    let coordinator: WhatsNewCoordinator
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    coordinator.markSeen()
                    dismiss()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "whatsnew.close", comment: "Close What's New sheet"))
                .keyboardShortcut(.cancelAction)
            }

            appIcon
                .padding(.top, 2)

            Text(coordinator.versionString)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 16)

            ScrollView {
                markdownContent
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }

            Button {
                coordinator.markSeen()
                dismiss()
                onDismiss()
            } label: {
                Text(String(localized: "whatsnew.done", comment: "Done button in What's New sheet"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("whatsnew-done")
            .padding(.top, 16)
        }
        .padding(22)
        .frame(width: 420, height: 480)
    }

    private var appIcon: some View {
        Group {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 76, height: 76)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 76, height: 76)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .accessibilityHidden(true)
    }

    private var markdownContent: some View {
        Group {
            if let attributed = loadMarkdown() {
                Text(attributed)
                    .font(.callout)
                    .textSelection(.enabled)
            } else {
                Text(String(localized: "whatsnew.unavailable", comment: "Fallback when release notes file is missing"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadMarkdown() -> AttributedString? {
        guard let url = Bundle.main.url(forReleaseNotesLanguage: Locale.current.language.languageCode?.identifier) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let markdown = String(data: data, encoding: .utf8) else {
            return nil
        }
        return try? AttributedString(markdown: markdown)
    }
}

private extension Bundle {
    /// Returns the URL for the release notes file matching the given language code,
    /// falling back to English if no match exists.
    func url(forReleaseNotesLanguage languageCode: String?) -> URL? {
        let languages: [String]
        if let code = languageCode {
            languages = [code, "en"]
        } else {
            languages = ["en"]
        }
        for lang in languages {
            if let url = url(forResource: lang, withExtension: "md", subdirectory: nil) {
                return url
            }
        }
        return nil
    }
}
