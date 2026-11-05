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
        if count < 0 { NSLog("Sidl: failed to load MultitouchSupport") }
    }

    private func handle(_ frame: [Touch], device: UInt) {
        let mapping = SettingsStore.shared.snapshot.withLock { $0 }
        let time = ProcessInfo.processInfo.systemUptime
        let out = hub.withLock { $0.process(frame, device: device, mapping: mapping, time: time) }

        // Here, not on the main thread: `device` is valid only during the frame callback.
        // Waveform 6 is a strong short tick. NSHapticFeedbackManager has one strength, and it is too weak.
        if mapping.swipeHaptics && !out.discrete.isEmpty {
            let result = mt_actuate(device, 6)
            if result != 0 { NSLog("Sidl: haptic failed: \(result)") }
        }

        DispatchQueue.main.async {
            self.touches = frame
            if !out.spots.isEmpty {
                let touching = frame.filter { $0.state == 4 }
                let center = touching.isEmpty ? nil
                    : CGPoint(x: CGFloat(touching.map(\.x).reduce(0, +)) / CGFloat(touching.count),
                              y: CGFloat(touching.map(\.y).reduce(0, +)) / CGFloat(touching.count))
                for spot in out.spots { GestureActivity.shared.record(spot, at: center) }
            }
            for action in out.discrete { Actions.perform(action) }
            for (action, delta) in out.continuous {
                switch Actions.adjust(action, by: delta) {
                case .level(let level):
                    HUD.shared.show(action, level: level)
                case .pending:
                    break  // the HUD appears when the level is known
                case .unsupported:
                    HUD.shared.show(action, level: nil)
                }
            }
        }
    }
}

/// The gestures that just ran, so the Settings drawing can animate them. Main thread only.
final class GestureActivity: ObservableObject {
    static let shared = GestureActivity()

    struct Fire: Equatable {
        let spot: GestureSpot
        let point: CGPoint?  // finger center, 0..1, y from the bottom; nil for corner clicks
        let id: Int          // a new value for each fire, also for the same gesture twice
    }

    @Published private(set) var lastFire: Fire?
    /// Slides that are running now. Changes only when a slide starts or ends, not on every frame.
    @Published private(set) var sliding: Set<GestureSpot> = []

    private var count = 0
    private var slideEnds: [GestureSpot: DispatchWorkItem] = [:]

    func record(_ spot: GestureSpot, at point: CGPoint?) {
        guard spot.continuous != nil else {
            count += 1
            lastFire = Fire(spot: spot, point: point, id: count)
            return
        }
        if !sliding.contains(spot) { sliding.insert(spot) }
        // A slide sends a frame about every 8 ms. It ends when no frame comes for a short time.
        slideEnds[spot]?.cancel()
        let end = DispatchWorkItem { [weak self] in self?.sliding.remove(spot) }
        slideEnds[spot] = end
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: end)
    }
}
