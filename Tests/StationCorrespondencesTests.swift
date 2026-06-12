import Testing
@testable import ParabusCore

@Suite("StationCorrespondences integrity")
struct StationCorrespondencesTests {

    @Test("cada entrada referencia una estación real de su línea")
    func entriesResolve() {
        for (key, _) in StationCorrespondences.table {
            let universe = GTFSStations.stations(for: key.lineNumber)
            #expect(
                StationNameMatcher.match(key.stationName, in: universe) != nil,
                "'\(key.stationName)' no existe en L\(key.lineNumber)"
            )
        }
    }

    @Test("colores hex parseables (#RRGGBB)")
    func hexColorsValid() {
        let hexSet = Set("0123456789ABCDEFabcdef")
        for (_, transfers) in StationCorrespondences.table {
            for t in transfers {
                #expect(t.brandColorHex.hasPrefix("#") && t.brandColorHex.count == 7
                        && t.brandColorHex.dropFirst().allSatisfy(hexSet.contains),
                        "hex inválido: \(t.brandColorHex)")
            }
        }
    }

    @Test("lookup tolera diacríticos y sufijos")
    func lookupIsFuzzy() {
        let insurgentes = StationCorrespondences.transfers(stationName: "Insurgentes", lineNumber: "1")
        #expect(insurgentes.contains { $0.system == .metro && $0.line == "1" })

        let buenavista = StationCorrespondences.transfers(stationName: "Buenavista L1", lineNumber: "1")
        #expect(buenavista.contains { $0.system == .suburbano })
        #expect(buenavista.contains { $0.system == .metro && $0.line == "B" })
    }

    @Test("estación sin transbordos devuelve vacío")
    func emptyForUnknown() {
        #expect(StationCorrespondences.transfers(stationName: "Sonora", lineNumber: "1").isEmpty)
    }

    @Test("referencias MB cruzadas apuntan a líneas existentes")
    func crossMBReferencesExist() {
        let validLines = Set(GTFSStations.allLines.map { $0.number })
        for (_, correspondences) in StationCorrespondences.table {
            for c in correspondences where c.system == .metrobus {
                #expect(validLines.contains(c.line),
                        "línea MB '\(c.line)' no existe en GTFSStations")
            }
        }
    }
}
