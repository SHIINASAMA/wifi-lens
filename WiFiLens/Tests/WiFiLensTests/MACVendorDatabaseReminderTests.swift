import Testing
@testable import WiFi_Lens

struct MACVendorDatabaseReminderTests {
    @Test func promptsOncePerSessionOnSpectrumWhenEmptyAndEnabled() {
        var policy = MACVendorDatabaseReminderPolicy()

        #expect(policy.shouldPresent(isSpectrum: false, isDatabaseEmpty: true, remindersEnabled: true) == false)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: false, remindersEnabled: true) == false)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: true, remindersEnabled: false) == false)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: true, remindersEnabled: true) == true)
        #expect(policy.shouldPresent(isSpectrum: true, isDatabaseEmpty: true, remindersEnabled: true) == false)
    }
}
