import XCTest
@testable import Sidl

final class TouchHubTests: XCTestCase {
    private let builtIn: UInt = 1
    private let magic: UInt = 2

    private func pair(x: Float, y: Float) -> [Touch] {
        [Touch(id: 1, x: x, y: y, state: 4, size: 1), Touch(id: 2, x: x + 0.01, y: y - 0.01, state: 4, size: 1)]
    }

    /// Regression: with one shared router, an empty frame from the other trackpad looked like a lift and cancelled the swipe.
    func testSwipeOnOneTrackpadSurvivesFramesFromAnother() {
        var hub = TouchHub()
        var fired: [DiscreteAction] = []
        for x: Float in [0.02, 0.10, 0.20, 0.35] {
            fired += hub.process(pair(x: x, y: 0.5), device: builtIn, mapping: Mapping(), time: 0).discrete
            fired += hub.process([], device: magic, mapping: Mapping(), time: 0).discrete
        }
        XCTAssertEqual(fired, [Mapping().leftEdgeSwipe])
    }

    func testSlideOnOneTrackpadIsNotMixedWithFingersOnAnother() {
        var hub = TouchHub()
        var total: Float = 0
        for y: Float in [0.4, 0.5, 0.6] {
            total += hub.process(pair(x: 0.93, y: y), device: magic, mapping: Mapping(), time: 0)
                .continuous.map(\.delta).reduce(0, +)
            // A resting finger in the middle of the other trackpad.
            _ = hub.process([Touch(id: 1, x: 0.5, y: 0.2, state: 4, size: 1)], device: builtIn, mapping: Mapping(), time: 0)
        }
        XCTAssertEqual(total, 0.2, accuracy: 0.001)
    }

    func testScrollClaimFromAnyTrackpad() {
        var hub = TouchHub()
        _ = hub.process(pair(x: 0.02, y: 0.5), device: builtIn, mapping: Mapping(), time: 0)
        _ = hub.process([], device: magic, mapping: Mapping(), time: 0)
        XCTAssertTrue(hub.claimsScroll)
        _ = hub.process([], device: builtIn, mapping: Mapping(), time: 0)
        XCTAssertFalse(hub.claimsScroll)
    }

    func testCornerFromAnyTrackpad() {
        var hub = TouchHub()
        _ = hub.process([Touch(id: 1, x: 0.95, y: 0.95, state: 4, size: 1)], device: magic, mapping: Mapping(), time: 5)
        _ = hub.process([Touch(id: 1, x: 0.5, y: 0.5, state: 4, size: 1)], device: builtIn, mapping: Mapping(), time: 5)
        XCTAssertEqual(hub.corner(at: 5), .topRight)
    }

    func testEachTrackpadGetsItsOwnStateAndRemoveAllClearsIt() {
        var hub = TouchHub()
        _ = hub.process([], device: builtIn, mapping: Mapping(), time: 0)
        _ = hub.process([], device: magic, mapping: Mapping(), time: 0)
        XCTAssertEqual(hub.deviceCount, 2)
        _ = hub.process(pair(x: 0.02, y: 0.5), device: builtIn, mapping: Mapping(), time: 0)
        hub.removeAll()
        XCTAssertEqual(hub.deviceCount, 0)
        XCTAssertFalse(hub.claimsScroll)
    }
}
