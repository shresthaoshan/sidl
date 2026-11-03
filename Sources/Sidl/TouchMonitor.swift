import CMultitouch
import Foundation
import os

struct Touch: Identifiable {
    let id: Int32
    let x: Float  // 0..1, left to right
    let y: Float  // 0..1, bottom to top
    let state: Int32
    let size: Float
}

/// Receives raw trackpad contacts from MultitouchSupport.
/// Gestures are recognized on the touch thread, so scroll blocking takes effect without a main-thread delay.
final class TouchMonitor: ObservableObject {
    static let shared = TouchMonitor()

    @Published private(set) var touches: [Touch] = []
    @Published private(set) var deviceCount: Int32 = 0
    @Published private(set) var lastGesture = "none"

    /// Read by the touch threads and the event tap. The lock also serializes frames from different trackpads.
    private let hub = OSAllocatedUnfairLock(initialState: TouchHub())
    private var restartWork: DispatchWorkItem?

    private init() {}

    /// Main thread only.
    func start() {
        restart()
        DeviceWatcher.start { [weak self] in self?.scheduleRestart() }
    }

    func stop() { mt_stop() }

    /// True if a gesture on any trackpad owns the fingers.
    var claimsScroll: Bool { hub.withLock { $0.claimsScroll } }

    /// The corner that a click at `time` belongs to, on any trackpad.
    func corner(at time: Double) -> Corner? { hub.withLock { $0.corner(at: time) } }

    /// Shows an action in the panel's "Last gesture" line. Main thread only.
    func report(_ title: String) { lastGesture = title }

    /// One device change often sends several notifications, so wait until they stop.
    private func scheduleRestart() {
        restartWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restart() }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    /// Reads the device list again and starts every trackpad that is connected now.
    private func restart() {
        let count = mt_start { device, touches, count, _ in
            let frame = (0..<Int(count)).map { i -> Touch in
                let t = touches![i]
                return Touch(id: t.identifier, x: t.normalized.position.x, y: t.normalized.position.y,
                             state: t.state, size: t.size)
            }
            TouchMonitor.shared.handle(frame, device: UInt(device))
        }
        hub.withLock { $0.removeAll() }  // device IDs from the old list are no longer valid
        deviceCount = count
    }

    private func handle(_ frame: [Touch], device: UInt) {
        let mapping = SettingsStore.shared.snapshot.withLock { $0 }
        let time = ProcessInfo.processInfo.systemUptime
        let out = hub.withLock { $0.process(frame, device: device, mapping: mapping, time: time) }

        DispatchQueue.main.async {
            self.touches = frame
            for action in out.discrete {
                self.lastGesture = action.title
                Actions.perform(action)
            }
            for (action, delta) in out.continuous {
                if let level = Actions.adjust(action, by: delta) {
                    self.lastGesture = "\(action.title) \(Int((level * 100).rounded()))%"
                    HUD.shared.show(action, level: level)
                }
            }
        }
    }
}
