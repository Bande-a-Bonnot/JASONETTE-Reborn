import SwiftUI

struct ImageComponent: View {
    let url: String?
    let style: JasonStyle?

    var body: some View {
        if let urlStr = url, let url = URL(string: urlStr) {
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
