import SwiftUI

struct ButtonComponent: View {
    let text: String?
    let url: String?
    let documentURL: URL?

    var resolvedURL: URL? {
        url.flatMap { JasonURL.resolve($0, against: documentURL) }
    }

    var body: some View {
        if let imageURL = resolvedURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    fallbackLabel
                default:
                    ProgressView()
                }
            }
        } else {
            fallbackLabel
        }
    }

    @ViewBuilder
    private var fallbackLabel: some View {
        Text(text ?? "Button")
    }
}
