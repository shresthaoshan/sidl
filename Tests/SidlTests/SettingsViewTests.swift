import SwiftUI
import XCTest
@testable import Sidl

final class SettingsViewTests: XCTestCase {
    /// Regression: the window opened with only a title bar because its content had no height.
    func testSettingsWindowShowsContent() {
        let window = SettingsWindow.makeWindow()
        XCTAssertGreaterThan(window.contentLayoutRect.height, 100, "content rect: \(window.contentLayoutRect)")
    }
}

final class GestureSpotTests: XCTestCase {
    /// Each gesture in Mapping has exactly one mark, so none is missing from the drawing.
    func testEachGestureHasOneMark() {
        let discrete = GestureSpot.allCases.compactMap(\.discrete)
        let continuous = GestureSpot.allCases.compactMap(\.continuous)
        XCTAssertEqual(Set(discrete), [\Mapping.leftEdgeSwipe, \.topEdgeSwipe, \.topLeftCorner, \.topRightCorner])
        XCTAssertEqual(Set(continuous), [\Mapping.leftEdgeSlide, \.rightEdgeSlide])
        XCTAssertEqual(discrete.count + continuous.count, GestureSpot.allCases.count)
    }

    func testMarkShowsTheCurrentAction() {
        var mapping = Mapping()
        mapping.topEdgeSwipe = .nextTrack
        mapping.rightEdgeSlide = .disabled
        XCTAssertEqual(GestureSpot.topEdgeSwipe.actionTitle(in: mapping), "Next track")
        XCTAssertEqual(GestureSpot.leftEdgeSlide.actionTitle(in: mapping), "Brightness")
        XCTAssertTrue(GestureSpot.rightEdgeSlide.isDisabled(in: mapping))
        XCTAssertFalse(GestureSpot.topEdgeSwipe.isDisabled(in: mapping))
    }
}

final class TrackpadSizeTests: XCTestCase {
    func testRealSizeKeepsProportions() {
        let size = TrackpadSize.fit(surface: CGSize(width: 120, height: 75), pointsPerMillimeter: 6, maxWidth: 1000)
        XCTAssertEqual(size, CGSize(width: 720, height: 450))
    }

    func testTooWideIsLimited() {
        let size = TrackpadSize.fit(surface: CGSize(width: 160, height: 100), pointsPerMillimeter: 6, maxWidth: 800)
        XCTAssertEqual(size, CGSize(width: 800, height: 500))
    }

    func testUnknownSizeUsesFallback() {
        XCTAssertEqual(TrackpadSize.fit(surface: .zero, pointsPerMillimeter: 6, maxWidth: 800), TrackpadSize.fallback)
        XCTAssertEqual(TrackpadSize.fit(surface: CGSize(width: 120, height: 75), pointsPerMillimeter: 0, maxWidth: 800),
                       TrackpadSize.fallback)
    }
}

final class TouchDotsTests: XCTestCase {
    private let size = CGSize(width: 400, height: 250)

    private func point(_ x: Float, _ y: Float) -> CGPoint {
        TouchDots.point(for: Touch(id: 1, x: x, y: y, state: 4, size: 1), in: size)
    }

    func testDotsStayInsideTheDrawing() {
        let r = TouchDots.dotSize / 2
        for (x, y) in [(Float(0), Float(1)), (1, 1), (0, 0), (1, 0), (1.05, -0.02)] {
            let p = point(x, y)
            XCTAssertTrue(CGRect(origin: .zero, size: size).insetBy(dx: r - 0.01, dy: r - 0.01).contains(p), "\(p)")
        }
    }

    func testTopOfTheTrackpadIsTopOfTheDrawing() {
        XCTAssertLessThan(point(0.5, 0.9).y, point(0.5, 0.1).y)
        XCTAssertLessThan(point(0.1, 0.5).x, point(0.9, 0.5).x)
    }
}

final class GestureActivityTests: XCTestCase {
    func testSwipeFiresAndSlideStartsAndEnds() {
        let activity = GestureActivity()
        activity.record(.topEdgeSwipe, at: CGPoint(x: 0.5, y: 0.9))
        activity.record(.topEdgeSwipe, at: nil)
        XCTAssertEqual(activity.lastFire?.spot, .topEdgeSwipe)
        XCTAssertEqual(activity.lastFire?.id, 2, "the same gesture twice must be two fires")

        activity.record(.rightEdgeSlide, at: nil)
        XCTAssertEqual(activity.sliding, [.rightEdgeSlide])
        XCTAssertEqual(activity.lastFire?.id, 2, "a slide is not a fire")
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(activity.sliding.isEmpty, "the slide ends when no frame comes")
    }
}
