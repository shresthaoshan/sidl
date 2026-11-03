import AppKit

enum Actions {
    /// Placeholder until the settings UI (MVP step 5).
    static let leftEdgeSwipeApp = "com.apple.Terminal"

    static func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> Bool

    /// MediaRemote's command sender. Unlike a synthesized media key, it needs no Accessibility permission.
    static let sendMediaCommand = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        .flatMap { dlsym($0, "MRMediaRemoteSendCommand") }
        .map { unsafeBitCast($0, to: SendCommandFn.self) }

    /// Toggles play/pause in the current Now Playing app (Music, Spotify, a browser).
    static func playPause() {
        _ = sendMediaCommand?(2, nil)  // kMRTogglePlayPause
    }
}
