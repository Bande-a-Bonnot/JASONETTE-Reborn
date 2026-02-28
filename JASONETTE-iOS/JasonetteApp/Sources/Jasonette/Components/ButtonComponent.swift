import SwiftUI

struct ButtonComponent: View {
    let text: String?
    let url: String?

    var body: some View {
        if let urlStr = url, let imageURL = URL(string: urlStr) {
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
