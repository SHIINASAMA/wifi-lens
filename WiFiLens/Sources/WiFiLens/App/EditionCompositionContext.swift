import SwiftUI

struct EditionCompositionContext {
    let scannerViewModel: ScannerViewModel
    let selectedPage: Binding<SidebarPage>
    let secondaryToolbarSelections: Binding<SecondaryToolbarSelections>
    let bleEnabled: Binding<Bool>
    let openMainWindow: (SidebarPage?) -> Void
}
