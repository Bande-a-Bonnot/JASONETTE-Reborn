import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Jasonette

@main
public struct JasonetteApp: App {
    @State private var isShowingBuildInfo = false

    public init() {}

    public var body: some Scene {
        WindowGroup {
            JasonetteRootView(url: JasonetteLaunchConfiguration.entryURL())
                .sheet(isPresented: $isShowingBuildInfo) {
                    BuildInfoSheet(metadata: .current())
                }
                .onOpenURL { url in
                    if url.scheme == "jasonette-build" {
                        isShowingBuildInfo = true
                    }
                }
        }
    }
}

private struct BuildInfoSheet: View {
    let metadata: JasonetteBuildMetadata
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    labeledValue("Version", "\(metadata.version) (\(metadata.build))")
                    labeledValue("Commit", metadata.gitCommit)
                    labeledValue("Branch", metadata.gitBranch)
                }

                Section("Build") {
                    labeledValue("Xcode Cloud build", metadata.ciBuildNumber)
                    labeledValue("Workflow", metadata.ciWorkflow)
                    labeledValue("Generated", metadata.generatedAt)
                }

                Section {
                    Button(copied ? "Copied" : "Copy build info") {
                        copyToPasteboard(metadata.displayText)
                        copied = true
                    }
                }
            }
            .navigationTitle("Jasonette Build")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
