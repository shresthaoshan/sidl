import SwiftUI

/// Draws the trackpad surface and each finger as a dot.
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

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10).stroke(.secondary)
                    ForEach(monitor.touches) { t in
                        Circle()
                            .fill(t.state == 4 ? Color.accentColor : .gray)
                            .frame(width: 24, height: 24)
                            .position(x: CGFloat(t.x) * geo.size.width,
                                      y: CGFloat(1 - t.y) * geo.size.height)
                    }
                }
            }
            .aspectRatio(1.6, contentMode: .fit)

            ForEach(monitor.touches) { t in
                Text(String(format: "#%d  x=%.2f  y=%.2f  state=%d  size=%.2f", t.id, t.x, t.y, t.state, t.size))
                    .font(.caption2.monospaced())
            }

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
