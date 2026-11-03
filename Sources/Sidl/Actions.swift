import AppKit

enum Actions {
    static func perform(_ action: DiscreteAction) {
        switch action {
        case .disabled: break
        case .openApp(let bundleID): openApp(bundleID: bundleID)
        case .playPause: _ = sendMediaCommand?(2, nil)      // kMRTogglePlayPause
        case .nextTrack: _ = sendMediaCommand?(4, nil)      // kMRNextTrack
        case .previousTrack: _ = sendMediaCommand?(5, nil)  // kMRPreviousTrack
        // The system shortcut runs the macOS screenshot tool, so Sidl needs no Screen Recording permission.
        case .screenshot: post(.screenshotToolbar)
        case .keyboardShortcut(let combo): if let combo { post(combo) }
        }
    }

    /// Sends a key combination as if typed. Needs Accessibility permission.
    static func post(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: keyDown)
            event?.flags = CGEventFlags(rawValue: combo.modifiers)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Applies one slide step. Main thread only.
    static func adjust(_ action: ContinuousAction, by delta: Float) -> AdjustResult {
        switch action {
        case .disabled: .unsupported
        case .volume: Volume.change(by: delta).map(AdjustResult.level) ?? .unsupported
        case .brightness: Brightness.change(by: delta)
        }
    }

    static func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> Bool

    /// MediaRemote's command sender. Unlike a synthesized media key, it needs no Accessibility permission.
    static let sendMediaCommand = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        .flatMap { dlsym($0, "MRMediaRemoteSendCommand") }
        .map { unsafeBitCast($0, to: SendCommandFn.self) }
}
