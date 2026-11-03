/// Gesture state for each trackpad, so frames from two trackpads never mix.
struct TouchHub {
    private struct Device {
        var router = GestureRouter()
        var corners = CornerClickDetector()
        var claimsScroll = false
    }

    private var devices: [UInt: Device] = [:]

    /// True if a gesture on any trackpad owns the fingers.
    var claimsScroll: Bool { devices.values.contains { $0.claimsScroll } }

    var deviceCount: Int { devices.count }

    /// Feeds one frame from one trackpad. `time` is in seconds, from the same clock as `corner(at:)`.
    mutating func process(_ frame: [Touch], device: UInt, mapping: Mapping, time: Double) -> GestureRouter.Output {
        var d = devices[device] ?? Device()
        let out = d.router.process(frame, mapping: mapping)
        d.corners.process(frame, time: time)
        d.claimsScroll = out.claimsScroll
        devices[device] = d
        return out
    }

    /// The corner that a click at `time` belongs to, on any trackpad.
    func corner(at time: Double) -> Corner? {
        devices.values.lazy.compactMap { $0.corners.corner(at: time) }.first
    }

    /// Forgets all trackpads, for example when the device list is read again.
    mutating func removeAll() { devices.removeAll() }
}
