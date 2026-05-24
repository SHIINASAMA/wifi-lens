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
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = controller.updater

        if UserDefaults.standard.bool(forKey: autoCheckKey) {
            try? updater.start()
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: autoCheckKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: autoCheckKey)
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        if !updater.canCheckForUpdates {
            do {
                try updater.start()
            } catch {
                AppLogger.sparkle.error("start failed: \(error.localizedDescription)")
                return
            }
        }
        AppLogger.sparkle.info("manual check triggered")
        controller.checkForUpdates(nil)
    }
}
