import CoreLocation
import Foundation

// MARK: - Timeline items (salida pura del planner; las vistas solo renderizan)

struct TimelineStation: Equatable, Identifiable {
    let station: GTFSStation
    let correspondences: [Correspondence]
    let isTerminal: Bool
    /// Estatus no suspensivo que tinta el nodo (.delayed/.limited/.intervention).
    let rowStatus: ServiceStatus?

    var id: String { station.id }
}

struct InterruptedSegment: Equatable {
    let stations: [GTFSStation]        // colapsadas, en orden de render
    let boundaryBefore: GTFSStation?   // última servida antes (nil si arranca en terminal)
    let boundaryAfter: GTFSStation?    // primera servida después
    let alternatives: [Alternative]
    let incident: Incident
}

enum Alternative: Equatable {
    case transfer(Correspondence, at: GTFSStation)
    case walk(minutes: Int, from: GTFSStation, to: GTFSStation)
}

enum TimelineItem: Equatable, Identifiable {
    case station(TimelineStation)
    case interruptedSegment(InterruptedSegment)
    case wholeLineBanner(Incident)

    var id: String {
        switch self {
        case .station(let s): return "st-\(s.station.id)"
        case .interruptedSegment(let seg): return "seg-\(seg.stations.first?.id ?? "empty")"
        case .wholeLineBanner: return "banner"
        }
    }
}

// MARK: - Planner

enum TimelinePlanner {

    /// `transfers` inyectable para tests; default = dataset curado.
    static func resolve(
        stations: [GTFSStation],
        incidents: [Incident],
        reversed: Bool,
        transfers: (String, String) -> [Correspondence] = StationCorrespondences.transfers
    ) -> [TimelineItem] {
        let ordered = reversed ? Array(stations.reversed()) : stations
        guard !ordered.isEmpty else { return [] }

        return ordered.enumerated().map { index, station in
            .station(TimelineStation(
                station: station,
                correspondences: transfers(station.name, station.lineNumber),
                isTerminal: index == 0 || index == ordered.count - 1,
                rowStatus: nil
            ))
        }
    }
}
