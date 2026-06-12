import Foundation

// MARK: - Correspondencias curadas (Metro / Suburbano / MB / Cablebús)
//
// Dataset estático que alimenta (a) los badges de transbordo por fila en el
// timeline de estación y (b) los chips de "ruta de escape" en la tarjeta de
// interrupción. Claves por nombre EXACTO de `GTFSStations` + línea MB dueña
// de la entrada; lookup con fallback fuzzy vía `StationNameMatcher`.
// Verificado contra el GTFS estático de CDMX (datos.cdmx.gob.mx, feb 2026):
// cada correspondencia Metro/Suburbano/Cablebús queda a distancia de
// transbordo del paradero real, y cada correspondencia cruzada MB referencia
// una línea con plataforma homónima/cercana. Colores solo para display.

enum TransitSystem: String, Codable, Hashable {
    case metro, metrobus, suburbano, cablebus, trolebus // reservado: sin datos de transbordo aún

    var displayName: String {
        switch self {
        case .metro: return "Metro"
        case .metrobus: return "Metrobús"
        case .suburbano: return "Suburbano"
        case .cablebus: return "Cablebús"
        case .trolebus: return "Trolebús"
        }
    }
}

struct Correspondence: Hashable, Codable {
    let system: TransitSystem
    let line: String
    let brandColorHex: String
}

enum StationCorrespondences {

    struct Key: Hashable {
        let stationName: String   // nombre EXACTO de GTFSStations
        let lineNumber: String    // línea MB dueña de la entrada
    }

    /// Índice [línea: nombre-normalizado → correspondencias], construido una
    /// vez — las vistas consultan por fila en cada render.
    private static let normalizedIndex: [String: [String: [Correspondence]]] = {
        var result: [String: [String: [Correspondence]]] = [:]
        for (key, correspondences) in table {
            let normalized = StationNameMatcher.normalize(key.stationName)
            result[key.lineNumber, default: [:]][normalized] = correspondences
        }
        return result
    }()

    static func transfers(stationName: String, lineNumber: String) -> [Correspondence] {
        if let exact = table[Key(stationName: stationName, lineNumber: lineNumber)] {
            return exact
        }
        // Tolerancia a sufijos/diacríticos sin escaneo lineal: match del
        // matcher solo si el índice normalizado no acierta directo.
        let byName = normalizedIndex[lineNumber] ?? [:]
        if let hit = byName[StationNameMatcher.normalize(stationName)] {
            return hit
        }
        guard let canonical = StationNameMatcher.match(stationName, in: GTFSStations.stations(for: lineNumber)) else { return [] }
        return byName[StationNameMatcher.normalize(canonical.name)] ?? []
    }

    // MARK: - Colores de marca

    private static let metroColors: [String: String] = [
        "1": "#F04E98", "2": "#005EB8", "3": "#AF9800", "4": "#6BBBAE",
        "5": "#FDD000", "6": "#DA291C", "7": "#E87722", "8": "#009A44",
        "9": "#512826", "12": "#B49759", "A": "#981D97", "B": "#3C8B40",
    ]
    private static func metro(_ line: String) -> Correspondence {
        Correspondence(system: .metro, line: line, brandColorHex: metroColors[line] ?? "#8E8E93")
    }
    private static func mb(_ line: String) -> Correspondence {
        Correspondence(system: .metrobus, line: line, brandColorHex: "#C8102E") // PANTONE 186 C — debe coincidir con BrandColors.metrobusRed (DesignTokens.swift)
    }
    private static let suburbano = Correspondence(system: .suburbano, line: "1", brandColorHex: "#D2006E")
    private static let cablebus1 = Correspondence(system: .cablebus, line: "1", brandColorHex: "#0093D0") // TODO: Cablebús L2 (Tepito) y L3 (Tláhuac) — transbordos con MB L5 pendientes de curar

    // MARK: - Tabla curada
    //
    // Algunas claves referencian plataformas fuera del orden ida de
    // `MBRouteOrder` (vuelta-only o Ruta Norte L4): De los Misterios L6,
    // Hospital Infantil La Villa L6, Gustavo A. Madero L7, Hospital Infantil
    // La Villa L7, Hidalgo L4, Moctezuma L4, Archivo General de la Nación L4.
    // Son inofensivas si no se consultan — el dataset se indexa por nombre.

