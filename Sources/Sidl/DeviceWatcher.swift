import AppKit
import IOKit

/// Calls `onChange` when a trackpad connects or disconnects, and after the Mac wakes from sleep.
enum DeviceWatcher {
    private static var onChange: (() -> Void)?
    private static var port: IONotificationPortRef?
    private static var iterators: [io_iterator_t] = []  // kept so the notifications stay active

    /// Main thread only. A second call does nothing.
    static func start(onChange: @escaping () -> Void) {
        guard port == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        self.onChange = onChange
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .commonModes)

        // Built-in trackpads and Magic Trackpads both register as AppleMultitouchDevice.
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(port, type, IOServiceMatching("AppleMultitouchDevice"),
                                                          { _, iterator in
                DeviceWatcher.drain(iterator)
                DeviceWatcher.onChange?()
            }, nil, &iterator)
            guard result == KERN_SUCCESS else { continue }
            drain(iterator)  // the notification starts only after the first drain
            iterators.append(iterator)
        }

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil, queue: .main) { _ in onChange() }
    }

    private static func drain(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }
}
