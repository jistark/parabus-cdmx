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
    /// Cubre toda la línea — el planner emite AT MOST ONE banner por resolve
    /// (el incidente de mayor severidad gana). Cuando se emite, las estaciones
    /// individuales siguen presentes en el timeline (no se colapsan).
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

        var banner: Incident?
        var suspendedBy: [Int: Incident] = [:]
        var rowStatus: [Int: ServiceStatus] = [:]

        for incident in incidents where incident.status != .regular {
            // Un centinela de línea completa en CUALQUIER posición de la lista anula el matching por estación.
            let wholeLine = incident.affectedStations.isEmpty
                || incident.affectedStations.contains(where: StationNameMatcher.isWholeLineSentinel)
            if wholeLine {
                if incident.status > (banner?.status ?? .unknown) { banner = incident }
                continue
            }
            let indices = matchedIndices(for: incident, in: ordered)
            guard !indices.isEmpty else { continue }

            if incident.status == .suspended || incident.status == .protest {
                for i in indices where (suspendedBy[i]?.status ?? .unknown) < incident.status {
                    suspendedBy[i] = incident
                }
            } else {
                for i in indices where (rowStatus[i] ?? .unknown) < incident.status {
                    rowStatus[i] = incident.status
                }
            }
        }

        // Si todo el corredor quedó suspendido, degrada a banner: un colapso
        // total no deja timeline que mostrar.
        if suspendedBy.count == ordered.count, let any = suspendedBy.values.first {
            banner = banner.map { $0.status >= any.status ? $0 : any } ?? any
            suspendedBy = [:]
        }

        var items: [TimelineItem] = []
        if let banner { items.append(.wholeLineBanner(banner)) }

        var index = 0
        while index < ordered.count {
            if let incident = suspendedBy[index] {
                var end = index
                while end + 1 < ordered.count, suspendedBy[end + 1] == incident { end += 1 }
                let collapsed = Array(ordered[index...end])
                items.append(.interruptedSegment(InterruptedSegment(
                    stations: collapsed,
                    boundaryBefore: index > 0 ? ordered[index - 1] : nil,
                    boundaryAfter: end + 1 < ordered.count ? ordered[end + 1] : nil,
                    alternatives: [],   // Task 6 deriva alternativas
                    incident: incident
                )))
                index = end + 1
            } else {
                items.append(.station(TimelineStation(
                    station: ordered[index],
                    correspondences: transfers(ordered[index].name, ordered[index].lineNumber),
                    isTerminal: index == 0 || index == ordered.count - 1,
                    rowStatus: rowStatus[index]
                )))
                index += 1
            }
        }
        return items
    }

    /// Índices afectados en el orden actual. Notación "A - B" expande al rango
    /// inclusivo; si un extremo no resuelve, degrada a matching por pieza.
    static func matchedIndices(for incident: Incident, in ordered: [GTFSStation]) -> [Int] {
        var result = Set<Int>()
        for raw in incident.affectedStations where !StationNameMatcher.isWholeLineSentinel(raw) {
            // Nombres de estación pueden contener " - " ("Lindavista - Vallejo", L6):
            // igualdad exacta normalizada primero; solo si no es una estación
            // conocida tratamos el string como notación de rango.
            if let exactIdx = ordered.firstIndex(where: {
                StationNameMatcher.normalize($0.name) == StationNameMatcher.normalize(raw)
            }) {
                result.insert(exactIdx)
                continue
            }
            if raw.contains(" - ") {
                let pieces = raw.components(separatedBy: " - ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if pieces.count == 2,
                   let a = index(of: pieces[0], in: ordered),
                   let b = index(of: pieces[1], in: ordered) {
                    result.formUnion(min(a, b)...max(a, b))
                } else {
                    for piece in pieces {
                        if let i = index(of: piece, in: ordered) { result.insert(i) }
                    }
                }
            } else if let i = index(of: raw, in: ordered) {
                result.insert(i)
            }
        }
        return result.sorted()
    }

    private static func index(of name: String, in ordered: [GTFSStation]) -> Int? {
        guard let match = StationNameMatcher.match(name, in: ordered) else { return nil }
        return ordered.firstIndex(of: match)
    }
}
