import XCTest
@testable import Sidl

final class EdgeSwipeRecognizerTests: XCTestCase {
    private func finger(_ id: Int32, _ x: Float, state: Int32 = 4) -> Touch {
        Touch(id: id, x: x, y: 0.5, state: state, size: 1)
    }

    /// Feeds the frames in order and returns how many times the swipe fired.
    private func fires(_ frames: [[Touch]], _ r: inout EdgeSwipeRecognizer) -> Int {
        frames.filter { r.process($0) }.count
    }

    func testTwoFingerSwipeFromLeftEdgeFiresOnce() {
        var r = EdgeSwipeRecognizer(edge: .left)
        let frames = [[finger(1, 0.02), finger(2, 0.03)],
                      [finger(1, 0.15), finger(2, 0.16)],
                      [finger(1, 0.30), finger(2, 0.31)],
                      [finger(1, 0.50), finger(2, 0.51)]]
        XCTAssertEqual(fires(frames, &r), 1)
    }

    func testFingersLandingOneFrameApartStillFire() {
        var r = EdgeSwipeRecognizer(edge: .left)
        let frames = [[finger(1, 0.02)],
                      [finger(1, 0.03), finger(2, 0.04)],
                      [finger(1, 0.30), finger(2, 0.31)]]
        XCTAssertEqual(fires(frames, &r), 1)
    }

    func testSwipeStartingAwayFromEdgeDoesNotFire() {
        var r = EdgeSwipeRecognizer(edge: .left)
        let frames = [[finger(1, 0.40), finger(2, 0.42)],
                      [finger(1, 0.80), finger(2, 0.82)]]
        XCTAssertEqual(fires(frames, &r), 0)
    }

    func testOneFingerSwipeDoesNotFire() {
        var r = EdgeSwipeRecognizer(edge: .left)
        XCTAssertEqual(fires([[finger(1, 0.02)], [finger(1, 0.60)]], &r), 0)
    }

    func testThirdFingerCancels() {
        var r = EdgeSwipeRecognizer(edge: .left)
        let frames = [[finger(1, 0.02), finger(2, 0.03)],
                      [finger(1, 0.10), finger(2, 0.11), finger(3, 0.5)],
                      [finger(1, 0.40), finger(2, 0.41)]]
        XCTAssertEqual(fires(frames, &r), 0)
    }

    func testResetsAfterFingersLift() {
        var r = EdgeSwipeRecognizer(edge: .left)
        let swipe = [[finger(1, 0.02), finger(2, 0.03)], [finger(1, 0.30), finger(2, 0.31)]]
        XCTAssertEqual(fires(swipe + [[]] + swipe, &r), 2)
        // Lifting fingers (non-touching states) counts as empty too.
        XCTAssertEqual(fires([[finger(1, 0.3, state: 7), finger(2, 0.3, state: 7)]] + swipe, &r), 1)
    }

    func testClaimsScrollUntilLiftEvenAfterFiring() {
        var r = EdgeSwipeRecognizer(edge: .left)
        _ = r.process([finger(1, 0.02), finger(2, 0.03)])
        XCTAssertTrue(r.claimsScroll)
        XCTAssertTrue(r.process([finger(1, 0.30), finger(2, 0.31)]))
        XCTAssertTrue(r.claimsScroll)
        _ = r.process([])
        XCTAssertFalse(r.claimsScroll)
    }

    func testDoesNotClaimScrollAwayFromEdgeOrAfterCancel() {
        var r = EdgeSwipeRecognizer(edge: .left)
        _ = r.process([finger(1, 0.40), finger(2, 0.42)])
        XCTAssertFalse(r.claimsScroll)
        _ = r.process([])
        _ = r.process([finger(1, 0.02), finger(2, 0.03)])
        _ = r.process([finger(1, 0.05)])
        XCTAssertFalse(r.claimsScroll)
    }

    // MARK: Top edge

    private func top(_ id: Int32, _ y: Float) -> Touch {
        Touch(id: id, x: 0.4 + Float(id) * 0.05, y: y, state: 4, size: 1)
    }

    func testTwoFingerSwipeDownFromTopEdgeFiresOnce() {
        var r = EdgeSwipeRecognizer(edge: .top)
        let frames = [[top(1, 0.97), top(2, 0.96)],
                      [top(1, 0.85), top(2, 0.84)],
                      [top(1, 0.70), top(2, 0.69)],
                      [top(1, 0.50), top(2, 0.49)]]
        XCTAssertEqual(fires(frames, &r), 1)
    }

    func testSwipeUpFromTopEdgeDoesNotFire() {
        var r = EdgeSwipeRecognizer(edge: .top)
        XCTAssertEqual(fires([[top(1, 0.92), top(2, 0.93)], [top(1, 0.99), top(2, 0.99)]], &r), 0)
    }

    func testSwipeDownStartingBelowTopEdgeDoesNotFire() {
        var r = EdgeSwipeRecognizer(edge: .top)
        XCTAssertEqual(fires([[top(1, 0.70), top(2, 0.70)], [top(1, 0.30), top(2, 0.30)]], &r), 0)
    }

    func testLeftEdgeSwipeIgnoresTopEdgeSwipe() {
        var r = EdgeSwipeRecognizer(edge: .left)
        XCTAssertEqual(fires([[top(1, 0.97), top(2, 0.96)], [top(1, 0.50), top(2, 0.49)]], &r), 0)
    }
}
