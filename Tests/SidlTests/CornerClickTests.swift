import XCTest
@testable import Sidl

final class CornerClickDetectorTests: XCTestCase {
    private func finger(_ x: Float, _ y: Float, id: Int32 = 1, state: Int32 = 4) -> Touch {
        Touch(id: id, x: x, y: y, state: state, size: 1)
    }

    func testEachTopCorner() {
        var d = CornerClickDetector()
        d.process([finger(0.05, 0.95)], time: 0)
        XCTAssertEqual(d.corner(at: 0), .topLeft)
        d.process([finger(0.95, 0.95)], time: 0)
        XCTAssertEqual(d.corner(at: 0), .topRight)
    }

    func testZoneEdges() {
        var d = CornerClickDetector()
        d.process([finger(0.12, 0.88)], time: 0)
        XCTAssertEqual(d.corner(at: 0), .topLeft, "the 12% boundary is inside")
        d.process([finger(0.13, 0.95)], time: 0)
        XCTAssertNil(d.corner(at: 0))
        d.process([finger(0.05, 0.87)], time: 0)
        XCTAssertNil(d.corner(at: 0))
    }

    func testBottomCornersAndMiddleAreIgnored() {
        var d = CornerClickDetector()
        for (x, y) in [(Float(0.05), Float(0.05)), (0.95, 0.05), (0.5, 0.95), (0.5, 0.5)] {
            d.process([finger(x, y)], time: 0)
            XCTAssertNil(d.corner(at: 0), "(\(x), \(y))")
        }
    }

    func testTwoFingersAreNeverACornerClick() {
        var d = CornerClickDetector()
        d.process([finger(0.05, 0.95), finger(0.5, 0.2, id: 2)], time: 0)
        XCTAssertNil(d.corner(at: 0))
    }

    func testMakeTouchStateCounts() {
        var d = CornerClickDetector()
        d.process([finger(0.05, 0.95, state: 3)], time: 0)  // a quick tap may never reach state 4
        XCTAssertEqual(d.corner(at: 0), .topLeft)
    }

    func testTapMemoryAfterLift() {
        var d = CornerClickDetector()
        d.process([finger(0.95, 0.95)], time: 10)
        d.process([finger(0.95, 0.95, state: 7)], time: 10.05)  // leaving
        XCTAssertEqual(d.corner(at: 10.05 + 0.29), .topRight)
        XCTAssertNil(d.corner(at: 10.05 + 0.31))
    }

    func testMovingOutOfTheCornerClearsIt() {
        var d = CornerClickDetector()
        d.process([finger(0.05, 0.95)], time: 0)
        d.process([finger(0.4, 0.6)], time: 0.1)
        XCTAssertNil(d.corner(at: 0.1))
    }
}

final class ClickFilterTests: XCTestCase {
    func testCornerClickDropsDownDragsAndUp() {
        var f = ClickFilter()
        XCTAssertTrue(f.handle(.down, cornerAction: true))
        XCTAssertTrue(f.handle(.dragged, cornerAction: false))
        XCTAssertTrue(f.handle(.up, cornerAction: false))
        XCTAssertFalse(f.swallowing)
    }

    func testNormalClickPasses() {
        var f = ClickFilter()
        XCTAssertFalse(f.handle(.down, cornerAction: false))
        XCTAssertFalse(f.handle(.dragged, cornerAction: false))
        XCTAssertFalse(f.handle(.up, cornerAction: false))
    }

    func testNextClickAfterCornerClickPasses() {
        var f = ClickFilter()
        _ = f.handle(.down, cornerAction: true)
        _ = f.handle(.up, cornerAction: false)
        XCTAssertFalse(f.handle(.down, cornerAction: false))
        XCTAssertFalse(f.handle(.up, cornerAction: false))
    }
}

final class KeyComboTests: XCTestCase {
    func testRecordsShortcutWithSymbolsInAppleOrder() {
        let combo = KeyCombo(keyCode: 17, flags: [.command, .option, .shift, .control], characters: "t")
        XCTAssertEqual(combo?.display, "⌃⌥⇧⌘T")
        XCTAssertEqual(combo?.keyCode, 17)
        XCTAssertEqual(combo.map { CGEventFlags(rawValue: $0.modifiers) },
                       [.maskControl, .maskAlternate, .maskShift, .maskCommand])
    }

    func testPlainKeyOrShiftOnlyIsRejected() {
        XCTAssertNil(KeyCombo(keyCode: 17, flags: [], characters: "t"))
        XCTAssertNil(KeyCombo(keyCode: 17, flags: [.shift], characters: "T"))
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(KeyCombo(keyCode: 49, flags: [.command], characters: " ")?.display, "⌘Space")
        XCTAssertEqual(KeyCombo(keyCode: 126, flags: [.control], characters: "")?.display, "⌃↑")
    }

    func testScreenshotIsCommandShift5() {
        XCTAssertEqual(KeyCombo.screenshotToolbar.keyCode, 23)  // kVK_ANSI_5
        XCTAssertEqual(CGEventFlags(rawValue: KeyCombo.screenshotToolbar.modifiers), [.maskCommand, .maskShift])
    }
}
