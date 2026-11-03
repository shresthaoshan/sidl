import SwiftUI
import XCTest
@testable import Touchyy

final class SettingsViewTests: XCTestCase {
    /// Regression: the window opened with only a title bar because its content had no height.
    func testSettingsWindowShowsContent() {
        let window = SettingsWindow.makeWindow()
        XCTAssertGreaterThan(window.contentLayoutRect.height, 100, "content rect: \(window.contentLayoutRect)")
    }
}
