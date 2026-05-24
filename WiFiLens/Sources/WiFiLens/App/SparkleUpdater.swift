import Sparkle

private let autoCheckKey = "SUEnableAutomaticChecks"

@MainActor
final class SparkleUpdater: ObservableObject {
    let controller: SPUStandardUpdaterController
    private let updater: SPUUpdater

    init() {
        if UserDefaults.standard.object(forKey: autoCheckKey) == nil {
            UserDefaults.standard.set(false, forKey: autoCheckKey)
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = controller.updater
        updater.automaticallyChecksForUpdates = UserDefaults.standard.bool(forKey: autoCheckKey)
    }

    var automaticallyChecksForUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: autoCheckKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: autoCheckKey)
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
