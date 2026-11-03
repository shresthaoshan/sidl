import XCTest
@testable import Touchyy

final class EdgeSwipeRecognizerTests: XCTestCase {
    private func finger(_ id: Int32, _ x: Float, state: Int32 = 4) -> Touch {
        Touch(id: id, x: x, y: 0.5, state: state, size: 1)
    }

    /// Feeds the frames in order and returns how many times the swipe fired.
    private func fires(_ frames: [[Touch]], _ r: inout EdgeSwipeRecognizer) -> Int {
        frames.filter { r.process($0) }.count
    }

    func testTwoFingerSwipeFromLeftEdgeFiresOnce() {
        var r = EdgeSwipeRecognizer()
        let frames = [[finger(1, 0.02), finger(2, 0.03)],
                      [finger(1, 0.15), finger(2, 0.16)],
                      [finger(1, 0.30), finger(2, 0.31)],
                      [finger(1, 0.50), finger(2, 0.51)]]
        XCTAssertEqual(fires(frames, &r), 1)
    }

    func testFingersLandingOneFrameApartStillFire() {
        var r = EdgeSwipeRecognizer()
        let frames = [[finger(1, 0.02)],
                      [finger(1, 0.03), finger(2, 0.04)],
                      [finger(1, 0.30), finger(2, 0.31)]]
        XCTAssertEqual(fires(frames, &r), 1)
    }

    func testSwipeStartingAwayFromEdgeDoesNotFire() {
        var r = EdgeSwipeRecognizer()
        let frames = [[finger(1, 0.40), finger(2, 0.42)],
                      [finger(1, 0.80), finger(2, 0.82)]]
        XCTAssertEqual(fires(frames, &r), 0)
    }

    func testOneFingerSwipeDoesNotFire() {
        var r = EdgeSwipeRecognizer()
        XCTAssertEqual(fires([[finger(1, 0.02)], [finger(1, 0.60)]], &r), 0)
    }

    func testThirdFingerCancels() {
        var r = EdgeSwipeRecognizer()
        let frames = [[finger(1, 0.02), finger(2, 0.03)],
                      [finger(1, 0.10), finger(2, 0.11), finger(3, 0.5)],
                      [finger(1, 0.40), finger(2, 0.41)]]
        XCTAssertEqual(fires(frames, &r), 0)
    }

    func testResetsAfterFingersLift() {
        var r = EdgeSwipeRecognizer()
        let swipe = [[finger(1, 0.02), finger(2, 0.03)], [finger(1, 0.30), finger(2, 0.31)]]
        XCTAssertEqual(fires(swipe + [[]] + swipe, &r), 2)
        // Lifting fingers (non-touching states) counts as empty too.
        XCTAssertEqual(fires([[finger(1, 0.3, state: 7), finger(2, 0.3, state: 7)]] + swipe, &r), 1)
    }
}
