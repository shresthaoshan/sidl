import XCTest
@testable import Sidl

final class TrackpadViewTests: XCTestCase {
    private let size = CGSize(width: 328, height: 205)

    private func touch(_ id: Int32, _ x: Float, _ y: Float) -> Touch {
        Touch(id: id, x: x, y: y, state: 4, size: 1)
    }

    private func labelRect(_ p: TrackpadView.Placement) -> CGRect {
        let s = TrackpadView.labelSize
        return CGRect(x: p.label.x - s.width / 2, y: p.label.y - s.height / 2, width: s.width, height: s.height)
    }

    func testDotsAndLabelsStayInsideTheDrawing() {
        let corners = [touch(1, 0, 1), touch(2, 1, 1), touch(3, 0, 0), touch(4, 1, 0), touch(5, 1.05, -0.02)]
        let bounds = CGRect(origin: .zero, size: size)
        let r = TrackpadView.dotSize / 2
        for p in TrackpadView.layout(corners, in: size) {
            XCTAssertTrue((r...size.width - r).contains(p.dot.x) && (r...size.height - r).contains(p.dot.y),
                          "dot \(p.dot) for finger \(p.touch.id)")
            XCTAssertTrue(bounds.contains(labelRect(p)), "label \(labelRect(p)) for finger \(p.touch.id)")
        }
    }

    func testTwoCloseFingersGetLabelsThatDoNotOverlap() {
        for pair in [[touch(1, 0.42, 0.55), touch(2, 0.58, 0.50)],   // side by side
                     [touch(1, 0.50, 0.62), touch(2, 0.52, 0.48)]] { // stacked
            let placed = TrackpadView.layout(pair, in: size)
            XCTAssertFalse(labelRect(placed[0]).intersects(labelRect(placed[1])))
        }
    }

    func testLabelMovesBelowWhenThereIsNoRoomAbove() {
        let p = TrackpadView.layout([touch(1, 0.5, 1)], in: size)[0]
        XCTAssertGreaterThan(p.label.y, p.dot.y)
    }

    func testEveryFingerIsPlacedOnce() {
        let touches = (1...5).map { touch(Int32($0), Float($0) / 6, 0.5) }
        XCTAssertEqual(Set(TrackpadView.layout(touches, in: size).map(\.touch.id)), Set(1...5))
    }
}
