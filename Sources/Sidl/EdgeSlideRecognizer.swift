/// Tracks a two-finger vertical slide along one edge of the trackpad.
struct EdgeSlideRecognizer {
    enum Phase { case idle, pending, sliding, rejected }

    var zone: ClosedRange<Float>  // x range where both fingers must land
    var activation: Float = 0.03  // travel that decides between vertical (slide) and horizontal (reject)

    private(set) var phase = Phase.idle
    private var startX: Float = 0
    private var startY: Float = 0
    private var lastY: Float = 0

    init(zone: ClosedRange<Float>) { self.zone = zone }

    /// True while the gesture owns the fingers, so scroll events must be blocked.
    var claimsScroll: Bool { phase == .pending || phase == .sliding }

    /// Feeds one frame of touches. Returns the vertical change for this frame (up is positive), or 0.
    mutating func process(_ touches: [Touch]) -> Float {
        let active = touches.filter { $0.state == 4 }
        if active.isEmpty { phase = .idle; return 0 }
        let x = active.map(\.x).reduce(0, +) / Float(active.count)
        let y = active.map(\.y).reduce(0, +) / Float(active.count)

        switch phase {
        case .idle:
            if active.count == 1 { return 0 }  // wait for the second finger
            if active.count == 2, active.allSatisfy({ zone.contains($0.x) }) {
                phase = .pending
                startX = x; startY = y
            } else {
                phase = .rejected
            }
            return 0

        case .pending:
            guard active.count == 2 else { phase = .rejected; return 0 }
            let dx = abs(x - startX), dy = abs(y - startY)
            if dy >= activation && dy > dx {
                phase = .sliding
                lastY = y
                return y - startY
            }
            if dx >= activation && dx > dy { phase = .rejected }
            return 0

        case .sliding:
            guard active.count == 2 else { phase = .rejected; return 0 }
            defer { lastY = y }
            return y - lastY

        case .rejected:
            return 0
        }
    }
}
