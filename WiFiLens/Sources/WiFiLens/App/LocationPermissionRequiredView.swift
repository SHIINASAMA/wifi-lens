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
                Text(String(localized: "Waiting for Location Services permission..."))
                    .foregroundColor(.orange)
                Button(String(localized: "Open System Settings")) {
                    openLocationPreferences()
                }
            case .denied:
                Text(String(localized: "Location Services required."))
                    .foregroundColor(.secondary)
                Button(String(localized: "Open Location Preferences")) {
                    openLocationPreferences()
                }
            default:
                Text(String(localized: "Location Services required."))
                    .foregroundColor(.secondary)
                Button(String(localized: "Open Location Preferences")) {
                    openLocationPreferences()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
