import Foundation

/// Resolves app-level launch configuration shared by concrete platform apps.
public enum JasonetteLaunchConfiguration {
    public static let productionEntryURL = URL(string: "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json")!

    #if DEBUG
    private static let defaultDebugOverridesEnabled = true
    #else
    private static let defaultDebugOverridesEnabled = false
    #endif

    /// Resolve the root document URL for the current process.
    ///
    /// Debug builds may override the production URL with either:
    /// - launch argument pair: `-JasonetteEntryURL https://example.com/app.json`
    /// - launch argument equals form: `-JasonetteEntryURL=https://example.com/app.json`
    /// - environment variable: `JASONETTE_ENTRY_URL=https://example.com/app.json`
    ///
    /// Release/TestFlight builds ignore overrides and always return
    /// `productionEntryURL` unless a caller provides a different `defaultURL`.
    public static func entryURL(
        processInfo: ProcessInfo = .processInfo,
        defaultURL: URL = productionEntryURL
    ) -> URL {
        entryURL(
            arguments: processInfo.arguments,
            environment: processInfo.environment,
            defaultURL: defaultURL,
            debugOverridesEnabled: defaultDebugOverridesEnabled
        )
    }

    static func entryURL(
        arguments: [String],
        environment: [String: String],
        defaultURL: URL = productionEntryURL,
        debugOverridesEnabled: Bool
    ) -> URL {
        guard debugOverridesEnabled else { return defaultURL }

        if let argumentOverride = launchArgumentOverride(in: arguments),
           let url = documentURL(from: argumentOverride) {
            return url
        }

        if let environmentOverride = environment["JASONETTE_ENTRY_URL"],
           let url = documentURL(from: environmentOverride) {
            return url
        }

        return defaultURL
    }

    private static func launchArgumentOverride(in arguments: [String]) -> String? {
        let argumentName = "-JasonetteEntryURL"

        for argument in arguments {
            if argument.hasPrefix("\(argumentName)=") {
                return String(argument.dropFirst(argumentName.count + 1))
            }
        }

        guard let index = arguments.firstIndex(of: argumentName) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }

    private static func documentURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              DocumentLoader.allowedSchemes.contains(scheme)
        else { return nil }
        return url
    }
}
