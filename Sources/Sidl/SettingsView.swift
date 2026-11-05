import AppKit
import CMultitouch
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    enum Tab: String, CaseIterable { case gestures = "Gestures", settings = "Settings" }

    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var launchAtLogin = LaunchAtLogin.shared
    @ObservedObject var inputFilter = InputFilter.shared
    @State var tab = Tab.gestures
    @State var selected = GestureSpot.leftEdgeSwipe
    var mapSize = TrackpadSize.onScreen(.main)

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, 12)

            switch tab {
            // Not a Form: a grouped Form limits rows to about 600 pt, less than a real-size drawing.
            case .gestures: gestures.padding(20)
            case .settings: Form { settings }.formStyle(.grouped)
            }
        }
        .frame(width: mapSize.width + 40)
        .onAppear { launchAtLogin.refresh() }
    }

    @ViewBuilder private var gestures: some View {
        VStack(spacing: 16) {
            GestureMap(mapping: store.mapping, selected: $selected).frame(width: mapSize.width, height: mapSize.height)
            HStack(alignment: .firstTextBaseline) {
                Text(selected.title).font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    if let path = selected.discrete {
                        DiscreteActionRow(title: selected.title, action: $store.mapping[dynamicMember: path])
                    } else if let path = selected.continuous {
                        ContinuousActionRow(title: selected.title, action: $store.mapping[dynamicMember: path])
                    }
                }
                .labelsHidden()
                .frame(width: 240)
                .id(selected)  // a new gesture gets a fresh row, so a running shortcut recorder stops
            }
        }
    }

    @ViewBuilder private var settings: some View {
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
            HStack {
                Label("Accessibility", systemImage: "accessibility")
                Spacer()
                if inputFilter.isActive {
                    StatusBadge(text: "Granted", color: .green)
                } else {
                    Button("Open Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Needed for scroll blocking, corner clicks, and the Screenshot and Keyboard shortcut actions.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

/// The trackpad drawing at the real size of the trackpad.
enum TrackpadSize {
    static let fallback = CGSize(width: 420, height: 262)

    /// The default trackpad at real size on `screen`, at most 80% of the screen width.
    static func onScreen(_ screen: NSScreen?) -> CGSize {
        var w: Int32 = 0, h: Int32 = 0
        guard mt_surface_size(&w, &h) == 0, let screen,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return fallback }
        let millimeters = CGDisplayScreenSize(id).width
        guard millimeters > 0 else { return fallback }
        return fit(surface: CGSize(width: CGFloat(w) / 100, height: CGFloat(h) / 100),
                   pointsPerMillimeter: screen.frame.width / millimeters, maxWidth: screen.frame.width * 0.8)
    }

    /// `surface` is in millimeters. Keeps the trackpad's proportions.
    static func fit(surface: CGSize, pointsPerMillimeter: CGFloat, maxWidth: CGFloat) -> CGSize {
        guard surface.width > 0, surface.height > 0, pointsPerMillimeter > 0 else { return fallback }
        let width = min(surface.width * pointsPerMillimeter, maxWidth)
        return CGSize(width: width.rounded(), height: (width * surface.height / surface.width).rounded())
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

    /// Short name, shown under the action on the drawing.
    var name: String {
        switch self {
        case .topLeftCorner: "Top-left corner"
        case .topRightCorner: "Top-right corner"
        case .topEdgeSwipe: "Top-edge swipe"
        case .leftEdgeSwipe: "Left-edge swipe"
        case .leftEdgeSlide: "Left-edge slide"
        case .rightEdgeSlide: "Right-edge slide"
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

    /// Where the mark is, as a fraction of the drawing. The origin is the top-left corner.
    /// A mark on the left starts at x, a mark on the right ends at x, and the top-edge mark is centered on x.
    var point: CGPoint {
        switch self {
        case .topLeftCorner: CGPoint(x: 0.04, y: 0.14)
        case .topRightCorner: CGPoint(x: 0.96, y: 0.14)
        case .topEdgeSwipe: CGPoint(x: 0.5, y: 0.14)
        case .leftEdgeSwipe: CGPoint(x: 0.04, y: 0.45)
        case .leftEdgeSlide: CGPoint(x: 0.04, y: 0.66)
        case .rightEdgeSlide: CGPoint(x: 0.96, y: 0.55)
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

/// The trackpad, with one mark for each gesture. The selected gesture's trigger zone is blue.
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
                RoundedRectangle(cornerRadius: 12).fill(Self.silver)
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0.53, green: 0.56, blue: 0.58))
                // The selected gesture's trigger zone, at the size the recognizers use.
                let zone = zone(w: w, h: h)
                Group {
                    Color.accentColor.opacity(0.25)
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3)
                }
                .mask(Rectangle().frame(width: zone.width, height: zone.height).position(x: zone.midX, y: zone.midY))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(spacing: 4) {
                    Image(systemName: "hand.point.up.left").font(.title3)
                    Text("Click a gesture to change it").font(.caption)
                }
                .foregroundStyle(Self.dim)
                .position(x: w / 2, y: h * 0.82)
                ForEach(GestureSpot.allCases) { spot in
                    mark(spot)
                        .frame(width: 150, alignment: spot.alignment)
                        .position(x: spot.point.x * w + spot.offset, y: spot.point.y * h)
                }
            }
        }
        .environment(\.colorScheme, .light)  // silver in dark mode too, like the real trackpad, so keep dark text
    }

    /// Brushed aluminum: light at the top, a little darker at the bottom.
    // Gray text is darker than .secondary, so it stays readable on silver.
    private static let dim = Color(white: 0.27)
    private static let silver = LinearGradient(colors: [Color(red: 0.70, green: 0.73, blue: 0.74),   // #B3BABD
                                                        Color(red: 0.64, green: 0.67, blue: 0.68)],  // #A2AAAD, Apple aluminum
                                               startPoint: .top, endPoint: .bottom)

    /// Where the selected gesture must start, in points.
    private func zone(w: CGFloat, h: CGFloat) -> CGRect {
        switch selected {
        case .leftEdgeSwipe, .leftEdgeSlide: CGRect(x: 0, y: 0, width: w * Self.edge, height: h)
        case .rightEdgeSlide: CGRect(x: w * (1 - Self.edge), y: 0, width: w * Self.edge, height: h)
        case .topEdgeSwipe: CGRect(x: 0, y: 0, width: w, height: h * Self.edge)
        case .topLeftCorner: CGRect(x: 0, y: 0, width: w * Self.corner, height: h * Self.corner)
        case .topRightCorner: CGRect(x: w * (1 - Self.corner), y: 0, width: w * Self.corner, height: h * Self.corner)
        }
    }

    private func mark(_ spot: GestureSpot) -> some View {
        let isSelected = spot == selected
        let disabled = spot.isDisabled(in: mapping)
        let icon = Image(systemName: spot.symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : disabled ? Self.dim : Color.accentColor)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7).fill(isSelected ? Color.accentColor : Color.white.opacity(disabled ? 0.2 : 0.55)))
        let trailing = spot.alignment == .trailing
        return Button { selected = spot } label: {
            HStack(spacing: 7) {
                // The icon faces the edge of its gesture.
                if !trailing { icon }
                VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
                    Text(spot.actionTitle(in: mapping))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(disabled ? Self.dim : Color.primary)
                    Text(spot.name).font(.caption2).foregroundStyle(Self.dim)
                }
                .lineLimit(1)
                .truncationMode(.tail)
                if trailing { icon }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 9).fill(isSelected ? Color.white.opacity(0.35) : Color.clear))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .help(spot.title)
    }
}

private extension GestureSpot {
    var alignment: Alignment {
        switch self {
        case .topEdgeSwipe: .center
        case .topRightCorner, .rightEdgeSlide: .trailing
        default: .leading
        }
    }

    /// Moves the 150 pt mark frame so that its leading or trailing edge is at `point.x`.
    var offset: CGFloat {
        switch alignment {
        case .leading: 75
        case .trailing: -75
        default: 0
        }
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
