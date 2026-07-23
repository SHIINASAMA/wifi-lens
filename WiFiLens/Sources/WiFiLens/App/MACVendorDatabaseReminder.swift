struct MACVendorDatabaseReminderPolicy {
    private(set) var hasPresentedThisSession = false

    mutating func shouldPresent(
        isSpectrum: Bool,
        isDatabaseEmpty: Bool,
        remindersEnabled: Bool
    ) -> Bool {
        guard !hasPresentedThisSession,
              isSpectrum,
              isDatabaseEmpty,
              remindersEnabled
        else { return false }

        hasPresentedThisSession = true
        return true
    }
}
