import XCTest
@testable import Touchyy

final class GestureRouterTests: XCTestCase {
    private func pair(x: Float, y: Float) -> [Touch] {
        [Touch(id: 1, x: x, y: y, state: 4, size: 1), Touch(id: 2, x: x + 0.01, y: y - 0.01, state: 4, size: 1)]
    }

    /// Feeds the frames and collects every output.
    private func run(_ frames: [[Touch]], _ mapping: Mapping = Mapping()) -> [GestureRouter.Output] {
        var router = GestureRouter()
        return frames.map { router.process($0, mapping: mapping) }
    }


    private func swipeRight() -> [[Touch]] { [pair(x: 0.02, y: 0.5), pair(x: 0.15, y: 0.5), pair(x: 0.35, y: 0.5)] }
    private func swipeDown() -> [[Touch]] { [pair(x: 0.45, y: 0.97), pair(x: 0.45, y: 0.8), pair(x: 0.45, y: 0.6)] }
    private func slideUp(x: Float) -> [[Touch]] { [pair(x: x, y: 0.4), pair(x: x, y: 0.5), pair(x: x, y: 0.6)] }

    func testLeftSwipeRoutesToMappedAction() {
        var m = Mapping()
        m.leftEdgeSwipe = .openApp(bundleID: "com.apple.Safari")
        XCTAssertEqual(run(swipeRight(), m).flatMap(\.discrete), [.openApp(bundleID: "com.apple.Safari")])
    }

    func testTopSwipeRoutesToMappedAction() {
        var m = Mapping()
        m.topEdgeSwipe = .nextTrack
        XCTAssertEqual(run(swipeDown(), m).flatMap(\.discrete), [.nextTrack])
    }

    func testSlidesRouteToMappedActions() {
        var m = Mapping()
        m.leftEdgeSlide = .volume
        m.rightEdgeSlide = .brightness
        let left = run(slideUp(x: 0.03), m).flatMap(\.continuous)
        let right = run(slideUp(x: 0.93), m).flatMap(\.continuous)
        XCTAssertEqual(left.map(\.action), [.volume, .volume])
        XCTAssertEqual(right.map(\.action), [.brightness, .brightness])
        XCTAssertEqual(left.map(\.delta).reduce(0, +), 0.2, accuracy: 0.001)
    }

    func testDisabledGestureNeitherActsNorBlocksScroll() {
        var m = Mapping()
        m.leftEdgeSwipe = .disabled
        m.leftEdgeSlide = .disabled
        let outputs = run(swipeRight(), m)
        XCTAssertTrue(outputs.flatMap(\.discrete).isEmpty)
        XCTAssertFalse(outputs.contains { $0.claimsScroll })
    }

    func testEnabledEdgeGestureBlocksScroll() {
        XCTAssertTrue(run(swipeRight()).allSatisfy(\.claimsScroll))
    }

    func testSlideBlocksSwipeInTopRightCorner() {
        // Down from the top-right corner: the right-edge slide starts first, so play/pause must not fire.
        let frames = [pair(x: 0.93, y: 0.97), pair(x: 0.93, y: 0.8), pair(x: 0.93, y: 0.6)]
        let outputs = run(frames)
        XCTAssertTrue(outputs.flatMap(\.discrete).isEmpty)
        XCTAssertFalse(outputs.flatMap(\.continuous).isEmpty)
    }

    func testDisabledSlideNoLongerBlocksSwipeInCorner() {
        var m = Mapping()
        m.rightEdgeSlide = .disabled
        let frames = [pair(x: 0.93, y: 0.97), pair(x: 0.93, y: 0.8), pair(x: 0.93, y: 0.6)]
        XCTAssertEqual(run(frames, m).flatMap(\.discrete), [.playPause])
    }
}
