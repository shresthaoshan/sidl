import XCTest
@testable import Touchyy

final class EdgeSlideRecognizerTests: XCTestCase {
    private func pair(x: Float = 0.95, y: Float) -> [Touch] {
        [Touch(id: 1, x: x, y: y, state: 4, size: 1), Touch(id: 2, x: x + 0.02, y: y, state: 4, size: 1)]
    }

    func testVerticalSlideOnRightEdgeReportsTravel() {
        var r = EdgeSlideRecognizer(zone: 0.9...1.0)
        let deltas = [0.50, 0.52, 0.55, 0.65, 0.60].map { r.process(pair(x: 0.92, y: Float($0))) }
        XCTAssertEqual(deltas[0], 0)
        XCTAssertEqual(deltas[1], 0)                       // below activation
        XCTAssertEqual(deltas[2], 0.05, accuracy: 0.001)    // activation includes travel so far
        XCTAssertEqual(deltas[3], 0.10, accuracy: 0.001)
        XCTAssertEqual(deltas[4], -0.05, accuracy: 0.001)   // sliding down lowers
        XCTAssertEqual(r.phase, .sliding)
    }

    func testClaimsScrollFromLandingUntilLift() {
        var r = EdgeSlideRecognizer(zone: 0.9...1.0)
        _ = r.process(pair(x: 0.92, y: 0.5))
        XCTAssertTrue(r.claimsScroll)
        _ = r.process(pair(x: 0.92, y: 0.6))
        XCTAssertTrue(r.claimsScroll)
        _ = r.process([])
        XCTAssertFalse(r.claimsScroll)
    }

    func testHorizontalMoveRejects() {
        var r = EdgeSlideRecognizer(zone: 0.9...1.0)
        _ = r.process(pair(x: 0.95, y: 0.5))
        XCTAssertEqual(r.process(pair(x: 0.85, y: 0.51)), 0)
        XCTAssertEqual(r.phase, .rejected)
        XCTAssertFalse(r.claimsScroll)
        XCTAssertEqual(r.process(pair(x: 0.85, y: 0.9)), 0)  // stays rejected until lift
    }

    func testFingersOutsideZoneAreIgnored() {
        var r = EdgeSlideRecognizer(zone: 0.9...1.0)
        _ = r.process(pair(x: 0.5, y: 0.5))
        XCTAssertFalse(r.claimsScroll)
        XCTAssertEqual(r.process(pair(x: 0.5, y: 0.9)), 0)
    }

    func testLiftingOneFingerStopsSlide() {
        var r = EdgeSlideRecognizer(zone: 0.9...1.0)
        _ = r.process(pair(x: 0.92, y: 0.5))
        _ = r.process(pair(x: 0.92, y: 0.6))
        XCTAssertEqual(r.process([Touch(id: 1, x: 0.92, y: 0.7, state: 4, size: 1)]), 0)
        XCTAssertFalse(r.claimsScroll)
    }
}
