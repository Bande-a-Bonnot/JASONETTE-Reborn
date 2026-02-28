import SwiftUI

struct LabelComponent: View {
    let text: String

    var body: some View {
        Text(text)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}
