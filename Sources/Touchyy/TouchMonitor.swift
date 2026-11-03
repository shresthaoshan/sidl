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
    private var leftEdgeSwipe = EdgeSwipeRecognizer(edge: .left)
    private var topEdgeSwipe = EdgeSwipeRecognizer(edge: .top)
    private var leftEdgeSlide = EdgeSlideRecognizer(zone: 0...0.1)
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
        let brightnessDelta = leftEdgeSlide.process(frame)
        let volumeDelta = rightEdgeSlide.process(frame)
        // A slide owns the fingers once it starts, so a swipe on the same edge or corner does not also fire.
        let sliding = leftEdgeSlide.phase == .sliding || rightEdgeSlide.phase == .sliding
        let swipedLeft = leftEdgeSwipe.process(frame) && !sliding
        let swipedTop = topEdgeSwipe.process(frame) && !sliding

        let claims = leftEdgeSwipe.claimsScroll || topEdgeSwipe.claimsScroll
            || leftEdgeSlide.claimsScroll || rightEdgeSlide.claimsScroll
        ScrollBlocker.shared.blocking.withLock { $0 = claims }

        DispatchQueue.main.async {
            self.touches = frame
            if swipedLeft {
                self.lastGesture = "Left-edge swipe"
                Actions.openApp(bundleID: Actions.leftEdgeSwipeApp)
            }
            if swipedTop {
                self.lastGesture = "Play/Pause"
                Actions.playPause()
            }
            if brightnessDelta != 0, let brightness = Brightness.change(by: brightnessDelta) {
                self.lastGesture = "Brightness \(Int((brightness * 100).rounded()))%"
            }
            if volumeDelta != 0, let volume = Volume.change(by: volumeDelta) {
                self.lastGesture = "Volume \(Int((volume * 100).rounded()))%"
            }
        }
    }
}
