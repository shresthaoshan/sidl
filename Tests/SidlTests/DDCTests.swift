import XCTest
@testable import Sidl

final class DDCTests: XCTestCase {
    func testSetBrightnessPacket() {
        // 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x00 ^ 0x32 = 0x9A
        XCTAssertEqual(DDC.setPacket(code: 0x10, value: 50), [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A])
    }

    func testSetPacketSplitsLargeValues() {
        let packet = DDC.setPacket(code: 0x10, value: 0x0123)
        XCTAssertEqual(Array(packet[3...4]), [0x01, 0x23])
    }

    func testGetBrightnessPacket() {
        // 0x6E ^ 0x51 ^ 0x82 ^ 0x01 ^ 0x10 = 0xAC
        XCTAssertEqual(DDC.getPacket(code: 0x10), [0x82, 0x01, 0x10, 0xAC])
    }

    func testParseReply() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0x00]
        let value = DDC.parseReply(reply, code: 0x10)
        XCTAssertEqual(value?.current, 50)
        XCTAssertEqual(value?.max, 100)
    }

    func testRejectBadReplies() {
        let good: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0x00]
        var unsupported = good; unsupported[3] = 0x01   // result code: VCP code not supported
        var otherCode = good; otherCode[4] = 0x12       // a reply for contrast
        var zeroMax = good; zeroMax[7] = 0x00
        var overMax = good; overMax[9] = 0x65
        for reply in [unsupported, otherCode, zeroMax, overMax, Array(good.prefix(9)), [UInt8](repeating: 0, count: 11)] {
            XCTAssertNil(DDC.parseReply(reply, code: 0x10), "\(reply)")
        }
    }
}

final class WriteThrottleTests: XCTestCase {
    func testFirstWriteIsImmediate() {
        var t = WriteThrottle(interval: 0.05)
        XCTAssertEqual(t.request(at: 10), .writeNow)
    }

    func testFastRequestsScheduleOneWrite() {
        var t = WriteThrottle(interval: 0.05)
        _ = t.request(at: 10)
        XCTAssertEqual(t.request(at: 10.01), .writeAt(10.05))
        XCTAssertEqual(t.request(at: 10.02), .alreadyScheduled)
        XCTAssertEqual(t.request(at: 10.04), .alreadyScheduled)
    }

    func testAfterTheScheduledWriteTheNextOneWaitsAgain() {
        var t = WriteThrottle(interval: 0.05)
        _ = t.request(at: 10)
        _ = t.request(at: 10.01)
        t.didWrite(at: 10.05)
        guard case .writeAt(let time) = t.request(at: 10.06) else { return XCTFail("expected a scheduled write") }
        XCTAssertEqual(time, 10.10, accuracy: 1e-9)
        XCTAssertEqual(t.request(at: 10.20), .alreadyScheduled, "a scheduled write must run before the next one")
    }

    func testSlowRequestsAreAllImmediate() {
        var t = WriteThrottle(interval: 0.05)
        XCTAssertEqual(t.request(at: 10), .writeNow)
        XCTAssertEqual(t.request(at: 10.06), .writeNow)
        XCTAssertEqual(t.request(at: 10.20), .writeNow)
    }
}

final class DDCMatchTests: XCTestCase {
    func testOneExternalDisplayMatchesItsOneService() {
        XCTAssertEqual(DDCIO.service(for: 7, externalDisplays: [7], services: ["svc"]), "svc")
    }

    func testNoMatchWhenTheCountsAreNotOne() {
        XCTAssertNil(DDCIO.service(for: 7, externalDisplays: [7, 8], services: ["a", "b"]), "two monitors: order unknown")
        XCTAssertNil(DDCIO.service(for: 7, externalDisplays: [7], services: [String]()), "no AV service, for example on Intel")
        XCTAssertNil(DDCIO.service(for: 7, externalDisplays: [8], services: ["svc"]), "the pointer is on another display")
    }
}
