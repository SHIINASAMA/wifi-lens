import AppKit
import SwiftUI

struct SecondaryToolbarCapsule: NSViewRepresentable {
    let descriptor: SecondaryToolbarDescriptor
    @Binding var selection: SecondaryToolbarItemID

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, itemIDs: descriptor.items.map(\.id))
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: descriptor.items.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionDidChange(_:))
        )
        control.segmentStyle = .capsule
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }

        if #available(macOS 27.0, *) {
            control.role = .valueSelection
        }

        update(control, with: descriptor, selection: selection)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        nsView.target = context.coordinator
        nsView.action = #selector(Coordinator.selectionDidChange(_:))
        context.coordinator.itemIDs = descriptor.items.map(\.id)
        update(nsView, with: descriptor, selection: selection)
    }

    private func update(_ control: NSSegmentedControl, with descriptor: SecondaryToolbarDescriptor, selection: SecondaryToolbarItemID) {
        if control.segmentCount != descriptor.items.count {
            control.segmentCount = descriptor.items.count
        }

        for (index, item) in descriptor.items.enumerated() {
            control.setLabel(item.title, forSegment: index)
            control.setWidth(110, forSegment: index)
            control.setTag(index, forSegment: index)
        }

        let selectedIndex = descriptor.selectionIndex(for: selection)
        if control.selectedSegment != selectedIndex {
            control.selectedSegment = selectedIndex
        }
    }

    final class Coordinator: NSObject {
        @Binding private var selection: SecondaryToolbarItemID
        var itemIDs: [SecondaryToolbarItemID]

        init(selection: Binding<SecondaryToolbarItemID>, itemIDs: [SecondaryToolbarItemID] = []) {
            _selection = selection
            self.itemIDs = itemIDs
        }

        @objc func selectionDidChange(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard index >= 0 else { return }
            guard itemIDs.indices.contains(index) else { return }
            let itemID = itemIDs[index]
            if selection != itemID {
                selection = itemID
            }
        }
    }
}
