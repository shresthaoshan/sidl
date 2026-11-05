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
