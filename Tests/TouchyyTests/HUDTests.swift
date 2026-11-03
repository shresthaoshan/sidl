import XCTest
@testable import Touchyy

final class HUDTests: XCTestCase {
    func testPanelHasSizeAndIgnoresMouse() {
        let panel = HUD().panel
        XCTAssertGreaterThan(panel.frame.width, 150, "frame: \(panel.frame)")
        XCTAssertGreaterThan(panel.frame.height, 20, "frame: \(panel.frame)")
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testShowUpdatesLevelThenFades() {
        let hud = HUD()
        hud.show(.brightness, level: 0.4)
        XCTAssertEqual(hud.action, .brightness)
        XCTAssertEqual(hud.level, 0.4)
        XCTAssertTrue(hud.panel.isVisible)

        RunLoop.main.run(until: Date().addingTimeInterval(hud.fadeDelay + 0.6))
        XCTAssertFalse(hud.panel.isVisible)
    }

    func testRepeatedShowRestartsFade() {
        let hud = HUD()
        hud.show(.volume, level: 0.5)
        RunLoop.main.run(until: Date().addingTimeInterval(hud.fadeDelay * 0.7))
        hud.show(.volume, level: 0.6)
        RunLoop.main.run(until: Date().addingTimeInterval(hud.fadeDelay * 0.7))
        XCTAssertTrue(hud.panel.isVisible, "the second show must restart the timer")
    }

    func testSymbols() {
        XCTAssertEqual(HUD.symbol(for: .volume, level: 0), "speaker.slash.fill")
        XCTAssertEqual(HUD.symbol(for: .volume, level: 0.2), "speaker.wave.1.fill")
        XCTAssertEqual(HUD.symbol(for: .volume, level: 0.5), "speaker.wave.2.fill")
        XCTAssertEqual(HUD.symbol(for: .volume, level: 0.9), "speaker.wave.3.fill")
        XCTAssertEqual(HUD.symbol(for: .brightness, level: 0.3), "sun.min.fill")
        XCTAssertEqual(HUD.symbol(for: .brightness, level: 0.8), "sun.max.fill")
    }

    func testShowDuringFadeKeepsPanelVisible() {
        let hud = HUD()
        hud.show(.volume, level: 0.5)
        RunLoop.main.run(until: Date().addingTimeInterval(hud.fadeDelay + 0.1))  // fade is running
        hud.show(.volume, level: 0.6)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))  // old fade would have finished
        XCTAssertTrue(hud.panel.isVisible)
        XCTAssertEqual(hud.panel.alphaValue, 1)
    }
}
