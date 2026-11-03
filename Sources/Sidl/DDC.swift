/// DDC/CI messages, the standard way to control a monitor over its video cable.
/// Pure code: building and reading the bytes, with no hardware access.
enum DDC {
    static let brightness: UInt8 = 0x10  // VCP code for brightness
    static let chipAddress: UInt32 = 0x37
    static let dataAddress: UInt32 = 0x51

    /// "Set VCP feature": [length, opcode 0x03, code, value high, value low, checksum].
    static func setPacket(code: UInt8, value: UInt16) -> [UInt8] {
        withChecksum([0x84, 0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    /// "Get VCP feature": [length, opcode 0x01, code, checksum].
    static func getPacket(code: UInt8) -> [UInt8] {
        withChecksum([0x82, 0x01, code])
    }

    /// Reads a "Get VCP feature" reply. Returns nil if the reply is not a successful answer for `code`.
    static func parseReply(_ reply: [UInt8], code: UInt8) -> (current: UInt16, max: UInt16)? {
        guard reply.count >= 10, reply[2] == 0x02, reply[3] == 0x00, reply[4] == code else { return nil }
        let max = UInt16(reply[6]) << 8 | UInt16(reply[7])
        let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
        guard max > 0, current <= max else { return nil }
        return (current, max)
    }

    /// The checksum is an XOR of the destination address (0x6E), the source address (0x51), and every byte.
    private static func withChecksum(_ bytes: [UInt8]) -> [UInt8] {
        bytes + [bytes.reduce(0x6E ^ 0x51, ^)]
    }
}

/// Limits writes to one for each `interval`. A write that is too soon is scheduled once,
/// and it sends the newest value when it runs, so a fast slide cannot flood a slow monitor.
struct WriteThrottle {
    enum Decision: Equatable {
        case writeNow
        case writeAt(Double)
        case alreadyScheduled
    }

    let interval: Double
    private var lastWrite = -Double.infinity
    private var scheduled = false

    init(interval: Double) { self.interval = interval }

    mutating func request(at now: Double) -> Decision {
        if scheduled { return .alreadyScheduled }
        if now - lastWrite >= interval {
            lastWrite = now
            return .writeNow
        }
        scheduled = true
        return .writeAt(lastWrite + interval)
    }

    /// Call when a scheduled write runs.
    mutating func didWrite(at now: Double) {
        lastWrite = now
        scheduled = false
    }
}
