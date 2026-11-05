import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var launchAtLogin = LaunchAtLogin.shared
    @State private var selected = GestureSpot.leftEdgeSwipe

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

            Section("Sensitivity") {
                SensitivityRow(title: "Slide sensitivity", level: $store.mapping.slideSensitivity)
                SensitivityRow(title: "Swipe sensitivity", level: $store.mapping.swipeSensitivity)
            }

            Section {
                GestureMap(mapping: store.mapping, selected: $selected)
            } footer: {
                Text("Click a gesture to change its action.").foregroundStyle(.secondary)
            }

            Section(selected.title) {
                Group {
                    if let path = selected.discrete {
                        DiscreteActionRow(title: "Action", action: $store.mapping[dynamicMember: path])
                    } else if let path = selected.continuous {
                        ContinuousActionRow(title: "Action", action: $store.mapping[dynamicMember: path])
                    }
                }
                .id(selected)  // a new gesture gets a fresh row, so a running shortcut recorder stops
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear { launchAtLogin.refresh() }
    }
}

/// A gesture, and where it is on the trackpad drawing.
enum GestureSpot: CaseIterable, Identifiable {
    case topLeftCorner, topEdgeSwipe, topRightCorner, leftEdgeSwipe, leftEdgeSlide, rightEdgeSlide

    var id: Self { self }

    var title: String {
        switch self {
        case .topLeftCorner: "Top-left corner click (one finger)"
        case .topRightCorner: "Top-right corner click (one finger)"
        case .topEdgeSwipe: "Top-edge swipe down (two fingers)"
        case .leftEdgeSwipe: "Left-edge swipe right (two fingers)"
        case .leftEdgeSlide: "Left-edge slide (two fingers)"
        case .rightEdgeSlide: "Right-edge slide (two fingers)"
        }
    }

    var symbol: String {
        switch self {
        case .topLeftCorner, .topRightCorner: "cursorarrow.click"
        case .topEdgeSwipe: "arrow.down"
        case .leftEdgeSwipe: "arrow.right"
        case .leftEdgeSlide, .rightEdgeSlide: "arrow.up.and.down"
        }
    }

    /// Center of the mark, as a fraction of the drawing. The origin is the top-left corner.
    var point: CGPoint {
        switch self {
        case .topLeftCorner: CGPoint(x: 0.17, y: 0.14)
        case .topRightCorner: CGPoint(x: 0.83, y: 0.14)
        case .topEdgeSwipe: CGPoint(x: 0.5, y: 0.14)
        case .leftEdgeSwipe: CGPoint(x: 0.38, y: 0.45)
        case .leftEdgeSlide: CGPoint(x: 0.17, y: 0.72)
        case .rightEdgeSlide: CGPoint(x: 0.83, y: 0.72)
        }
    }

    var discrete: WritableKeyPath<Mapping, DiscreteAction>? {
        switch self {
        case .topLeftCorner: \.topLeftCorner
        case .topRightCorner: \.topRightCorner
        case .topEdgeSwipe: \.topEdgeSwipe
        case .leftEdgeSwipe: \.leftEdgeSwipe
        case .leftEdgeSlide, .rightEdgeSlide: nil
        }
    }

    var continuous: WritableKeyPath<Mapping, ContinuousAction>? {
        switch self {
        case .leftEdgeSlide: \.leftEdgeSlide
        case .rightEdgeSlide: \.rightEdgeSlide
        default: nil
        }
    }

    func actionTitle(in mapping: Mapping) -> String {
        if let discrete { return mapping[keyPath: discrete].title }
        return continuous.map { mapping[keyPath: $0].title } ?? ""
    }

    func isDisabled(in mapping: Mapping) -> Bool {
        if let discrete { return mapping[keyPath: discrete] == .disabled }
        return continuous.map { mapping[keyPath: $0] == .disabled } ?? true
    }
}

/// The trackpad, with the real gesture zones shaded and one mark for each gesture.
private struct GestureMap: View {
    let mapping: Mapping
    @Binding var selected: GestureSpot

    // The same sizes as GestureRouter and CornerClickDetector use.
    private static let edge: CGFloat = 0.1
    private static let corner: CGFloat = 0.12

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.5))
                    Path { p in
                        p.addRect(CGRect(x: 0, y: 0, width: w * Self.edge, height: h))
                        p.addRect(CGRect(x: w * (1 - Self.edge), y: 0, width: w * Self.edge, height: h))
                        p.addRect(CGRect(x: 0, y: 0, width: w, height: h * Self.edge))
                    }
                    .fill(.quaternary.opacity(0.6))
                    Path { p in
                        p.addRect(CGRect(x: 0, y: 0, width: w * Self.corner, height: h * Self.corner))
                        p.addRect(CGRect(x: w * (1 - Self.corner), y: 0, width: w * Self.corner, height: h * Self.corner))
                    }
                    .fill(.quaternary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                RoundedRectangle(cornerRadius: 12).stroke(.secondary)
                ForEach(GestureSpot.allCases) { spot in
                    mark(spot).position(x: spot.point.x * w, y: spot.point.y * h)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
    }

    private func mark(_ spot: GestureSpot) -> some View {
        let isSelected = spot == selected
        return Button { selected = spot } label: {
            HStack(spacing: 4) {
                // The icon faces the edge of its gesture.
                if spot.point.x <= 0.5 { Image(systemName: spot.symbol) }
                Text(spot.actionTitle(in: mapping)).lineLimit(1).truncationMode(.tail)
                if spot.point.x > 0.5 { Image(systemName: spot.symbol) }
            }
                .font(.caption.weight(.medium))
                .frame(maxWidth: 90)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .foregroundStyle(isSelected ? Color.white : spot.isDisabled(in: mapping) ? Color.secondary : Color.primary)
                .background(Capsule().fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color(nsColor: .separatorColor)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(spot.title)
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
