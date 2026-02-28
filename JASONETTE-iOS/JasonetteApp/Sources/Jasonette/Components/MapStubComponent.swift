import SwiftUI
import MapKit

struct MapStubComponent: View {
    var body: some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            Map()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    Text("Map")
                        .foregroundColor(.secondary)
                )
        }
    }
}
