import SwiftUI

struct HelpCenterView: View {
    var body: some View {
        VStack {
            Spacer()
            Text(String(localized: "Help Center"))
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
