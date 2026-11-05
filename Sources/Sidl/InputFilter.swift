import ApplicationServices
import Foundation

/// One event tap for Sidl's input changes. Needs Accessibility permission.
/// - Drops scroll events while a gesture owns the fingers.
/// - Turns a click in a top corner into the corner's action, and drops the click.
final class InputFilter: ObservableObject {
    static let shared = InputFilter()

    @Published private(set) var isActive = false

    private var tap: CFMachPort?
    private var droppedLast = false  // momentum events follow the fate of the scroll they belong to
    private var clicks = ClickFilter()

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
        let types: [CGEventType] = [.scrollWheel, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, _ in
            InputFilter.shared.filter(type, event)
        }, userInfo: nil) else { return false }

        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        isActive = true
        return true
    }

    private func filter(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .scrollWheel:
            let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
            let drop = TouchMonitor.shared.claimsScroll || (momentum && droppedLast)
            if !momentum { droppedLast = drop }
            return drop ? nil : pass
        case .leftMouseDown:
            let corner = cornerAction()
            guard clicks.handle(.down, cornerAction: corner != nil), let corner else { return pass }
            // Run the action after the tap returns, so the event tap stays fast.
            DispatchQueue.main.async {
                GestureActivity.shared.record(corner.spot, at: nil)
                Actions.perform(corner.action)
            }
            return nil
        case .leftMouseDragged:
            return clicks.handle(.dragged, cornerAction: false) ? nil : pass
        case .leftMouseUp:
            return clicks.handle(.up, cornerAction: false) ? nil : pass
        default:
            return pass
        }
    }

    /// The corner under a single finger and its action, if that corner has one.
    private func cornerAction() -> (spot: GestureSpot, action: DiscreteAction)? {
        let m = SettingsStore.shared.mapping
        let corner: (spot: GestureSpot, action: DiscreteAction)? = switch TouchMonitor.shared.corner(at: ProcessInfo.processInfo.systemUptime) {
        case .topLeft: (.topLeftCorner, m.topLeftCorner)
        case .topRight: (.topRightCorner, m.topRightCorner)
        case nil: nil
        }
        return corner?.action == .disabled ? nil : corner
    }
}
