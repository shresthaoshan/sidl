import XCTest
@testable import Sidl

/// Replays trackpad frames recorded on a real trackpad (see "Record a test fixture" in CONTRIBUTING.md).
final class FixtureTests: XCTestCase {
    /// Each file, and the gestures it must fire, in order.
    /// The swipe files have two edge swipes each, and between them one-finger pointer moves and
    /// three-finger swipes back from the opened app. Those must not fire.
    private let expected: [String: [GestureSpot]] = [
        "left-edge-swipe": [.leftEdgeSwipe, .leftEdgeSwipe],
        "top-edge-swipe": [.topEdgeSwipe, .topEdgeSwipe],
        "scrolling": [],
        "notification-center": [],
        "three-finger-swipes": [],
    ]
    /// Files that must fire only this slide, at least once.
    private let slides: [String: GestureSpot] = ["left-edge-slide": .leftEdgeSlide, "right-edge-slide": .rightEdgeSlide]

    private static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")

    /// The frames in a file, in order. Lines with the same time and device are one frame.
    static func frames(_ name: String) throws -> [(device: UInt, touches: [Touch])] {
        let text = try String(contentsOf: folder.appendingPathComponent("\(name).csv"), encoding: .utf8)
        var frames: [(key: String, device: UInt, touches: [Touch])] = []
        for line in text.split(separator: "\n").dropFirst() {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let key = f[0] + "," + f[1]
            if frames.last?.key != key { frames.append((key, UInt(f[1])!, [])) }
            if !f[2].isEmpty {
                frames[frames.count - 1].touches.append(Touch(id: Int32(f[2])!, x: Float(f[3])!, y: Float(f[4])!,
                                                              state: Int32(f[5])!, size: Float(f[6])!))
            }
        }
        return frames.map { ($0.device, $0.touches) }
    }

    /// The gestures that fire. A slide fires on many frames in a row, so each run of frames counts once.
    static func fired(_ name: String) throws -> [GestureSpot] {
        var hub = TouchHub()
        var spots: [GestureSpot] = []
        var previous: [GestureSpot] = []
        for (i, frame) in try frames(name).enumerated() {
            let out = hub.process(frame.touches, device: frame.device, mapping: Mapping(), time: Double(i) / 120)
            spots += out.spots.filter { $0.continuous == nil || !previous.contains($0) }
            previous = out.spots
        }
        return spots
    }

    func testRecordedGesturesFireExactlyWhatTheyShould() throws {
        for (name, gestures) in expected {
            XCTAssertEqual(try Self.fired(name), gestures, name)
        }
        for (name, slide) in slides {
            let fired = try Self.fired(name)
            XCTAssertFalse(fired.isEmpty, "\(name) fired nothing")
            XCTAssertEqual(Set(fired), [slide], name)
        }
    }

    func testEveryFixtureIsChecked() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
            .filter { $0.hasSuffix(".csv") }.map { String($0.dropLast(4)) }
        XCTAssertEqual(Set(files), Set(expected.keys).union(slides.keys), "add each new file to the tables above")
    }
}
