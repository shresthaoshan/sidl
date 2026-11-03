import SwiftUI

@main
struct TouchyyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
        TouchMonitor.shared.start()
        ScrollBlocker.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("Touchyy", systemImage: "hand.draw") {
            DebugView()
        }
        .menuBarExtraStyle(.window)
    }
}
