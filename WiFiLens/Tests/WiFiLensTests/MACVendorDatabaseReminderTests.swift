import Testing
@testable import WiFi_Lens

struct MACVendorDatabaseReminderTests {
    @Test func promptsOncePerSessionOnSpectrumWhenEmptyAndEnabled() {
        let policy = MACVendorDatabaseReminderPolicy()

        #expect(policy.shouldPresent(isSpectrum: false, isDatabaseEmpty: true, remindersEnabled: true) == false)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: false, remindersEnabled: true) == false)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: true, remindersEnabled: false) == false)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: true, remindersEnabled: true) == true)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: true, remindersEnabled: true) == false)
    }

    @Test func sharedPolicySuppressesReminderAcrossWindowClients() {
        let processPolicy = MACVendorDatabaseReminderPolicy()

        #expect(processPolicy.shouldPresent(
            isSpectrum: true,
            isDatabaseEmpty: true,
            remindersEnabled: true
        ))
        #expect(!processPolicy.shouldPresent(
            isSpectrum: true,
            isDatabaseEmpty: true,
            remindersEnabled: true
        ))
    }

    @Test func unavailableDatabaseIsTreatedAsEmptyForRecoveryReminder() {
        #expect(MACVendorDatabaseAvailability.notInstalled.shouldRemindWhenEmpty)
        #expect(MACVendorDatabaseAvailability.unavailable(.persistenceFailure).shouldRemindWhenEmpty)
        #expect(!MACVendorDatabaseAvailability.loading.shouldRemindWhenEmpty)
        #expect(!MACVendorDatabaseAvailability.installed(
            MACVendorDatabaseSummary(
                source: .manualImport,
                createdAt: .distantPast,
                registryCounts: [:],
                totalRecordCount: 0
            )
        ).shouldRemindWhenEmpty)
    }
}
