import SwiftUI

struct ImageComponent: View {
    let url: String?
    let style: JasonStyle?
    let documentURL: URL?

    var resolvedURL: URL? {
        url.flatMap { JasonURL.resolve($0, against: documentURL, allowedSchemes: DocumentLoader.allowedSchemes) }
    }

    var body: some View {
        if let url = resolvedURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(
                width: style?.width?.cgFloat,
                height: style?.height?.cgFloat
            )
            .clipped()
        }
    }
}
