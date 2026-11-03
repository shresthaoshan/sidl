import ApplicationServices
import Foundation
import os

/// Drops scroll events while a gesture owns the fingers. Needs Accessibility permission.
final class ScrollBlocker: ObservableObject {
    static let shared = ScrollBlocker()

    /// Set from the touch thread, read from the event tap on the main thread.
    let blocking = OSAllocatedUnfairLock(initialState: false)

    @Published private(set) var isActive = false

    private var tap: CFMachPort?
    private var droppedLast = false  // momentum events follow the fate of the scroll they belong to

    private init() {}

    func start() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        if installTap() { return }
        // Retry until the user grants Accessibility permission.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
            if self.installTap() { timer.invalidate() }
        }
    }

    private func installTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, _ in
            ScrollBlocker.shared.filter(type, event)
        }, userInfo: nil) else { return false }

        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        isActive = true
        return true
    }

    private func filter(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        let drop = blocking.withLock { $0 } || (momentum && droppedLast)
        if !momentum { droppedLast = drop }
        return drop ? nil : Unmanaged.passUnretained(event)
    }
}
