import SwiftUI

struct ImageComponent: View {
    let url: String?
    let style: JasonStyle?
    let documentURL: URL?

    var resolvedURL: URL? {
        url.flatMap { JasonURL.resolve($0, against: documentURL, allowedSchemes: DocumentLoader.allowedSchemes) }
    }

    var usesAnimatedGIFRenderer: Bool {
        resolvedURL?.isGIFImageURL == true
    }

    var body: some View {
        if let url = resolvedURL {
            imageContent(for: url)
                .frame(
                    width: style?.width?.cgFloat,
                    height: style?.height?.cgFloat
                )
                .clipped()
        }
    }

    @ViewBuilder
    private func imageContent(for url: URL) -> some View {
        #if os(iOS)
        if url.isGIFImageURL {
            AnimatedGIFImage(url: url)
        } else {
            asyncImage(for: url)
        }
        #else
        asyncImage(for: url)
        #endif
    }

    @ViewBuilder
    private func asyncImage(for url: URL) -> some View {
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
    }
}
