import SwiftUI

/// Shared popover that displays recommendation reasons in a compact list.
/// Placed as an overlay button on channel cards.
struct ReasonPopover: View {
    let reasons: [RecommendationReason]
    @State private var isHovering = false

    var body: some View {
        Button {
            // no-op — hover drives the popover
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
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isHovering, arrowEdge: .trailing) {
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
