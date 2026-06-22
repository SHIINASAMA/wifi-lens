import Foundation
import Testing
@testable import WiFi_Lens

@Suite("Diagnostic Migration")
@MainActor
struct DiagnosticMigrationTests {
    @Test("OverviewView reads diagnosis from store")
    func readsFromStore() async {
        let store = WiFiObservationStore()
        let vm = ScannerViewModel(store: store)
        let overview = OverviewView(viewModel: vm, store: store)

        store.diagnosis = DiagnosticResult(
            icon: "wifi.slash",
            title: "Weak Signal",
            message: "Move closer",
            severity: .critical
        )

        #expect(overview.store.diagnosis?.icon == "wifi.slash")
        #expect(overview.store.diagnosis?.severity == .critical)
    }

    @Test("Store diagnosis is nil when not set")
    func diagnosisNilByDefault() {
        let store = WiFiObservationStore()
        #expect(store.diagnosis == nil)
    }

    @Test("DiagnosticSeverity maps to expected colors")
    func severityColors() {
        #expect(DiagnosticSeverity.excellent.color == .green)
        #expect(DiagnosticSeverity.warning.color == .orange)
        #expect(DiagnosticSeverity.critical.color == .red)
        #expect(DiagnosticSeverity.ok.color == .mint)
    }
}
