import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var launchAtLogin = LaunchAtLogin.shared

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin.isEnabled },
                                                        set: { launchAtLogin.setEnabled($0) }))
                if launchAtLogin.status == .requiresApproval {
                    HStack {
                        Text("Approve Sidl in Login Items.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if let error = launchAtLogin.error {
                    Text(error).foregroundStyle(.red)
                }
                Toggle("Haptic feedback on swipes", isOn: $store.mapping.swipeHaptics)
            }

            DiscreteActionRow(title: "Left-edge swipe right", action: $store.mapping.leftEdgeSwipe)
            DiscreteActionRow(title: "Top-edge swipe down", action: $store.mapping.topEdgeSwipe)
            ContinuousActionRow(title: "Left-edge slide", action: $store.mapping.leftEdgeSlide)
            ContinuousActionRow(title: "Right-edge slide", action: $store.mapping.rightEdgeSlide)

            Section("Corner clicks (one finger)") {
                DiscreteActionRow(title: "Top-left corner", action: $store.mapping.topLeftCorner)
                DiscreteActionRow(title: "Top-right corner", action: $store.mapping.topRightCorner)
            }

            Section("Sensitivity") {
                SensitivityRow(title: "Slide sensitivity", level: $store.mapping.slideSensitivity)
                SensitivityRow(title: "Swipe sensitivity", level: $store.mapping.swipeSensitivity)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear { launchAtLogin.refresh() }
    }
}

private struct DiscreteActionRow: View {
    let title: String
    @Binding var action: DiscreteAction

    /// Shown as "Open app…" until the user picks an app. Choosing it opens the file panel.
    private static let unchosenApp = DiscreteAction.openApp(bundleID: "")

    /// The Open app choice keeps the current app, or offers "Open app…".
    private var openAppChoice: DiscreteAction {
        if case .openApp = action { action } else { Self.unchosenApp }
    }

    /// Choosing "Open app…" asks for the app first. If the user cancels, the previous action stays.
    private var selection: Binding<DiscreteAction> {
        Binding(get: { action }, set: { new in
            if new == Self.unchosenApp {
                DispatchQueue.main.async(execute: chooseApp)  // after the menu closes
            } else {
                action = new
            }
        })
    }

    /// The Keyboard shortcut choice keeps the recorded shortcut, or offers an empty one until the user records it.
    private var shortcutChoice: DiscreteAction {
        if case .keyboardShortcut = action { action } else { .keyboardShortcut(nil) }
    }

    var body: some View {
        Picker(title, selection: selection) {
            ForEach([.disabled, openAppChoice, .playPause, .nextTrack, .previousTrack, .screenshot, shortcutChoice],
                    id: \.self) {
                Text($0.title).tag($0)
            }
        }
        if case .openApp = action {
            HStack {
                Spacer()
                Button("Choose App…", action: chooseApp)
            }
        }
        if case .keyboardShortcut = action {
            ShortcutRecorder(action: $action)
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

/// Records the next key combination pressed while the Settings window is active.
private struct ShortcutRecorder: View {
    @Binding var action: DiscreteAction
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Spacer()
            Button(monitor == nil ? "Record Shortcut…" : "Press a shortcut (⎋ to cancel)") {
                monitor == nil ? start() : stop()
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                stop()  // plain Escape cancels
            } else if let combo = KeyCombo(keyCode: event.keyCode, flags: event.modifierFlags,
                                           characters: event.charactersIgnoringModifiers) {
                action = .keyboardShortcut(combo)
                stop()
            }
            return nil  // the keys are for the recorder, not for the window
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
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
        w.title = "Sidl Settings"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(hosting.view.fittingSize)  // size now, so center() places the full window
        return w
    }
}
