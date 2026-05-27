import SwiftUI

struct HelpCenterView: View {
    var body: some View {
        VStack {
            Spacer()
            Text(String(localized: "nav.help_center", comment: "Help Center navigation item"))
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
