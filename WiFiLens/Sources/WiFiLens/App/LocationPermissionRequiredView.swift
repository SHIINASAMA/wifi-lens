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
                Text(String(localized: "permission.location.waiting", comment: "Status while waiting for Location Services authorization"))
                    .foregroundColor(.orange)
                Button(String(localized: "common.action.open_system_settings", comment: "Button to open macOS System Settings")) {
                    openLocationPreferences()
                }
            case .denied:
                Text(String(localized: "permission.location.required_short", comment: "Short label: Location Services required"))
                    .foregroundColor(.secondary)
                Button(String(localized: "common.action.open_location_preferences", comment: "Button to open Location Services preferences")) {
                    openLocationPreferences()
                }
            default:
                Text(String(localized: "permission.location.required_short", comment: "Short label: Location Services required"))
                    .foregroundColor(.secondary)
                Button(String(localized: "common.action.open_location_preferences", comment: "Button to open Location Services preferences")) {
                    openLocationPreferences()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
