import SwiftUI

/// Shared popover that displays recommendation reasons in a compact list.
/// Placed as an overlay button on channel cards.
struct ReasonPopover: View {
    let reasons: [RecommendationReason]
    @State private var isHovering = false
    @State private var isTapped = false

    private var showPopover: Bool { isHovering || isTapped }

    var body: some View {
        Button {
            isTapped.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 20, height: 20)
                Text("?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "channels.reason.popover.title",
                                   comment: "Title for recommendation reason popover"))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
            if !hovering { isTapped = false }
        }
        .popover(isPresented: Binding<Bool>(
            get: { isHovering || isTapped },
            set: { newValue in if !newValue { isTapped = false; isHovering = false } }
        ), arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "channels.reason.popover.title",
                            comment: "Title for recommendation reason popover"))
                    .font(.system(size: 11, weight: .semibold))

                ForEach(reasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        Text(reason.displayText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(width: 260)
        }
    }
}
