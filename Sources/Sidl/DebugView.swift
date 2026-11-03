import SwiftUI

/// The menu bar panel: status lines, the live trackpad drawing, and the app buttons.
struct DebugView: View {
    @ObservedObject var monitor = TouchMonitor.shared
    @ObservedObject var scrollBlocker = InputFilter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monitor.deviceCount < 0 ? "Failed to load MultitouchSupport"
                                         : "Devices: \(monitor.deviceCount)  Fingers: \(monitor.touches.count)")
                .font(.caption.monospaced())
            Text("Last gesture: \(monitor.lastGesture)")
                .font(.caption.monospaced())
            Text(scrollBlocker.isActive ? "Scroll blocking: on" : "Scroll blocking: off (grant Accessibility)")
                .font(.caption.monospaced())

            TrackpadView(touches: monitor.touches)

            Divider()
            HStack {
                Button("Settings…") { SettingsWindow.show() }
                Spacer()
                Button("Quit Sidl") { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 360)
    }
}
