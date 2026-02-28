import SwiftUI

struct SpaceComponent: View {
    let height: CGFloat?

    var body: some View {
        Spacer()
            .frame(height: height ?? 10)
    }
}
