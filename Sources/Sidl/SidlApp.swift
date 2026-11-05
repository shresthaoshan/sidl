import SwiftUI

@main
struct SidlApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
        TouchMonitor.shared.start()
        InputFilter.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("Sidl", systemImage: "hand.draw") {
            Button("Settings…") { SettingsWindow.show() }.keyboardShortcut(",")
            Divider()
            Button("Quit Sidl") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
