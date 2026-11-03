import CMultitouch
import Foundation

struct Touch: Identifiable {
    let id: Int32
    let x: Float  // 0..1, left to right
    let y: Float  // 0..1, bottom to top
    let state: Int32
    let size: Float
}

/// Receives raw trackpad contacts from MultitouchSupport and handles them on the main thread.
final class TouchMonitor: ObservableObject {
    static let shared = TouchMonitor()

    @Published private(set) var touches: [Touch] = []
    @Published private(set) var deviceCount: Int32 = 0
    @Published private(set) var lastGesture = "none"

    private var leftEdgeSwipe = EdgeSwipeRecognizer()

    private init() {}

    func start() {
        deviceCount = mt_start { touches, count, _ in
            let frame = (0..<Int(count)).map { i -> Touch in
                let t = touches![i]
                return Touch(id: t.identifier, x: t.normalized.position.x, y: t.normalized.position.y,
                             state: t.state, size: t.size)
            }
            DispatchQueue.main.async { TouchMonitor.shared.handle(frame) }
        }
    }

    func stop() { mt_stop() }

    private func handle(_ frame: [Touch]) {
        touches = frame
        if leftEdgeSwipe.process(frame) {
            lastGesture = "Left-edge swipe"
            Actions.openApp(bundleID: Actions.leftEdgeSwipeApp)
        }
    }
}
