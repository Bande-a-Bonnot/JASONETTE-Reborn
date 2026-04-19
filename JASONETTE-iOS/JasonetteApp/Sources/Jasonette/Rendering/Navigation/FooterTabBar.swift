import SwiftUI

/// The persistent tab bar, rendered by `JasonetteTabShell` via
/// `safeAreaInset(edge: .bottom)`. Presentation-only — tap dispatch goes back
/// to the caller, never synthesizes hrefs.
@MainActor
struct FooterTabBar: View {
    let tabs: [TabEntry]
    let selectedTabID: TabID
    let onTap: (TabEntry) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    onTap(tab)
                } label: {
                    FooterTabCell(
                        descriptor: tab.descriptor,
                        isSelected: tab.id == selectedTabID
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(.background.shadow(.drop(radius: 1)))
    }
}

@MainActor
private struct FooterTabCell: View {
    let descriptor: TabDescriptor
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                if let url = descriptor.label.iconURL {
                    // Phase-based API so `.failure` shows a visible fallback
                    // instead of silently leaving a tappable blank space.
                    // `Color.clear` stays for `.empty` (still loading) so a
                    // slow-but-successful fetch doesn't flash a broken icon.
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                        case .empty:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                if let badge = descriptor.label.badge, !badge.isEmpty {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.red))
                        .offset(x: 6, y: -4)
                }
            }
            if let text = descriptor.label.text, !text.isEmpty {
                Text(text).font(.caption)
            }
        }
        .opacity(isSelected ? 1.0 : 0.55)
        .contentShape(Rectangle())
    }
}
