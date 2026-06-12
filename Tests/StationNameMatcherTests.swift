import Testing
@testable import ParabusCore

@Suite("StationNameMatcher")
struct StationNameMatcherTests {

    private var l1: [GTFSStation] { GTFSStations.stations(for: "1") }

    @Test("matchea exacto ignorando mayúsculas y diacríticos")
    func exactInsensitive() {
        #expect(StationNameMatcher.match("chilpancingo", in: l1)?.name == "Chilpancingo")
        #expect(StationNameMatcher.match("FELIX CUEVAS", in: l1)?.name == "Félix Cuevas")
    }

    @Test("tolera sufijos de línea en el nombre canónico")
    func suffixTolerant() {
        #expect(StationNameMatcher.match("Plaza de la República", in: l1)?.name == "Plaza de la República L1")
    }

    @Test("tolera sufijos en el nombre del incidente (dirección inversa)")
    func reverseSuffixTolerant() {
        #expect(StationNameMatcher.match("Indios Verdes L1 dirección sur", in: l1)?.name == "Indios Verdes L1")
    }

    @Test("sin match razonable devuelve nil")
    func noMatch() {
        #expect(!l1.isEmpty, "precondición: datos de L1 cargados")
        #expect(StationNameMatcher.match("Estación Inventada", in: l1) == nil)
    }

    @Test("centinelas de línea completa")
    func sentinels() {
        #expect(StationNameMatcher.isWholeLineSentinel("Línea Completa"))
        #expect(StationNameMatcher.isWholeLineSentinel("toda la linea"))
        #expect(!StationNameMatcher.isWholeLineSentinel("Sonora"))
    }
}
