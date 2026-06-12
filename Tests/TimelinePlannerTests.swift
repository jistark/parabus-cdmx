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
        guard items.count == 7 else { Issue.record("count=\(items.count)"); return }
        guard case .station(let first) = items[0],
              case .station(let last) = items[6],
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

    private func suspension(_ stations: [String], status: ServiceStatus = .suspended) -> Incident {
        Incident(status: status, affectedStations: stations, info: "obras")
    }

    @Test("notación 'A - B' colapsa el rango inclusivo")
    func segmentNotation() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Carlos - Eco"])],
            reversed: false, transfers: Self.noTransfers)
        // Alfa, Bravo, [Carlos+Delta+Eco], Fox, Golf
        guard items.count == 5 else { Issue.record("count=\(items.count)"); return }
        guard case .interruptedSegment(let seg) = items[2] else {
            Issue.record("items[2] no es segmento"); return
        }
        #expect(seg.stations.map(\.name) == ["Carlos", "Delta", "Eco"])
        #expect(seg.boundaryBefore?.name == "Bravo")
        #expect(seg.boundaryAfter?.name == "Fox")
    }

    @Test("lista de nombres contiguos colapsa igual que la notación")
    func nameList() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Carlos", "Delta", "Eco"])],
            reversed: false, transfers: Self.noTransfers)
        guard items.count == 5, case .interruptedSegment(let seg) = items[2] else {
            Issue.record("estructura inesperada"); return
        }
        #expect(seg.stations.count == 3)
    }

    @Test("afectadas no contiguas: un segmento por sub-rango")
    func nonContiguous() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Bravo", "Eco"])],
            reversed: false, transfers: Self.noTransfers)
        // Alfa, [Bravo], Carlos, Delta, [Eco], Fox, Golf
        let segments = items.compactMap { item -> InterruptedSegment? in
            if case .interruptedSegment(let s) = item { return s } else { return nil }
        }
        guard segments.count == 2 else { Issue.record("segments=\(segments.count)"); return }
        #expect(segments[0].stations.map(\.name) == ["Bravo"])
        #expect(segments[1].stations.map(\.name) == ["Eco"])
    }

    @Test("colapso en terminal: sin boundaryBefore")
    func terminalSegment() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Alfa - Bravo"])],
            reversed: false, transfers: Self.noTransfers)
        guard case .interruptedSegment(let seg) = items.first else {
            Issue.record("items[0] no es segmento"); return
        }
        #expect(seg.boundaryBefore == nil)
        #expect(seg.boundaryAfter?.name == "Carlos")
    }

    @Test("línea completa: banner, sin colapso")
    func wholeLine() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Línea Completa"])],
            reversed: false, transfers: Self.noTransfers)
        guard items.count == 8 else { Issue.record("count=\(items.count)"); return }  // banner + 7
        guard case .wholeLineBanner = items[0] else {
            Issue.record("items[0] no es banner"); return
        }
        #expect(!items.dropFirst().contains { if case .interruptedSegment = $0 { return true } else { return false } })
    }

    @Test("sin matches: passthrough silencioso")
    func unmatchedFallback() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Estación Fantasma"])],
            reversed: false, transfers: Self.noTransfers)
        #expect(items.count == 7)
        #expect(items.allSatisfy { if case .station = $0 { return true } else { return false } })
    }

    @Test("retraso no colapsa: marca rowStatus")
    func delayedMarksRows() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic,
            incidents: [suspension(["Carlos"], status: .delayed)],
            reversed: false, transfers: Self.noTransfers)
        guard items.count == 7, case .station(let carlos) = items[2] else {
            Issue.record("estructura inesperada"); return
        }
        #expect(carlos.rowStatus == .delayed)
    }

    @Test("reversed con segmento: fronteras invertidas")
    func reversedSegment() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Carlos - Eco"])],
            reversed: true, transfers: Self.noTransfers)
        // Golf, Fox, [Eco+Delta+Carlos], Bravo, Alfa
        guard items.count == 5, case .interruptedSegment(let seg) = items[2] else {
            Issue.record("estructura inesperada"); return
        }
        #expect(seg.stations.map(\.name) == ["Eco", "Delta", "Carlos"])
        #expect(seg.boundaryBefore?.name == "Fox")
        #expect(seg.boundaryAfter?.name == "Bravo")
    }

    @Test("nombre de estación con ' - ' no se interpreta como rango")
    func dashedStationName() {
        // Línea sintética con una estación cuyo nombre contiene el separador.
        let line = ["Alfa", "Beta - Gamma", "Delta", "Eco"].enumerated().map { i, name in
            GTFSStation(id: "d-\(i)", name: name, lineNumber: "6",
                        latitude: 19.500 - Double(i) * 0.009, longitude: -99.150)
        }
        let items = TimelinePlanner.resolve(
            stations: line, incidents: [suspension(["Beta - Gamma"])],
            reversed: false, transfers: Self.noTransfers)
        // Alfa, [Beta - Gamma], Delta, Eco — UN punto colapsado, no un rango.
        guard items.count == 4, case .interruptedSegment(let seg) = items[1] else {
            Issue.record("estructura inesperada: \(items.map(\.id))"); return
        }
        #expect(seg.stations.map(\.name) == ["Beta - Gamma"])
        #expect(seg.boundaryBefore?.name == "Alfa")
        #expect(seg.boundaryAfter?.name == "Delta")
    }

    @Test("incidentes distintos adyacentes producen segmentos separados")
    func adjacentDistinctIncidents() {
        let a = Incident(status: .suspended, affectedStations: ["Carlos", "Delta"], info: "obras")
        let b = Incident(status: .suspended, affectedStations: ["Eco"], info: "manifestación vecinal")
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [a, b],
            reversed: false, transfers: Self.noTransfers)
        let segments = items.compactMap { item -> InterruptedSegment? in
            if case .interruptedSegment(let s) = item { return s } else { return nil }
        }
        guard segments.count == 2 else { Issue.record("segments=\(segments.count)"); return }
        #expect(segments[0].stations.map(\.name) == ["Carlos", "Delta"])
        #expect(segments[0].incident.info == "obras")
        #expect(segments[1].stations.map(\.name) == ["Eco"])
        #expect(segments[1].incident.info == "manifestación vecinal")
    }

    @Test("protest gana sobre suspended en el mismo índice")
    func protestBeatsSuspended() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic,
            incidents: [suspension(["Carlos"]), suspension(["Carlos"], status: .protest)],
            reversed: false, transfers: Self.noTransfers)
        let segments = items.compactMap { item -> InterruptedSegment? in
            if case .interruptedSegment(let s) = item { return s } else { return nil }
        }
        guard segments.count == 1 else { Issue.record("segments=\(segments.count)"); return }
        #expect(segments[0].incident.status == .protest)
    }

    /// Transfers sintéticos: Bravo→Metro 1; Delta→Metro 9; Fox→Metro 12 y Suburbano.
    /// Carlos→MB 2 (cross-MB NO es ruta de escape; debe ignorarse).
    static func synTransfers(_ name: String, _ line: String) -> [Correspondence] {
        switch name {
        case "Bravo": return [Correspondence(system: .metro, line: "1", brandColorHex: "#F04E98")]
        case "Delta": return [Correspondence(system: .metro, line: "9", brandColorHex: "#512826")]
        case "Fox": return [
            Correspondence(system: .metro, line: "12", brandColorHex: "#B49759"),
            Correspondence(system: .suburbano, line: "1", brandColorHex: "#D2006E"),
        ]
        case "Carlos": return [Correspondence(system: .metrobus, line: "2", brandColorHex: "#C8102E")]
        default: return []
        }
    }

    @Test("alternativas: fronteras primero, luego colapsadas, sin duplicados, máx 3")
    func alternativesPriority() {
        // Colapsa Carlos-Eco → fronteras Bravo y Fox; colapsada Delta.
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Carlos - Eco"])],
            reversed: false, transfers: Self.synTransfers)
        guard items.count == 5, case .interruptedSegment(let seg) = items[2] else {
            Issue.record("estructura inesperada"); return
        }
        guard seg.alternatives.count == 3 else {
            Issue.record("alternatives=\(seg.alternatives)"); return
        }
        // 1º y 2º: transbordos en fronteras (Bravo Metro 1, Fox Metro 12);
        // el walk siempre cierra. Delta (colapsada) queda fuera por el cap,
        // y el MB cross de Carlos nunca califica.
        guard case .transfer(let c0, let s0) = seg.alternatives[0],
              case .transfer(let c1, let s1) = seg.alternatives[1],
              case .walk(let minutes, let from, let to) = seg.alternatives[2] else {
            Issue.record("estructura inesperada: \(seg.alternatives)"); return
        }
        #expect(c0.line == "1" && s0.name == "Bravo")
        #expect(c1.line == "12" && s1.name == "Fox")
        // Bravo→Fox: 4 × 0.009° ≈ 4003 m → 4003/75 = 53.4 min → techo a múltiplo de 5 = 55.
        #expect(minutes == 55)
        #expect(from.name == "Bravo" && to.name == "Fox")
    }

    @Test("sin frontera (tramo en terminal): sin chip de caminata")
    func noWalkAtTerminal() {
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [suspension(["Alfa - Bravo"])],
            reversed: false, transfers: Self.synTransfers)
        guard case .interruptedSegment(let seg) = items.first else {
            Issue.record("items[0] no es segmento"); return
        }
        #expect(!seg.alternatives.contains { if case .walk = $0 { return true } else { return false } })
        // Bravo está colapsada: su Metro 1 sí aplica como escape de colapsada.
        #expect(seg.alternatives.contains {
            if case .transfer(let c, _) = $0 { return c.line == "1" } else { return false }
        })
    }

    @Test("cobertura total por incidentes distintos: el banner toma el más severo")
    func fullCoverageBannerTakesWorst() {
        // A (.suspended) cubre Alfa-Carlos; B (.protest) cubre Delta-Golf → toda la línea.
        let a = Incident(status: .suspended, affectedStations: ["Alfa - Carlos"], info: "obras")
        let b = Incident(status: .protest, affectedStations: ["Delta - Golf"], info: "marcha")
        let items = TimelinePlanner.resolve(
            stations: Self.synthetic, incidents: [a, b],
            reversed: false, transfers: Self.noTransfers)
        guard case .wholeLineBanner(let incident) = items.first else {
            Issue.record("items[0] no es banner: \(items.map(\.id))"); return
        }
        #expect(incident.status == .protest)
        #expect(incident.info == "marcha")
    }

    @Test("caminata mínima de 5 min")
    func walkFloor() {
        // Fronteras pegadas (~222 m) → 3 min → piso 5.
        let tight = ["A", "B", "C"].enumerated().map { i, n in
            GTFSStation(id: "t-\(i)", name: n, lineNumber: "1",
                        latitude: 19.500 - Double(i) * 0.001, longitude: -99.150)
        }
        let items = TimelinePlanner.resolve(
            stations: tight, incidents: [suspension(["B"])],
            reversed: false, transfers: Self.noTransfers)
        guard items.count == 3, case .interruptedSegment(let seg) = items[1] else {
            Issue.record("estructura inesperada"); return
        }
        let walks = seg.alternatives.compactMap { alt -> Int? in
            if case .walk(let m, _, _) = alt { return m } else { return nil }
        }
        guard walks.count == 1 else { Issue.record("walks=\(walks)"); return }
        #expect(walks[0] == 5)
    }
}
