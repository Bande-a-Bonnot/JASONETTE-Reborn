import SwiftUI

struct ButtonComponent: View {
    static let minimumHitSize: CGFloat = 44
    static let defaultHorizontalPadding: CGFloat = 14
    static let defaultVerticalPadding: CGFloat = 10

    let text: String?
    let url: String?
    let documentURL: URL?
    let style: JasonStyle?

    init(text: String?, url: String?, documentURL: URL?, style: JasonStyle? = nil) {
        self.text = text
        self.url = url
        self.documentURL = documentURL
        self.style = style
    }

    init(component: JasonComponent, documentURL: URL?, style: JasonStyle? = nil) {
        self.init(text: component.text, url: component.imageURL, documentURL: documentURL, style: style)
    }

    var resolvedURL: URL? {
        url.flatMap { JasonURL.resolve($0, against: documentURL, allowedSchemes: DocumentLoader.allowedSchemes) }
    }

    var horizontalLabelPadding: CGFloat {
        style?.width?.cgFloat == nil ? Self.defaultHorizontalPadding : 0
    }

    var minimumLabelWidth: CGFloat {
        max(Self.minimumHitSize, style?.width?.cgFloat ?? 0)
    }

    var body: some View {
        if let imageURL = resolvedURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: Self.minimumHitSize, minHeight: Self.minimumHitSize)
                        .contentShape(Rectangle())
                case .failure:
                    fallbackLabel
                default:
                    ProgressView()
                        .frame(minWidth: Self.minimumHitSize, minHeight: Self.minimumHitSize)
                }
            }
        } else {
            fallbackLabel
        }
    }

    @ViewBuilder
    private var fallbackLabel: some View {
        Text(text ?? "Button")
            .padding(.horizontal, horizontalLabelPadding)
            .padding(.vertical, Self.defaultVerticalPadding)
            .frame(minWidth: minimumLabelWidth, minHeight: Self.minimumHitSize)
            .contentShape(Rectangle())
    }
}
