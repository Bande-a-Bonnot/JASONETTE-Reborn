import SwiftUI
import Jasonette

@main
public struct JasonetteApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            JasonetteRootView(url: JasonetteLaunchConfiguration.entryURL())
        }
    }
}
