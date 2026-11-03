import CoreGraphics
import Foundation

/// Built-in display brightness through the private DisplayServices framework.
/// External displays are not supported (they need DDC).
enum Brightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let get = lib.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFn.self) }
    private static let set = lib.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFn.self) }

    /// Changes the brightness by `delta` (0..1 scale) and returns the new value, or nil if not supported.
    @discardableResult
    static func change(by delta: Float) -> Float? {
        guard let get, let set, let display = builtInDisplay() else { return nil }
        var value: Float = 0
        guard get(display, &value) == 0 else { return nil }
        value = min(max(value + delta, 0), 1)
        guard set(display, value) == 0 else { return nil }
        return value
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
