/// Runs every recognizer on each frame and maps the results to actions.
/// Gestures set to None neither act nor block scroll.
struct GestureRouter {
    struct Output {
        var claimsScroll = false
        var discrete: [DiscreteAction] = []
        var continuous: [(action: ContinuousAction, delta: Float)] = []
    }

    private var leftEdgeSwipe = EdgeSwipeRecognizer(edge: .left)
    private var topEdgeSwipe = EdgeSwipeRecognizer(edge: .top)
    private var leftEdgeSlide = EdgeSlideRecognizer(zone: 0...0.1)
    private var rightEdgeSlide = EdgeSlideRecognizer(zone: 0.9...1.0)

    mutating func process(_ frame: [Touch], mapping m: Mapping) -> Output {
        leftEdgeSwipe.minTravel = m.swipeTravel
        topEdgeSwipe.minTravel = m.swipeTravel

        // Recognizers always run, so their state stays correct when the mapping changes mid-gesture.
        let leftDelta = leftEdgeSlide.process(frame) * m.slideMultiplier
        let rightDelta = rightEdgeSlide.process(frame) * m.slideMultiplier
        let swipedLeft = leftEdgeSwipe.process(frame)
        let swipedTop = topEdgeSwipe.process(frame)

        let leftSwipeOn = m.leftEdgeSwipe != .disabled
        let topSwipeOn = m.topEdgeSwipe != .disabled
        let leftSlideOn = m.leftEdgeSlide != .disabled
        let rightSlideOn = m.rightEdgeSlide != .disabled

        // A started slide owns the fingers, so a swipe on the same edge or corner does not also fire.
        let sliding = (leftSlideOn && leftEdgeSlide.phase == .sliding)
            || (rightSlideOn && rightEdgeSlide.phase == .sliding)

        var out = Output()
        out.claimsScroll = (leftSwipeOn && leftEdgeSwipe.claimsScroll) || (topSwipeOn && topEdgeSwipe.claimsScroll)
            || (leftSlideOn && leftEdgeSlide.claimsScroll) || (rightSlideOn && rightEdgeSlide.claimsScroll)
        if swipedLeft && leftSwipeOn && !sliding { out.discrete.append(m.leftEdgeSwipe) }
        if swipedTop && topSwipeOn && !sliding { out.discrete.append(m.topEdgeSwipe) }
        if leftDelta != 0 && leftSlideOn { out.continuous.append((m.leftEdgeSlide, leftDelta)) }
        if rightDelta != 0 && rightSlideOn { out.continuous.append((m.rightEdgeSlide, rightDelta)) }
        return out
    }
}
