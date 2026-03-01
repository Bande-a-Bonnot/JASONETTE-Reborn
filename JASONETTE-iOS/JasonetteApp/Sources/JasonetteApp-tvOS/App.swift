import SwiftUI
import Jasonette

@main
public struct JasonetteApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            JasonetteNavigationView(
                url: URL(string: "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json")!
            )
        }
    }
}
