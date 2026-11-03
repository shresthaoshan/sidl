import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared

    var body: some View {
        Form {
            DiscreteActionRow(title: "Left-edge swipe right", action: $store.mapping.leftEdgeSwipe)
            DiscreteActionRow(title: "Top-edge swipe down", action: $store.mapping.topEdgeSwipe)
            ContinuousActionRow(title: "Left-edge slide", action: $store.mapping.leftEdgeSlide)
            ContinuousActionRow(title: "Right-edge slide", action: $store.mapping.rightEdgeSlide)

            Section("Sensitivity") {
                SensitivityRow(title: "Slide sensitivity", level: $store.mapping.slideSensitivity)
                SensitivityRow(title: "Swipe sensitivity", level: $store.mapping.swipeSensitivity)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}

private struct DiscreteActionRow: View {
    let title: String
    @Binding var action: DiscreteAction

    /// The Open app choice keeps the current app, or offers Finder until the user picks one.
    private var openAppChoice: DiscreteAction {
        if case .openApp = action { action } else { .openApp(bundleID: "com.apple.finder") }
    }

    var body: some View {
        Picker(title, selection: $action) {
            ForEach([.disabled, openAppChoice, .playPause, .nextTrack, .previousTrack], id: \.self) {
                Text($0.title).tag($0)
            }
        }
        if case .openApp = action {
            HStack {
                Spacer()
                Button("Choose App…", action: chooseApp)
            }
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        action = .openApp(bundleID: bundleID)
    }
}

private struct ContinuousActionRow: View {
    let title: String
    @Binding var action: ContinuousAction

    var body: some View {
        Picker(title, selection: $action) {
            ForEach(ContinuousAction.allCases) { Text($0.title).tag($0) }
        }
    }
}

private struct SensitivityRow: View {
    let title: String
    @Binding var level: Int

    var body: some View {
        Picker(title, selection: $level) {
            ForEach(Mapping.sensitivityLevels, id: \.self) {
                Text($0 == Mapping.defaultSensitivity ? "\($0) (default)" : "\($0)").tag($0)
            }
        }
    }
}

/// A plain AppKit window, so it opens only on request and never at launch.
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            window = makeWindow()
            window?.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = .preferredContentSize  // window follows the view, also when the Choose App row appears
        let w = NSWindow(contentViewController: hosting)
        w.title = "Touchyy Settings"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(hosting.view.fittingSize)  // size now, so center() places the full window
        return w
    }
}
