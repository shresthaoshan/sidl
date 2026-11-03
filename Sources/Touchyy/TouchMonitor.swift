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
    private var leftEdgeSwipe = EdgeSwipeRecognizer()
    private var rightEdgeSlide = EdgeSlideRecognizer(zone: 0.9...1.0)

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

    private func handle(_ frame: [Touch]) {
        let swiped = leftEdgeSwipe.process(frame)
        let slide = rightEdgeSlide.process(frame)
        let claims = leftEdgeSwipe.claimsScroll || rightEdgeSlide.claimsScroll
        ScrollBlocker.shared.blocking.withLock { $0 = claims }

        DispatchQueue.main.async {
            self.touches = frame
            if swiped {
                self.lastGesture = "Left-edge swipe"
                Actions.openApp(bundleID: Actions.leftEdgeSwipeApp)
            }
            if slide != 0, let volume = Volume.change(by: slide) {
                self.lastGesture = "Volume \(Int((volume * 100).rounded()))%"
            }
        }
    }
}
