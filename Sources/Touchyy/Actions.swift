import AppKit

enum Actions {
    /// Placeholder until the settings UI (MVP step 5).
    static let leftEdgeSwipeApp = "com.apple.Terminal"

    static func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
