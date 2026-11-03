import Foundation
import IOKit

/// The result of one slide step on a level control.
enum AdjustResult: Equatable {
    case level(Float)  // the new level, 0..1
    case pending       // the level is not known yet, for example while a monitor is read the first time
    case unsupported
}

/// I2C access to external monitors on Apple silicon, through private IOKit functions.
enum DDCIO {
    private typealias CreateFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
    private typealias I2CFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

    private static let lib = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
    private static let create = lib.flatMap { dlsym($0, "IOAVServiceCreateWithService") }.map { unsafeBitCast($0, to: CreateFn.self) }
    private static let readI2C = lib.flatMap { dlsym($0, "IOAVServiceReadI2C") }.map { unsafeBitCast($0, to: I2CFn.self) }
    private static let writeI2C = lib.flatMap { dlsym($0, "IOAVServiceWriteI2C") }.map { unsafeBitCast($0, to: I2CFn.self) }

    /// The AV services of all external displays. Intel Macs have none, so DDC is off there.
    static func externalServices() -> [CFTypeRef] {
        guard let create else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }

        var services: [CFTypeRef] = []
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            if location == "External", let service = create(kCFAllocatorDefault, entry)?.takeRetainedValue() {
                services.append(service)
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return services
    }

    /// Blocks for about 50 ms. Never call it on the main thread or the touch thread.
    static func read(_ service: CFTypeRef, code: UInt8) -> (current: UInt16, max: UInt16)? {
        guard let readI2C, let writeI2C else { return nil }
        for _ in 0..<3 {  // DDC often fails once; monitors expect a short retry
            var request = DDC.getPacket(code: code)
            guard writeI2C(service, DDC.chipAddress, DDC.dataAddress, &request, UInt32(request.count)) == kIOReturnSuccess
            else { usleep(20_000); continue }
            usleep(50_000)  // the monitor needs time before the reply is ready
            var reply = [UInt8](repeating: 0, count: 11)
            if readI2C(service, DDC.chipAddress, DDC.dataAddress, &reply, UInt32(reply.count)) == kIOReturnSuccess,
               let value = DDC.parseReply(reply, code: code) {
                return value
            }
            usleep(20_000)
        }
        return nil
    }

    /// Blocks for a few ms. Never call it on the main thread or the touch thread.
    @discardableResult
    static func write(_ service: CFTypeRef, code: UInt8, value: UInt16) -> Bool {
        guard let writeI2C else { return false }
        var packet = DDC.setPacket(code: code, value: value)
        for _ in 0..<2 {
            if writeI2C(service, DDC.chipAddress, DDC.dataAddress, &packet, UInt32(packet.count)) == kIOReturnSuccess {
                return true
            }
            usleep(10_000)
        }
        return false
    }

    /// Matches a display to an AV service. Only one external display is supported for now: with more,
    /// the order of displays and services is not known to match, and a wrong match changes the wrong monitor.
    static func service<Service>(for display: UInt32, externalDisplays: [UInt32], services: [Service]) -> Service? {
        guard externalDisplays == [display], services.count == 1 else { return nil }
        return services[0]
    }
}

/// Brightness of one external monitor over DDC/CI. Sidl keeps its own copy of the level,
/// because DDC reads are slow and the HUD must follow the fingers. Main thread only.
final class DDCDisplay {
    private let service: CFTypeRef
    private let queue = DispatchQueue(label: "app.sidl.ddc")  // serial: writes reach the monitor in order

    private var level: Float?
    private var maxValue: UInt16 = 100
    private var pendingDelta: Float = 0  // slide travel while the first read runs
    private var loading = false
    private var failedAt: Double?
    private var throttle = WriteThrottle(interval: 0.05)

    private static let retryAfter: Double = 5

    init(service: CFTypeRef) { self.service = service }

    func change(by delta: Float) -> AdjustResult {
        let now = ProcessInfo.processInfo.systemUptime
        if let failedAt, now - failedAt < Self.retryAfter { return .unsupported }
        guard let current = level else {
            pendingDelta += delta
            load()
            return .pending
        }

        let new = min(max(current + delta, 0), 1)
        level = new
        switch throttle.request(at: now) {
        case .writeNow:
            send(new)
        case .writeAt(let time):
            DispatchQueue.main.asyncAfter(deadline: .now() + max(time - now, 0)) { [self] in
                throttle.didWrite(at: ProcessInfo.processInfo.systemUptime)
                if let level { send(level) }  // the newest level, not the one from when it was scheduled
            }
        case .alreadyScheduled:
            break
        }
        return .level(new)
    }

    private func load() {
        guard !loading else { return }
        loading = true
        let service = service
        queue.async {
            let value = DDCIO.read(service, code: DDC.brightness)
            DispatchQueue.main.async { [self] in
                loading = false
                guard let value else {
                    failedAt = ProcessInfo.processInfo.systemUptime
                    pendingDelta = 0
                    return
                }
                failedAt = nil
                maxValue = value.max
                level = Float(value.current) / Float(value.max)
                let delta = pendingDelta
                pendingDelta = 0
                if delta != 0 { _ = change(by: delta) }
            }
        }
    }

    private func send(_ level: Float) {
        let value = UInt16((level * Float(maxValue)).rounded())
        let service = service
        queue.async { DDCIO.write(service, code: DDC.brightness, value: value) }
    }
}
