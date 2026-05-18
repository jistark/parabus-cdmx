import Foundation
import CoreLocation

/// Abstraction over CLAuthorizationStatus that's testable without
/// CLLocationManager. LocationCoordinator translates the real Apple
/// enum into this.
enum LocationAuthStatus: Equatable {
    case notDetermined
    case authorized
    case denied
}

/// Outcome of the map bootstrap state machine. The view layer
/// reads this and decides what to render.
enum BootstrapOutcome: Equatable {
    /// Show pre-prompt sheet asking for location permission.
    case showPrePrompt
    /// Use the supplied station immediately, animate camera.
    case useStation(stationId: String)
    /// Wait for location (auth granted, request in flight).
    case waitingForLocation
}

/// Pure function: given the inputs, decide what the bootstrap should do.
/// No side effects, no async, no CLLocationManager. Trivially testable.
struct MapBootstrap {
    static let userDefaultsKeyLastStation = "parabus.map.lastStationId"
    static let userDefaultsKeyPrePromptShown = "parabus.map.hasShownLocationPrePrompt"

    /// Default fallback station when no GPS and no persisted state.
    /// First station of Line 1 — guaranteed to exist in GTFSStations.
    static let defaultSeedLine = "1"

    static func decide(
        authStatus: LocationAuthStatus,
        hasShownPrePrompt: Bool,
        persistedStationId: String?
    ) -> BootstrapOutcome {
        switch authStatus {
        case .notDetermined where !hasShownPrePrompt:
            return .showPrePrompt
        case .notDetermined:
            // Already shown once; treat like denied for this session.
            return fallbackOutcome(persistedStationId: persistedStationId)
        case .authorized:
            return .waitingForLocation
        case .denied:
            return fallbackOutcome(persistedStationId: persistedStationId)
        }
    }

    private static func fallbackOutcome(persistedStationId: String?) -> BootstrapOutcome {
        if let id = persistedStationId, !id.isEmpty {
            return .useStation(stationId: id)
        }
        // Sentinel — view layer resolves to first station of default line.
        return .useStation(stationId: defaultSeedStationId())
    }

    static func defaultSeedStationId() -> String {
        // First station of Line 1. GTFSStations is deterministic, so this
        // returns a stable id across runs.
        GTFSStations.stations(for: defaultSeedLine).first?.id ?? ""
    }
}
