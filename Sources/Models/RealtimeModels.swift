import Foundation
import CoreLocation

// MARK: - Vehicle Position

/// A single vehicle position from the worker's GTFS-RT decoder.
/// Shape mirrors workers/src/gtfs-rt.ts VehiclePosition.
struct VehiclePosition: Codable, Identifiable, Hashable {
    /// Per-snapshot UUID from the GTFS-RT FeedEntity.id.
    /// Note: this rotates every feed refresh — use `vehicleId` if you need
    /// a stable id across snapshots (for SwiftUI animation matching).
    let entityId: String
    let tripId: String?
    let routeId: String?
    let vehicleId: String?
    let vehicleLabel: String?
    let lat: Double?
    let lon: Double?
    /// Compass bearing 0..<360 (normalized server-side).
    let bearing: Double?
    /// Meters per second.
    let speed: Double?
    let currentStopSequence: Int?
    let stopId: String?
    /// Unix seconds when the position was recorded by the vehicle.
    let timestamp: TimeInterval?

    var id: String { entityId }

    /// Convenience for MapKit. Nil if the source feed lacked coordinates.
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Stable id across snapshots — use as ForEach id when you want SwiftUI
    /// to keep annotation identity steady so movement animates instead of
    /// re-creating views.
    var stableId: String { vehicleId ?? entityId }
}

// MARK: - Realtime Feed Response

/// Decoded response from GET /vehicles[?line=N].
struct RealtimeFeed: Codable {
    let serviceActive: Bool
    let feedTimestamp: TimeInterval?
    let decodedAt: String?
    let line: String?
    let filterApplied: Bool?
    let staticMissing: Bool?
    let count: Int?
    let vehicles: [VehiclePosition]
    /// Present only when serviceActive == false.
    let message: String?
}

// MARK: - Static Routes Response

/// Decoded response from GET /static/routes.
struct StaticRoutesResponse: Codable {
    let generatedAt: String
    let count: Int
    let routes: [String: StaticRoute]
    let lineRoutes: [String: [String]]
}

/// One row from the GTFS routes.txt, indexed by route_id.
struct StaticRoute: Codable, Hashable {
    let routeId: String
    /// "1", "2", ... "7" — GTFS route_short_name.
    let line: String
    let longName: String
    /// Hex color without leading "#" (e.g. "D40D0D").
    let color: String
    let textColor: String
}

// MARK: - Static Stops Response

struct StaticStopsResponse: Codable {
    let generatedAt: String
    let count: Int
    let stops: [String: StaticStop]
}

struct StaticStop: Codable, Hashable, Identifiable {
    let stopId: String
    let name: String
    let lat: Double
    let lon: Double

    var id: String { stopId }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
