/// Detects a two-finger swipe that starts at the left edge of the trackpad and moves right.
struct EdgeSwipeRecognizer {
    var edgeZone: Float = 0.1   // fingers must land with x below this
    var minTravel: Float = 0.2  // each finger must move right by at least this

    private var startX: [Int32: Float]?
    private var done = false    // gesture fired or was rejected; wait until all fingers lift

    /// Feeds one frame of touches. Returns true once, on the frame that completes the swipe.
    mutating func process(_ touches: [Touch]) -> Bool {
        let active = touches.filter { $0.state == 4 }
        if active.isEmpty { startX = nil; done = false; return false }
        if done { return false }

        guard let startX else {
            guard active.count == 2 else { return false }  // wait for the second finger
            if active.allSatisfy({ $0.x < edgeZone }) {
                self.startX = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0.x) })
            } else {
                done = true
            }
            return false
        }

        // Cancel if the finger set changes during the gesture.
        guard active.count == 2, active.allSatisfy({ startX[$0.id] != nil }) else { done = true; return false }

        if active.allSatisfy({ $0.x - startX[$0.id]! >= minTravel }) {
            done = true
            return true
        }
        return false
    }
}
