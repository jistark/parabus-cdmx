import CoreLocation
import Testing
@testable import ParabusCore

@Suite("MBRouteOrder integrity")
struct MBRouteOrderTests {

    private let allLineNumbers = ["1", "2", "3", "4", "5", "6", "7"]

    @Test("cada nombre del orden resuelve a exactamente una estación de su línea")
    func everyNameResolves() {
        for line in allLineNumbers {
            let universe = GTFSStations.stations(for: line)
            for name in MBRouteOrder.orderedNames[line] ?? [] {
                let matches = universe.filter { $0.name == name }
                #expect(matches.count == 1, "'\(name)' (L\(line)) resolvió \(matches.count) veces")
            }
        }
    }

    @Test("sin duplicados dentro de cada línea")
    func noDuplicates() {
        for line in allLineNumbers {
            let names = MBRouteOrder.orderedNames[line] ?? []
            #expect(Set(names).count == names.count, "L\(line) tiene duplicados")
        }
    }

    @Test("toda línea tiene orden definido y no trivial")
    func everyLineCovered() {
        for line in allLineNumbers {
            #expect((MBRouteOrder.orderedNames[line]?.count ?? 0) >= 20, "L\(line) incompleta")
        }
    }

    @Test("las terminales coinciden con la ruta oficial de GTFSStations.allLines")
    func terminalsMatchRoute() {
        // El feed GTFS no tiene ninguna estación cuyo nombre contenga
        // "Aeropuerto": la terminal aérea de L4 se llama "Terminal 1 AICM".
        // Clave: normalize(endpoint de allLines) → normalize(nombre exacto en
        // GTFSStations.line*Stations). Añadir alias cuando allLines use el nombre
        // comercial de la terminal pero el stop GTFS tenga otro nombre oficial.
        let gtfsAliases: [String: String] = ["aeropuerto t1": "terminal 1 aicm"]
        for meta in GTFSStations.allLines {
            let stations = MBRouteOrder.orderedStations(for: meta.number)
            let endpoints = meta.route.components(separatedBy: " - ")
            guard endpoints.count == 2 else {
                Issue.record("L\(meta.number): route '\(meta.route)' no parseable como 'A - B'")
                continue
            }
            let first = StationNameMatcher.normalize(stations.first?.name ?? "")
            let last = StationNameMatcher.normalize(stations.last?.name ?? "")
            let expectedFirst = StationNameMatcher.normalize(endpoints[0])
            let expectedLast = StationNameMatcher.normalize(endpoints[1])
            #expect(first.contains(gtfsAliases[expectedFirst] ?? expectedFirst),
                    "L\(meta.number): primera ≠ \(endpoints[0])")
            #expect(last.contains(gtfsAliases[expectedLast] ?? expectedLast),
                    "L\(meta.number): última ≠ \(endpoints[1])")
        }
    }

    @Test("estaciones consecutivas a distancia de corredor (50 m – 3.5 km)")
    func adjacencySanity() {
        for line in allLineNumbers {
            let stations = MBRouteOrder.orderedStations(for: line)
            for (a, b) in zip(stations, stations.dropFirst()) {
                let d = CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                #expect(d > 50 && d < 3500,
                        "L\(line): \(a.name) → \(b.name) = \(Int(d)) m")
            }
        }
    }
}
