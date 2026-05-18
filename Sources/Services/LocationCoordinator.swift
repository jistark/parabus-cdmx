import Foundation
import CoreLocation
import Observation

/// Thin observable wrapper around CLLocationManager. Single
/// responsibility: translate the system authorization state to our
/// `LocationAuthStatus`, request authorization, request a one-shot
/// location. No business logic — view models read this and decide.
///
/// Not unit-tested directly (pure CLLocationManager wrapper). Validation
/// path: simulator with Debug screen buttons + Accessibility Inspector.
@MainActor
@Observable
final class LocationCoordinator: NSObject {

    private let manager = CLLocationManager()

    private(set) var authStatus: LocationAuthStatus = .notDetermined
    private(set) var latestLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Initial status snapshot — delegate fires didChangeAuthorization
        // immediately on creation in iOS 14+ but we read sync to avoid
        // a one-frame .notDetermined flicker.
        authStatus = Self.translate(manager.authorizationStatus)
    }

    /// Fire the system permission dialog. No-op if already decided.
    func requestAuthorization() {
        guard authStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Request a one-shot location. Caller must have authorized first.
    func requestLocation() {
        guard authStatus == .authorized else { return }
        manager.requestLocation()
    }

    nonisolated private static func translate(_ status: CLAuthorizationStatus) -> LocationAuthStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}

extension LocationCoordinator: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        let translated = Self.translate(status)
        Task { @MainActor in
            self.authStatus = translated
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.latestLocation = coord
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Non-fatal — view layer treats missing location as "use fallback".
        // CLError.denied surfaces as authStatus change separately.
    }
}

// MARK: - CLLocationCoordinate2D Equatable

/// Retroactive Equatable so SwiftUI's `.onChange(of:)` can observe
/// `LocationCoordinator.latestLocation`. Apple hasn't added this
/// conformance themselves as of iOS 18; `@retroactive` is the modern
/// Swift 6 way to acknowledge that this is a non-original-module
/// conformance.
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
