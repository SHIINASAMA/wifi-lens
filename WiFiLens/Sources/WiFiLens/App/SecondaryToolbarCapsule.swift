import AppKit
import SwiftUI

struct SecondaryToolbarCapsule: NSViewRepresentable {
    let descriptor: SecondaryToolbarDescriptor
    @Binding var selection: SecondaryToolbarItemID

    static func makeControl(
        descriptor: SecondaryToolbarDescriptor,
        selection: SecondaryToolbarItemID,
        target: AnyObject?,
        action: Selector?
    ) -> SecondaryToolbarSegmentedControl {
        let control = SecondaryToolbarSegmentedControl(
            labels: descriptor.items.map(\.title),
            trackingMode: .selectOne,
            target: target,
            action: action
        )
        control.segmentStyle = .capsule
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setAccessibilityIdentifier("secondary-toolbar")
        control.setAccessibilityLabel(descriptor.items.map(\.title).joined(separator: ", "))

        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }
        #if compiler(>=6.3)
        if #available(macOS 27.0, *) {
            control.role = .valueSelection
        }
        #endif

        update(control, with: descriptor, selection: selection)
        return control
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, itemIDs: descriptor.items.map(\.id))
    }

    func makeNSView(context: Context) -> SecondaryToolbarSegmentedControl {
        Self.makeControl(
            descriptor: descriptor,
            selection: selection,
            target: context.coordinator,
            action: #selector(Coordinator.selectionDidChange(_:))
        )
    }

    func updateNSView(_ nsView: SecondaryToolbarSegmentedControl, context: Context) {
        nsView.target = context.coordinator
        nsView.action = #selector(Coordinator.selectionDidChange(_:))
        context.coordinator.itemIDs = descriptor.items.map(\.id)
        Self.update(nsView, with: descriptor, selection: selection)
    }

    private static func update(_ control: SecondaryToolbarSegmentedControl, with descriptor: SecondaryToolbarDescriptor, selection: SecondaryToolbarItemID) {
        if control.segmentCount != descriptor.items.count {
            control.segmentCount = descriptor.items.count
        }

        for (index, item) in descriptor.items.enumerated() {
            control.setLabel(item.title, forSegment: index)
            control.setWidth(110, forSegment: index)
            control.setTag(index, forSegment: index)
        }

        control.segmentItemIDs = descriptor.items.map(\.id)
        let selectedIndex = descriptor.selectionIndex(for: selection)
        if control.selectedSegment != selectedIndex {
            control.selectedSegment = selectedIndex
        }
        control.refreshAccessibilityChildren()
    }

    @MainActor
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

final class SecondaryToolbarSegmentedControl: NSSegmentedControl {
    var segmentItemIDs: [SecondaryToolbarItemID] = []

    func refreshAccessibilityChildren() {
        var childElements: [Any] = []
        var xOffset: CGFloat = 0

        for index in 0..<segmentCount {
            let width = self.width(forSegment: index)
            let frame = NSRect(x: xOffset, y: 0, width: width, height: bounds.height)
            let label = self.label(forSegment: index) ?? ""
            let element = NSAccessibilityElement()
            element.setAccessibilityRole(.radioButton)
            element.setAccessibilityFrame(frame)
            element.setAccessibilityLabel(label)
            element.setAccessibilityParent(self)
            if segmentItemIDs.indices.contains(index) {
                element.setAccessibilityIdentifier("secondary-toolbar-\(segmentItemIDs[index].rawValue)")
            }
            childElements.append(element)
            xOffset += width
        }

        setAccessibilityChildren(childElements as [Any]?)
    }
}
