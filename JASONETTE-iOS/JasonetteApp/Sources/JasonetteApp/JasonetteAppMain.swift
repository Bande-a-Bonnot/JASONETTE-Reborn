import SwiftUI
import Jasonette

@main
struct JasonetteAppMain: App {
    var body: some Scene {
        WindowGroup {
            JasonetteNavigationView(
                url: URL(string: "https://jasonette.github.io/Jasonpedia/demo.json")!
            )
        }
    }
}
