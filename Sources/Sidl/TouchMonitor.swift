import CMultitouch
import Foundation

struct Touch: Identifiable {
    let id: Int32
    let x: Float  // 0..1, left to right
    let y: Float  // 0..1, bottom to top
    let state: Int32
    let size: Float
}

/// Receives raw trackpad contacts from MultitouchSupport.
/// Gestures are recognized on the touch thread, so scroll blocking takes effect without a main-thread delay.
final class TouchMonitor: ObservableObject {
    static let shared = TouchMonitor()

    @Published private(set) var touches: [Touch] = []
    @Published private(set) var deviceCount: Int32 = 0
    @Published private(set) var lastGesture = "none"

    // Touch thread only.
    private var router = GestureRouter()
    private var corners = CornerClickDetector()

    private init() {}

    func start() {
        deviceCount = mt_start { touches, count, _ in
            let frame = (0..<Int(count)).map { i -> Touch in
                let t = touches![i]
                return Touch(id: t.identifier, x: t.normalized.position.x, y: t.normalized.position.y,
                             state: t.state, size: t.size)
            }
            TouchMonitor.shared.handle(frame)
        }
    }

    func stop() { mt_stop() }

    /// Shows an action in the panel's "Last gesture" line. Main thread only.
    func report(_ title: String) { lastGesture = title }

    private func handle(_ frame: [Touch]) {
        let out = router.process(frame, mapping: SettingsStore.shared.snapshot.withLock { $0 })
        InputFilter.shared.blocking.withLock { $0 = out.claimsScroll }
        corners.process(frame, time: ProcessInfo.processInfo.systemUptime)
        InputFilter.shared.corners.withLock { [corners] in $0 = corners }

        DispatchQueue.main.async {
            self.touches = frame
            for action in out.discrete {
                self.lastGesture = action.title
                Actions.perform(action)
            }
            for (action, delta) in out.continuous {
                if let level = Actions.adjust(action, by: delta) {
                    self.lastGesture = "\(action.title) \(Int((level * 100).rounded()))%"
                    HUD.shared.show(action, level: level)
                }
            }
        }
    }
}
