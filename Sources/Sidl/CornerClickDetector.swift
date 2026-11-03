enum Corner { case topLeft, topRight }

/// Tracks which top corner a single finger touches, so a click can be matched to it.
/// With tap-to-click, macOS sends the click after the finger lifts, so the corner is kept for a short time.
struct CornerClickDetector {
    var zone: Float = 0.12            // corner size, as a fraction of width and height
    var memory: Double = 0.3          // seconds a corner is kept after the finger lifts

    private var lastCorner: Corner?
    private var liftTime: Double?     // nil while the finger still touches

    /// Feeds one frame. `time` is in seconds, from the same clock as `corner(at:)`.
    mutating func process(_ touches: [Touch], time: Double) {
        let touching = touches.filter { (3...4).contains($0.state) }  // make-touch or touching: a quick tap may skip 4
        switch touching.count {
        case 0:
            if lastCorner != nil && liftTime == nil { liftTime = time }
        case 1:
            lastCorner = corner(of: touching[0])
            liftTime = nil
        default:
            // Two or more fingers: a normal click or a gesture, never a corner click.
            lastCorner = nil
            liftTime = nil
        }
    }

    /// The corner that a click at `time` belongs to, or nil.
    func corner(at time: Double) -> Corner? {
        guard let lastCorner else { return nil }
        if let liftTime, time - liftTime > memory { return nil }
        return lastCorner
    }

    private func corner(of t: Touch) -> Corner? {
        guard t.y >= 1 - zone else { return nil }
        if t.x <= zone { return .topLeft }
        if t.x >= 1 - zone { return .topRight }
        return nil
    }
}

/// Decides which mouse events of a corner click to drop: the down, the drags, and the up.
struct ClickFilter {
    enum Event { case down, dragged, up }

    private(set) var swallowing = false

    /// Returns true if the event must be dropped. `cornerAction` is only read on `.down`.
    mutating func handle(_ event: Event, cornerAction: Bool) -> Bool {
        switch event {
        case .down:
            swallowing = cornerAction
            return swallowing
        case .dragged:
            return swallowing
        case .up:
            defer { swallowing = false }
            return swallowing
        }
    }
}
