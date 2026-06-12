import CoreLocation
import Testing
@testable import ParabusCore

@Suite("TimelinePlanner")
struct TimelinePlannerTests {

    /// Línea sintética: 7 estaciones N→S separadas ~1 km (0.009° lat).
    /// El planner no exige estaciones reales — esto aísla los tests de los
    /// datasets curados.
    static let synthetic: [GTFSStation] = ["Alfa", "Bravo", "Carlos", "Delta", "Eco", "Fox", "Golf"]
        .enumerated().map { i, name in
            GTFSStation(id: "syn-\(i)", name: name, lineNumber: "1",
                        latitude: 19.500 - Double(i) * 0.009, longitude: -99.150)
        }

    static func noTransfers(_: String, _: String) -> [Correspondence] { [] }

    @Test("sin incidentes: todas .station en orden, terminales marcadas")
    func passthrough() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [], reversed: false,
            transfers: Self.noTransfers)
        #expect(items.count == 7)
        guard case .station(let first) = items[0], case .station(let last) = items[6],
              case .station(let mid) = items[3] else {
            Issue.record("tipo de item inesperado"); return
        }
        #expect(first.station.name == "Alfa" && first.isTerminal)
        #expect(last.station.name == "Golf" && last.isTerminal)
        #expect(mid.station.name == "Delta" && !mid.isTerminal)
    }

    @Test("reversed invierte orden y terminales")
    func reversedOrder() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [], reversed: true,
            transfers: Self.noTransfers)
        guard case .station(let first) = items[0] else { Issue.record("no station"); return }
        #expect(first.station.name == "Golf" && first.isTerminal)
    }

    @Test("estaciones vacías: timeline vacío")
    func emptyStations() {
        #expect(TimelinePlanner.resolve(stations: [], incidents: [], reversed: false,
                                        transfers: Self.noTransfers).isEmpty)
    }
}
