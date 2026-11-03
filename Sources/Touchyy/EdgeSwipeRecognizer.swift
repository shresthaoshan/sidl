/// Detects a two-finger swipe that starts at one edge of the trackpad and moves inward.
struct EdgeSwipeRecognizer {
    enum Edge {
        case left  // land at the left edge, move right
        case top   // land at the top edge, move down
    }

    let edge: Edge
    var edgeZone: Float = 0.1   // fingers must land within this distance of the edge
    var minTravel: Float = 0.2  // each finger must move inward by at least this

    private var start: [Int32: Touch]?
    private var done = false    // gesture fired or was rejected; wait until all fingers lift

    init(edge: Edge) { self.edge = edge }

    /// True from the moment both fingers land at the edge until they lift, unless the gesture is cancelled.
    var claimsScroll: Bool { start != nil }

    /// Feeds one frame of touches. Returns true once, on the frame that completes the swipe.
    mutating func process(_ touches: [Touch]) -> Bool {
        let active = touches.filter { $0.state == 4 }
        if active.isEmpty { start = nil; done = false; return false }
        if done { return false }

        guard let start else {
            guard active.count == 2 else { return false }  // wait for the second finger
            if active.allSatisfy(atEdge) {
                self.start = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
            } else {
                done = true
            }
            return false
        }

        // Cancel if the finger set changes during the gesture.
        guard active.count == 2, active.allSatisfy({ start[$0.id] != nil }) else {
            self.start = nil
            done = true
            return false
        }

        if active.allSatisfy({ inwardTravel(from: start[$0.id]!, to: $0) >= minTravel }) {
            done = true
            return true
        }
        return false
    }

    private func atEdge(_ t: Touch) -> Bool {
        switch edge {
        case .left: t.x < edgeZone
        case .top: t.y > 1 - edgeZone
        }
    }

    private func inwardTravel(from a: Touch, to b: Touch) -> Float {
        switch edge {
        case .left: b.x - a.x
        case .top: a.y - b.y
        }
    }
}
