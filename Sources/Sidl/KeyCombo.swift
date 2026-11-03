import AppKit

/// A recorded keyboard shortcut, saved with the text to show for it.
struct KeyCombo: Codable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt64  // CGEventFlags raw value
    var display: String

    /// ⌘⇧5: the macOS screenshot toolbar.
    static let screenshotToolbar = KeyCombo(keyCode: 23, modifiers: CGEventFlags([.maskCommand, .maskShift]).rawValue,
                                            display: "⇧⌘5")

    init(keyCode: UInt16, modifiers: UInt64, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }

    /// Builds a shortcut from a key press. Returns nil without ⌃, ⌥, or ⌘, so a plain key cannot be recorded.
    init?(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) {
        let flags = flags.intersection([.control, .option, .shift, .command])
        guard !flags.intersection([.control, .option, .command]).isEmpty else { return nil }

        var cg = CGEventFlags()
        var symbols = ""
        // Apple's order for modifier symbols: ⌃⌥⇧⌘.
        if flags.contains(.control) { cg.insert(.maskControl); symbols += "⌃" }
        if flags.contains(.option) { cg.insert(.maskAlternate); symbols += "⌥" }
        if flags.contains(.shift) { cg.insert(.maskShift); symbols += "⇧" }
        if flags.contains(.command) { cg.insert(.maskCommand); symbols += "⌘" }

        self.init(keyCode: keyCode, modifiers: cg.rawValue,
                  display: symbols + (Self.keyNames[keyCode] ?? characters?.uppercased() ?? "?"))
    }

    private static let keyNames: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