    static let table: [Key: [Correspondence]] = [
        // Línea 1 · Indios Verdes - El Caminero
        Key(stationName: "Indios Verdes L1", lineNumber: "1"): [metro("3"), cablebus1, mb("7")],
        Key(stationName: "Dep. 18 Mzo. L1", lineNumber: "1"): [metro("3"), metro("6"), mb("6")],
        Key(stationName: "Potrero", lineNumber: "1"): [metro("3")],
        Key(stationName: "La Raza L1", lineNumber: "1"): [metro("3"), metro("5"), mb("3")],
        Key(stationName: "Buenavista L1", lineNumber: "1"): [metro("B"), suburbano, mb("3"), mb("4")],
        Key(stationName: "Revolución", lineNumber: "1"): [metro("2")],
        Key(stationName: "Plaza de la República L1", lineNumber: "1"): [mb("4")],
        Key(stationName: "Reforma L1", lineNumber: "1"): [mb("7")],
        Key(stationName: "Hamburgo L1", lineNumber: "1"): [mb("7")],
        Key(stationName: "Insurgentes", lineNumber: "1"): [metro("1")],
        Key(stationName: "Chilpancingo", lineNumber: "1"): [metro("9")],
        Key(stationName: "Nuevo León L1", lineNumber: "1"): [mb("2")],
        Key(stationName: "La Piedad", lineNumber: "1"): [mb("2")],
        Key(stationName: "Félix Cuevas", lineNumber: "1"): [metro("12")],

        // Línea 2 · Tacubaya - Tepalcates
        Key(stationName: "Tacubaya", lineNumber: "2"): [metro("1"), metro("7"), metro("9")],
        Key(stationName: "Patriotismo", lineNumber: "2"): [metro("9")],
        Key(stationName: "Nuevo León L2", lineNumber: "2"): [mb("1")],
        Key(stationName: "Etiopía L2", lineNumber: "2"): [metro("3"), mb("3")],
        Key(stationName: "Metro Coyuya L2", lineNumber: "2"): [metro("8")],
        Key(stationName: "Tepalcates", lineNumber: "2"): [metro("A")],

        // Línea 3 · Tenayuca - Pueblo Sta. Cruz Atoyac
        Key(stationName: "Hospital la Raza", lineNumber: "3"): [metro("3"), metro("5")],
        Key(stationName: "La Raza L3", lineNumber: "3"): [metro("3"), metro("5"), mb("1")],
        Key(stationName: "Tlatelolco", lineNumber: "3"): [metro("3")],
        Key(stationName: "Guerrero", lineNumber: "3"): [metro("3"), metro("B")],
        Key(stationName: "Buenavista L3 Norte", lineNumber: "3"): [metro("B"), suburbano, mb("1"), mb("4")],
        Key(stationName: "Buenavista L3 Sur", lineNumber: "3"): [metro("B"), suburbano, mb("1"), mb("4")],
        Key(stationName: "Hidalgo L3", lineNumber: "3"): [metro("2"), metro("3"), mb("4"), mb("7")],
        Key(stationName: "Juárez L3", lineNumber: "3"): [metro("3")],
        Key(stationName: "Balderas", lineNumber: "3"): [metro("1"), metro("3")],
        Key(stationName: "Cuauhtémoc", lineNumber: "3"): [metro("1")],
        Key(stationName: "Hospital General", lineNumber: "3"): [metro("3")],
        Key(stationName: "Centro Médico", lineNumber: "3"): [metro("3"), metro("9")],
        Key(stationName: "Etiopía L3", lineNumber: "3"): [metro("3"), mb("2")],
        Key(stationName: "Montevideo L3", lineNumber: "3"): [mb("6")],

        // Línea 4 · Buenavista - Aeropuerto T1
        Key(stationName: "Buenavista L4", lineNumber: "4"): [metro("B"), suburbano, mb("1"), mb("3")],
        Key(stationName: "Plaza de la República L4", lineNumber: "4"): [mb("1")],
        Key(stationName: "Hidalgo L4", lineNumber: "4"): [metro("2"), metro("3"), mb("3"), mb("7")],
        Key(stationName: "Bellas Artes", lineNumber: "4"): [metro("2"), metro("8")],
        Key(stationName: "Juárez L4", lineNumber: "4"): [metro("3")],
        Key(stationName: "Isabel la Católica", lineNumber: "4"): [metro("1")],
        Key(stationName: "Pino Suárez", lineNumber: "4"): [metro("1"), metro("2")],
        Key(stationName: "La Merced", lineNumber: "4"): [metro("1")],
        Key(stationName: "Morelos", lineNumber: "4"): [metro("4"), metro("B")],
        Key(stationName: "Moctezuma L4", lineNumber: "4"): [mb("5")],
        Key(stationName: "Archivo General de la Nación L4", lineNumber: "4"): [mb("5")],
        Key(stationName: "San Lázaro L4 Ote", lineNumber: "4"): [metro("1"), metro("B"), mb("5")],
        Key(stationName: "San Lázaro L4 Pte", lineNumber: "4"): [metro("1"), metro("B"), mb("5")],
        Key(stationName: "Pantitlán", lineNumber: "4"): [metro("1"), metro("5"), metro("9"), metro("A")],

        // Línea 5 · Río de los Remedios - Preparatoria 1
        Key(stationName: "San Juan de Aragón L5", lineNumber: "5"): [mb("6")],
        Key(stationName: "Archivo General de la Nación L5", lineNumber: "5"): [mb("4")],
        Key(stationName: "San Lázaro Norte L5", lineNumber: "5"): [metro("1"), metro("B"), mb("4")],
        Key(stationName: "San Lázaro Sur L5", lineNumber: "5"): [metro("1"), metro("B"), mb("4")],
        Key(stationName: "Moctezuma L5", lineNumber: "5"): [mb("4")],
        Key(stationName: "Mixiuhca", lineNumber: "5"): [metro("9")],
        Key(stationName: "Metro Coyuya L5", lineNumber: "5"): [metro("8"), mb("2")],
        Key(stationName: "Apatlaco", lineNumber: "5"): [metro("8")],
        Key(stationName: "Escuadrón 201", lineNumber: "5"): [metro("8")],

        // Línea 6 · El Rosario - Villa de Aragón
        Key(stationName: "El Rosario", lineNumber: "6"): [metro("6"), metro("7")],
        Key(stationName: "Instituto del Petróleo", lineNumber: "6"): [metro("5"), metro("6")],
        Key(stationName: "Lindavista - Vallejo", lineNumber: "6"): [metro("6")],
        Key(stationName: "Montevideo L6", lineNumber: "6"): [mb("3")],
        Key(stationName: "Dep. 18 Mzo. L6", lineNumber: "6"): [metro("3"), metro("6"), mb("1")],
        Key(stationName: "De los Misterios L6", lineNumber: "6"): [mb("7")],
        Key(stationName: "La Villa", lineNumber: "6"): [metro("6")],
        Key(stationName: "Hospital Infantil La Villa L6", lineNumber: "6"): [mb("7")],
        Key(stationName: "Gustavo A. Madero L6", lineNumber: "6"): [mb("7")],
        Key(stationName: "Martín Carrera", lineNumber: "6"): [metro("4"), metro("6")],
        Key(stationName: "San Juan de Aragón L6", lineNumber: "6"): [mb("5")],
        Key(stationName: "Villa de Aragón", lineNumber: "6"): [metro("B")],

        // Línea 7 · Indios Verdes - Campo Marte
        Key(stationName: "Indios Verdes L7", lineNumber: "7"): [metro("3"), cablebus1, mb("1")],
        Key(stationName: "De los Misterios L7", lineNumber: "7"): [mb("6")],
        Key(stationName: "Hospital Infantil La Villa L7", lineNumber: "7"): [mb("6")],
        Key(stationName: "Gustavo A. Madero L7", lineNumber: "7"): [mb("6")],
        Key(stationName: "Garibaldi", lineNumber: "7"): [metro("8"), metro("B")],
        Key(stationName: "Hidalgo L7", lineNumber: "7"): [metro("2"), metro("3"), mb("3"), mb("4")],
        Key(stationName: "Reforma L7", lineNumber: "7"): [mb("1")],
        Key(stationName: "Hamburgo L7", lineNumber: "7"): [mb("1")],
        Key(stationName: "Chapultepec", lineNumber: "7"): [metro("1")],
        Key(stationName: "Auditorio", lineNumber: "7"): [metro("7")],
    ]
}
