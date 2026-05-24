import SwiftUI

struct LocationPermissionRequiredView: View {
    let accessState: ScanAccessState
    let openLocationPreferences: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            switch accessState {
            case .waitingForAuthorization:
                Text("Waiting for Location Services permission...")
                    .foregroundColor(.orange)
                Button("Open System Settings") {
                    openLocationPreferences()
                }
            case .denied:
                Text("Location Services required.")
                    .foregroundColor(.secondary)
                Button("Open Location Preferences") {
                    openLocationPreferences()
                }
            default:
                Text("Location Services required.")
                    .foregroundColor(.secondary)
                Button("Open Location Preferences") {
                    openLocationPreferences()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
