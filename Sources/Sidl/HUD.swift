import AppKit
import SwiftUI

/// On-screen level display for volume and brightness slides.
final class HUD: ObservableObject {
    static let shared = HUD()

    @Published private(set) var action = ContinuousAction.volume
    @Published private(set) var level: Float?  // nil: not supported on this display

    let fadeDelay: TimeInterval = 1.2
    private(set) lazy var panel = makePanel()
    private var generation = 0  // a fade only hides the panel if no newer show happened

    /// Shows the level, or "Not supported" for nil, and restarts the fade timer. Main thread only.
    func show(_ action: ContinuousAction, level: Float?) {
        self.action = action
        self.level = level
        place()
        // A zero-length animation also stops a fade that is running now.
        NSAnimationContext.runAnimationGroup { $0.duration = 0; panel.animator().alphaValue = 1 }
        panel.orderFrontRegardless()
        // After a long run (sleep, display changes), macOS can stop showing an old panel on
        // full-screen Spaces, even with .canJoinAllSpaces. A new panel joins the active Space.
        if !panel.isOnActiveSpace {
            NSLog("Sidl: HUD panel is not on the active Space, making a new one")
            panel.orderOut(nil)
            panel = makePanel()
            place()
            panel.orderFrontRegardless()
        }

        generation += 1
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) { [self] in
            guard generation == current else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 },
                                                 completionHandler: { [self] in
                if generation == current { panel.orderOut(nil) }
            })
        }
    }

    static func symbol(for action: ContinuousAction, level: Float?) -> String {
        guard let level else { return "exclamationmark.triangle.fill" }
        switch action {
        case .volume:
            if level <= 0 { return "speaker.slash.fill" }
            if level < 0.34 { return "speaker.wave.1.fill" }
            if level < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .disabled:
            return "questionmark"
        }
    }

    func makePanel() -> NSPanel {
        let hosting = NSHostingController(rootView: HUDView(hud: self))
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: hosting.view.fittingSize),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.contentViewController = hosting
        p.setContentSize(hosting.view.fittingSize)
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.ignoresMouseEvents = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        return p
    }

    /// Bottom center of the screen that has the pointer.
    private func place() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.minY + area.height / 8))
    }
}

private struct HUDView: View {
    @ObservedObject var hud: HUD

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: HUD.symbol(for: hud.action, level: hud.level))
                .font(.system(size: 18, weight: .medium))
                .frame(width: 26)
            if let level = hud.level {
                ProgressView(value: Double(level))
                    .progressViewStyle(.linear)
                    .frame(width: 140)
                Text("\(Int((level * 100).rounded()))%")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            } else {
                // Same width as the bar and the percent, so the panel keeps its size.
                Text("Not supported on this display")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 192, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
    }
}
