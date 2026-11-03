import XCTest
@testable import Sidl

final class SettingsStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "SidlTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsWhenNothingIsStored() {
        XCTAssertEqual(SettingsStore(defaults: defaults).mapping, Mapping())
        XCTAssertEqual(Mapping().leftEdgeSwipe, .openApp(bundleID: "com.apple.Terminal"))
        XCTAssertEqual(Mapping().topEdgeSwipe, .playPause)
        XCTAssertEqual(Mapping().leftEdgeSlide, .brightness)
        XCTAssertEqual(Mapping().rightEdgeSlide, .volume)
    }

    func testChangesPersistAcrossInstances() {
        let store = SettingsStore(defaults: defaults)
        store.mapping.leftEdgeSwipe = .openApp(bundleID: "com.apple.Safari")
        store.mapping.topEdgeSwipe = .nextTrack
        store.mapping.leftEdgeSlide = .disabled
        store.mapping.rightEdgeSlide = .brightness

        let reloaded = SettingsStore(defaults: defaults).mapping
        XCTAssertEqual(reloaded, store.mapping)
    }

    func testSnapshotFollowsChanges() {
        let store = SettingsStore(defaults: defaults)
        store.mapping.topEdgeSwipe = .previousTrack
        XCTAssertEqual(store.snapshot.withLock { $0 }.topEdgeSwipe, .previousTrack)
    }

    func testUnreadableValueFallsBackToDefaultForThatGestureOnly() {
        defaults.set(Data("garbage".utf8), forKey: "gesture.topEdgeSwipe")
        defaults.set(try! JSONEncoder().encode(ContinuousAction.disabled), forKey: "gesture.rightEdgeSlide")

        let mapping = SettingsStore(defaults: defaults).mapping
        XCTAssertEqual(mapping.topEdgeSwipe, .playPause)
        XCTAssertEqual(mapping.rightEdgeSlide, .disabled)
    }

    // MARK: Sensitivity

    func testSensitivityDefaultsToLevel3() {
        let mapping = SettingsStore(defaults: defaults).mapping
        XCTAssertEqual(mapping.slideSensitivity, 3)
        XCTAssertEqual(mapping.swipeSensitivity, 3)
        XCTAssertEqual(mapping.slideMultiplier, 1)
        XCTAssertEqual(mapping.swipeTravel, 0.14)
    }

    func testSensitivityPersists() {
        let store = SettingsStore(defaults: defaults)
        store.mapping.slideSensitivity = 5
        store.mapping.swipeSensitivity = 1
        let reloaded = SettingsStore(defaults: defaults).mapping
        XCTAssertEqual(reloaded.slideSensitivity, 5)
        XCTAssertEqual(reloaded.swipeSensitivity, 1)
        XCTAssertEqual(reloaded.slideMultiplier, 2)
        XCTAssertEqual(reloaded.swipeTravel, 0.20)
    }

    func testInvalidSensitivityFallsBackToLevel3() {
        defaults.set(try! JSONEncoder().encode(9), forKey: "gesture.slideSensitivity")
        defaults.set(Data("garbage".utf8), forKey: "gesture.swipeSensitivity")
        let mapping = SettingsStore(defaults: defaults).mapping
        XCTAssertEqual(mapping.slideSensitivity, 3)
        XCTAssertEqual(mapping.swipeSensitivity, 3)
    }
}
