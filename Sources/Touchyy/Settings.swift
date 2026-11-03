import AppKit
import os

/// Action for a gesture that fires once (a swipe).
enum DiscreteAction: Codable, Hashable {
    case disabled
    case openApp(bundleID: String)
    case playPause
    case nextTrack
    case previousTrack

    var title: String {
        switch self {
        case .disabled: "None"
        case .openApp(let bundleID): "Open \(Self.appName(bundleID))"
        case .playPause: "Play/Pause"
        case .nextTrack: "Next track"
        case .previousTrack: "Previous track"
        }
    }

    static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

/// Action for a gesture that reports travel every frame (a slide).
enum ContinuousAction: String, Codable, CaseIterable, Identifiable {
    case disabled, volume, brightness

    var id: String { rawValue }
    var title: String {
        switch self {
        case .disabled: "None"
        case .volume: "Volume"
        case .brightness: "Brightness"
        }
    }
}

struct Mapping: Equatable {
    var leftEdgeSwipe = DiscreteAction.openApp(bundleID: "com.apple.Terminal")
    var topEdgeSwipe = DiscreteAction.playPause
    var leftEdgeSlide = ContinuousAction.brightness
    var rightEdgeSlide = ContinuousAction.volume
}

/// Saves the mapping in UserDefaults, one JSON value per gesture.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var mapping: Mapping {
        didSet {
            save()
            snapshot.withLock { $0 = mapping }
        }
    }

    /// Copy of `mapping` for the touch thread.
    let snapshot: OSAllocatedUnfairLock<Mapping>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var m = Mapping()
        Self.load("leftEdgeSwipe", into: &m.leftEdgeSwipe, from: defaults)
        Self.load("topEdgeSwipe", into: &m.topEdgeSwipe, from: defaults)
        Self.load("leftEdgeSlide", into: &m.leftEdgeSlide, from: defaults)
        Self.load("rightEdgeSlide", into: &m.rightEdgeSlide, from: defaults)
        mapping = m
        snapshot = OSAllocatedUnfairLock(initialState: m)
    }

    private func save() {
        store("leftEdgeSwipe", mapping.leftEdgeSwipe)
        store("topEdgeSwipe", mapping.topEdgeSwipe)
        store("leftEdgeSlide", mapping.leftEdgeSlide)
        store("rightEdgeSlide", mapping.rightEdgeSlide)
    }

    private func store<T: Encodable>(_ key: String, _ value: T) {
        defaults.set(try? JSONEncoder().encode(value), forKey: "gesture.\(key)")
    }

    /// Keeps the default when the key is missing or holds a value this version cannot read.
    private static func load<T: Decodable>(_ key: String, into value: inout T, from defaults: UserDefaults) {
        guard let data = defaults.data(forKey: "gesture.\(key)"),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else { return }
        value = decoded
    }
}
