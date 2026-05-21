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
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let isSelected = tab.id == selectedTabID
                Button {
                    onTap(tab)
                } label: {
                    FooterTabCell(
                        descriptor: tab.descriptor,
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FooterTabCell.accessibilityLabel(for: tab.descriptor, fallback: "Tab \(index + 1)"))
                .accessibilityValue(isSelected ? "Selected" : "")
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

    private var resolvedStyle: JasonStyle {
        descriptor.label.style ?? JasonStyle()
    }

    private var cellStyle: JasonStyle {
        resolvedStyle.withoutSize()
    }

    private var iconWidth: CGFloat {
        resolvedStyle.width?.cgFloat ?? resolvedStyle.height?.cgFloat ?? 24
    }

    private var iconHeight: CGFloat {
        resolvedStyle.height?.cgFloat ?? resolvedStyle.width?.cgFloat ?? 24
    }

    private var spacing: CGFloat {
        resolvedStyle.spacing?.cgFloat ?? 2
    }

    private var tint: Color {
        if let color = resolvedStyle.color.flatMap(Color.init(css:)) {
            return isSelected ? color : color.opacity(0.55)
        }
        return isSelected ? .accentColor : .secondary
    }

    var body: some View {
        VStack(spacing: spacing) {
            ZStack(alignment: .topTrailing) {
                icon
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
            selectedIndicator
        }
        .contentShape(Rectangle())
        // Footer-tab `width`/`height` size the icon, not the whole cell — this
        // mirrors the legacy typeless footer-tab renderer.
        .modifier(JasonStyleModifier(style: cellStyle, headStyles: [:], className: nil))
        .foregroundColor(tint)
    }

    static func accessibilityLabel(for descriptor: TabDescriptor, fallback: String) -> String {
        if let text = descriptor.label.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let systemName = descriptor.label.systemImageName, !systemName.isEmpty {
            return systemName.replacingOccurrences(of: ".", with: " ")
        }
        if let iconName = descriptor.label.iconURL?.deletingPathExtension().lastPathComponent, !iconName.isEmpty {
            return iconName.replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
        }
        return fallback
    }

    @ViewBuilder
    private var icon: some View {
        if let name = descriptor.label.systemImageName {
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: iconWidth, height: iconHeight)
        } else if let url = descriptor.label.iconURL {
            // Phase-based API so `.failure` shows a visible fallback instead
            // of silently leaving a tappable blank space. `Color.clear` stays
            // for `.empty` (still loading), avoiding a broken-icon flash for a
            // slow-but-successful fetch.
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
            .frame(width: iconWidth, height: iconHeight)
        }
    }

    @ViewBuilder
    private var selectedIndicator: some View {
        if isSelected {
            Capsule()
                .fill(tint)
                .frame(width: 18, height: 3)
                .padding(.top, 2)
        } else {
            Color.clear
                .frame(width: 18, height: 3)
                .padding(.top, 2)
        }
    }
}
