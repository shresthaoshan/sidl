import AppKit
import os

/// Action for a gesture that fires once (a swipe or a corner click).
enum DiscreteAction: Codable, Hashable {
    case disabled
    case openApp(bundleID: String)
    case playPause
    case nextTrack
    case previousTrack
    case screenshot
    case keyboardShortcut(KeyCombo?)  // nil until the user records one

    var title: String {
        switch self {
        case .disabled: "None"
        case .openApp(let bundleID): bundleID.isEmpty ? "Open app…" : "Open \(Self.appName(bundleID))"
        case .playPause: "Play/Pause"
        case .nextTrack: "Next track"
        case .previousTrack: "Previous track"
        case .screenshot: "Screenshot"
        case .keyboardShortcut(let combo): "Shortcut \(combo?.display ?? "(not set)")"
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
    static let sensitivityLevels = 1...5
    static let defaultSensitivity = 3

    var leftEdgeSwipe = DiscreteAction.openApp(bundleID: "com.apple.Terminal")
    var topEdgeSwipe = DiscreteAction.playPause
    var leftEdgeSlide = ContinuousAction.brightness
    var rightEdgeSlide = ContinuousAction.volume
    var topLeftCorner = DiscreteAction.previousTrack
    var topRightCorner = DiscreteAction.nextTrack
    var slideSensitivity = defaultSensitivity  // shared by both slides
    var swipeSensitivity = defaultSensitivity  // shared by both swipes

    /// Multiplier on slide travel. Level 3 changes the level 0% to 100% over one full trackpad height.
    var slideMultiplier: Float { [0.5, 0.75, 1, 1.5, 2][Self.validLevel(slideSensitivity) - 1] }

    /// Travel each finger needs for a swipe, as a fraction of the trackpad.
    var swipeTravel: Float { [0.20, 0.17, 0.14, 0.11, 0.08][Self.validLevel(swipeSensitivity) - 1] }

    static func validLevel(_ level: Int) -> Int {
        sensitivityLevels.contains(level) ? level : defaultSensitivity
    }
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
        Self.load("topLeftCorner", into: &m.topLeftCorner, from: defaults)
        Self.load("topRightCorner", into: &m.topRightCorner, from: defaults)
        Self.load("slideSensitivity", into: &m.slideSensitivity, from: defaults)
        Self.load("swipeSensitivity", into: &m.swipeSensitivity, from: defaults)
        m.slideSensitivity = Mapping.validLevel(m.slideSensitivity)
        m.swipeSensitivity = Mapping.validLevel(m.swipeSensitivity)
        mapping = m
        snapshot = OSAllocatedUnfairLock(initialState: m)
    }

    private func save() {
        store("leftEdgeSwipe", mapping.leftEdgeSwipe)
        store("topEdgeSwipe", mapping.topEdgeSwipe)
        store("leftEdgeSlide", mapping.leftEdgeSlide)
        store("rightEdgeSlide", mapping.rightEdgeSlide)
        store("topLeftCorner", mapping.topLeftCorner)
        store("topRightCorner", mapping.topRightCorner)
        store("slideSensitivity", mapping.slideSensitivity)
        store("swipeSensitivity", mapping.swipeSensitivity)
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
