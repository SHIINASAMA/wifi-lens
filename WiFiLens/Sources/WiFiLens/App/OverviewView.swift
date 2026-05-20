import SwiftUI

struct OverviewView: View {
    var body: some View {
        VStack {
            Spacer()
            Text(String(localized: "Overview"))
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
