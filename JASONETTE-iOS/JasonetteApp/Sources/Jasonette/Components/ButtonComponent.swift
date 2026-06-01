import SwiftUI

struct ButtonComponent: View {
    static let minimumHitSize: CGFloat = 44
    static let defaultHorizontalPadding: CGFloat = 14
    static let defaultVerticalPadding: CGFloat = 10

    let text: String?
    let url: String?
    let documentURL: URL?

    init(text: String?, url: String?, documentURL: URL?) {
        self.text = text
        self.url = url
        self.documentURL = documentURL
    }

    init(component: JasonComponent, documentURL: URL?) {
        self.init(text: component.text, url: component.imageURL, documentURL: documentURL)
    }

    var resolvedURL: URL? {
        url.flatMap { JasonURL.resolve($0, against: documentURL, allowedSchemes: DocumentLoader.allowedSchemes) }
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
            .padding(.horizontal, Self.defaultHorizontalPadding)
            .padding(.vertical, Self.defaultVerticalPadding)
            .frame(minWidth: Self.minimumHitSize, minHeight: Self.minimumHitSize)
            .contentShape(Rectangle())
    }
}
