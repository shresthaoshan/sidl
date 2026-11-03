import AppKit
import CoreGraphics

/// Brightness of the display that has the pointer. Main thread only.
/// 1. DisplayServices (private): the built-in display, and displays that macOS itself controls.
/// 2. DDC/CI over the video cable: other external monitors, on Apple silicon.
enum Brightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let get = lib.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFn.self) }
    private static let set = lib.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFn.self) }

    private static var ddcDisplays: [CGDirectDisplayID: DDCDisplay] = [:]
    private static var watchingScreens = false

    /// Changes the brightness by `delta` (0..1 scale).
    static func change(by delta: Float) -> AdjustResult {
        guard let display = pointerDisplay() else { return .unsupported }
        if let level = changeWithDisplayServices(display, by: delta) { return .level(level) }
        return ddcDisplay(for: display)?.change(by: delta) ?? .unsupported
    }

    private static func changeWithDisplayServices(_ display: CGDirectDisplayID, by delta: Float) -> Float? {
        guard let get, let set else { return nil }
        var value: Float = 0
        guard get(display, &value) == 0 else { return nil }
        value = min(max(value + delta, 0), 1)
        guard set(display, value) == 0 else { return nil }
        return value
    }

    private static func ddcDisplay(for display: CGDirectDisplayID) -> DDCDisplay? {
        if let cached = ddcDisplays[display] { return cached }
        watchScreens()
        let externals = onlineDisplays().filter { CGDisplayIsBuiltin($0) == 0 }
        guard let service = DDCIO.service(for: display, externalDisplays: externals, services: DDCIO.externalServices())
        else { return nil }
        let ddc = DDCDisplay(service: service)
        ddcDisplays[display] = ddc
        return ddc
    }

    /// A monitor that connects, disconnects, or changes mode can get a new AV service, so forget the old ones.
    private static func watchScreens() {
        guard !watchingScreens else { return }
        watchingScreens = true
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in ddcDisplays.removeAll() }
    }

    private static func pointerDisplay() -> CGDirectDisplayID? {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        return (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private static func onlineDisplays() -> [CGDirectDisplayID] {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success else { return [] }
        return Array(displays.prefix(Int(count)))
    }
}
