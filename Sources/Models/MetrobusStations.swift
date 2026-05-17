import Foundation

// MARK: - Metrobus Stations

/// Static data for all Metrobus stations organized by line
enum MetrobusStations {
    /// All stations for a given line number
    static func stations(for lineNumber: String) -> [CommuteStation] {
        switch lineNumber {
        case "1": return line1Stations
        case "2": return line2Stations
        case "3": return line3Stations
        case "4": return line4Stations
        case "5": return line5Stations
        case "6": return line6Stations
        case "7": return line7Stations
        default: return []
        }
    }

    /// All lines with their info
    static let allLines: [(number: String, name: String, route: String)] = [
        ("1", "Linea 1", "Indios Verdes - El Caminero"),
        ("2", "Linea 2", "Tacubaya - Tepalcates"),
        ("3", "Linea 3", "Tenayuca - Etiopía"),
        ("4", "Linea 4", "Buenavista - Aeropuerto T1"),
        ("5", "Linea 5", "Politecnico - Rio de los Remedios"),
        ("6", "Linea 6", "El Rosario - Villa de Aragon"),
        ("7", "Linea 7", "Indios Verdes - Campo Marte")
    ]

    /// Search stations across all lines
    static func search(_ query: String) -> [CommuteStation] {
        guard !query.isEmpty else { return [] }

        let normalizedQuery = query.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        var results: [CommuteStation] = []
        for lineNumber in ["1", "2", "3", "4", "5", "6", "7"] {
            let lineStations = stations(for: lineNumber)
            let matches = lineStations.filter { station in
                let normalizedName = station.name.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                return normalizedName.contains(normalizedQuery)
            }
            results.append(contentsOf: matches)
        }
        return results
    }

    // MARK: - Line 1: Insurgentes (Indios Verdes - El Caminero)

    static let line1Stations: [CommuteStation] = [
        CommuteStation(id: "1_00", name: "Indios Verdes", lineNumber: "1"),
        CommuteStation(id: "1_01", name: "Potrero", lineNumber: "1"),
        CommuteStation(id: "1_02", name: "La Raza", lineNumber: "1"),
        CommuteStation(id: "1_03", name: "Autobuses del Norte", lineNumber: "1"),
        CommuteStation(id: "1_04", name: "Instituto del Petroleo", lineNumber: "1"),
        CommuteStation(id: "1_05", name: "Politecnico", lineNumber: "1"),
        CommuteStation(id: "1_06", name: "Eje 5 Norte", lineNumber: "1"),
        CommuteStation(id: "1_07", name: "Misterios", lineNumber: "1"),
        CommuteStation(id: "1_08", name: "Hospital Infantil", lineNumber: "1"),
        CommuteStation(id: "1_09", name: "Buenavista", lineNumber: "1"),
        CommuteStation(id: "1_10", name: "Revolucion", lineNumber: "1"),
        CommuteStation(id: "1_11", name: "San Cosme", lineNumber: "1"),
        CommuteStation(id: "1_12", name: "Hamburgo", lineNumber: "1"),
        CommuteStation(id: "1_13", name: "Reforma", lineNumber: "1"),
        CommuteStation(id: "1_14", name: "Insurgentes", lineNumber: "1"),
        CommuteStation(id: "1_15", name: "Durango", lineNumber: "1"),
        CommuteStation(id: "1_16", name: "Alvaro Obregon", lineNumber: "1"),
        CommuteStation(id: "1_17", name: "Sonora", lineNumber: "1"),
        CommuteStation(id: "1_18", name: "Campeche", lineNumber: "1"),
        CommuteStation(id: "1_19", name: "Chilpancingo", lineNumber: "1"),
        CommuteStation(id: "1_20", name: "La Joya", lineNumber: "1"),
        CommuteStation(id: "1_21", name: "Ciudad de los Deportes", lineNumber: "1"),
        CommuteStation(id: "1_22", name: "Parque Hundido", lineNumber: "1"),
        CommuteStation(id: "1_23", name: "Felix Cuevas", lineNumber: "1"),
        CommuteStation(id: "1_24", name: "Rio Churubusco", lineNumber: "1"),
        CommuteStation(id: "1_25", name: "Teatro Insurgentes", lineNumber: "1"),
        CommuteStation(id: "1_26", name: "Poliforum", lineNumber: "1"),
        CommuteStation(id: "1_27", name: "Perisur", lineNumber: "1"),
        CommuteStation(id: "1_28", name: "Villa Olimpica", lineNumber: "1"),
        CommuteStation(id: "1_29", name: "Jose Maria Velasco", lineNumber: "1"),
        CommuteStation(id: "1_30", name: "Corregidora", lineNumber: "1"),
        CommuteStation(id: "1_31", name: "Doctor Galvez", lineNumber: "1"),
        CommuteStation(id: "1_32", name: "El Caminero", lineNumber: "1"),
    ]

    // MARK: - Line 2: Eje 4 Sur (Tacubaya - Tepalcates)

    static let line2Stations: [CommuteStation] = [
        CommuteStation(id: "2_00", name: "Tacubaya", lineNumber: "2"),
        CommuteStation(id: "2_01", name: "Antonio Maceo", lineNumber: "2"),
        CommuteStation(id: "2_02", name: "Nuevo Leon", lineNumber: "2"),
        CommuteStation(id: "2_03", name: "Escandón", lineNumber: "2"),
        CommuteStation(id: "2_04", name: "Patriotismo", lineNumber: "2"),
        CommuteStation(id: "2_05", name: "Chilpancingo", lineNumber: "2"),
        CommuteStation(id: "2_06", name: "Etiopía", lineNumber: "2"),
        CommuteStation(id: "2_07", name: "Centro SCOP", lineNumber: "2"),
        CommuteStation(id: "2_08", name: "Parque Delta", lineNumber: "2"),
        CommuteStation(id: "2_09", name: "Ninos Heroes", lineNumber: "2"),
        CommuteStation(id: "2_10", name: "Doctor Vertiz", lineNumber: "2"),
        CommuteStation(id: "2_11", name: "Obrera", lineNumber: "2"),
        CommuteStation(id: "2_12", name: "Chabacano", lineNumber: "2"),
        CommuteStation(id: "2_13", name: "Rojo Gomez", lineNumber: "2"),
        CommuteStation(id: "2_14", name: "Las Torres", lineNumber: "2"),
        CommuteStation(id: "2_15", name: "San Antonio Abad", lineNumber: "2"),
        CommuteStation(id: "2_16", name: "Iztacalco", lineNumber: "2"),
        CommuteStation(id: "2_17", name: "La Viga", lineNumber: "2"),
        CommuteStation(id: "2_18", name: "Santa Anita", lineNumber: "2"),
        CommuteStation(id: "2_19", name: "Jamaica", lineNumber: "2"),
        CommuteStation(id: "2_20", name: "Eje 3 Oriente", lineNumber: "2"),
        CommuteStation(id: "2_21", name: "Canal de San Juan", lineNumber: "2"),
        CommuteStation(id: "2_22", name: "Tepalcates", lineNumber: "2"),
    ]

    // MARK: - Line 3: Eje 1 Poniente (Tenayuca - Etiopía)

    static let line3Stations: [CommuteStation] = [
        CommuteStation(id: "3_00", name: "Tenayuca", lineNumber: "3"),
        CommuteStation(id: "3_01", name: "San Jose de la Escalera", lineNumber: "3"),
        CommuteStation(id: "3_02", name: "Acueducto de Tenayuca", lineNumber: "3"),
        CommuteStation(id: "3_03", name: "Hospital Magdalena", lineNumber: "3"),
        CommuteStation(id: "3_04", name: "Manuel González", lineNumber: "3"),
        CommuteStation(id: "3_05", name: "Coltongo", lineNumber: "3"),
        CommuteStation(id: "3_06", name: "Poniente 128", lineNumber: "3"),
        CommuteStation(id: "3_07", name: "Poniente 112", lineNumber: "3"),
        CommuteStation(id: "3_08", name: "Poniente 100", lineNumber: "3"),
        CommuteStation(id: "3_09", name: "Poniente 82", lineNumber: "3"),
        CommuteStation(id: "3_10", name: "Refineria", lineNumber: "3"),
        CommuteStation(id: "3_11", name: "La Raza", lineNumber: "3"),
        CommuteStation(id: "3_12", name: "Tlatelolco", lineNumber: "3"),
        CommuteStation(id: "3_13", name: "Hidalgo", lineNumber: "3"),
        CommuteStation(id: "3_14", name: "Juarez", lineNumber: "3"),
        CommuteStation(id: "3_15", name: "Balderas", lineNumber: "3"),
        CommuteStation(id: "3_16", name: "Doctor Vertiz", lineNumber: "3"),
        CommuteStation(id: "3_17", name: "Etiopia", lineNumber: "3"),
    ]

    // MARK: - Line 4: Buenavista - Aeropuerto T1

    static let line4Stations: [CommuteStation] = [
        CommuteStation(id: "4_00", name: "Buenavista", lineNumber: "4"),
        CommuteStation(id: "4_01", name: "Nonoalco-Tlatelolco", lineNumber: "4"),
        CommuteStation(id: "4_02", name: "Ricardo Flores Magon", lineNumber: "4"),
        CommuteStation(id: "4_03", name: "San Simon", lineNumber: "4"),
        CommuteStation(id: "4_04", name: "Canal del Norte", lineNumber: "4"),
        CommuteStation(id: "4_05", name: "Morelos", lineNumber: "4"),
        CommuteStation(id: "4_06", name: "Candelaria", lineNumber: "4"),
        CommuteStation(id: "4_07", name: "San Lazaro", lineNumber: "4"),
        CommuteStation(id: "4_08", name: "La Viga", lineNumber: "4"),
        CommuteStation(id: "4_09", name: "Jamaica", lineNumber: "4"),
        CommuteStation(id: "4_10", name: "Moctezuma", lineNumber: "4"),
        CommuteStation(id: "4_11", name: "Circuito Interior", lineNumber: "4"),
        CommuteStation(id: "4_12", name: "Deportivo Oceania", lineNumber: "4"),
        CommuteStation(id: "4_13", name: "Hangares", lineNumber: "4"),
        CommuteStation(id: "4_14", name: "Pantitlan", lineNumber: "4"),
        CommuteStation(id: "4_15", name: "Alameda Oriente", lineNumber: "4"),
        CommuteStation(id: "4_16", name: "Terminal Aerea T1", lineNumber: "4"),
    ]

    // MARK: - Line 5: Eje 3 Oriente (Politecnico - Rio de los Remedios)

    static let line5Stations: [CommuteStation] = [
        CommuteStation(id: "5_00", name: "Politecnico", lineNumber: "5"),
        CommuteStation(id: "5_01", name: "Instituto del Petroleo", lineNumber: "5"),
        CommuteStation(id: "5_02", name: "Montevideo", lineNumber: "5"),
        CommuteStation(id: "5_03", name: "Talismán", lineNumber: "5"),
        CommuteStation(id: "5_04", name: "Congreso de la Union", lineNumber: "5"),
        CommuteStation(id: "5_05", name: "Rio Consulado", lineNumber: "5"),
        CommuteStation(id: "5_06", name: "5 de Febrero", lineNumber: "5"),
        CommuteStation(id: "5_07", name: "Oceania", lineNumber: "5"),
        CommuteStation(id: "5_08", name: "Aragon", lineNumber: "5"),
        CommuteStation(id: "5_09", name: "Deportivo Oceanía", lineNumber: "5"),
        CommuteStation(id: "5_10", name: "Cuchilla del Tesoro", lineNumber: "5"),
        CommuteStation(id: "5_11", name: "Rio Guadalupe", lineNumber: "5"),
        CommuteStation(id: "5_12", name: "San Juan de Aragon", lineNumber: "5"),
        CommuteStation(id: "5_13", name: "Rio de los Remedios", lineNumber: "5"),
    ]

    // MARK: - Line 6: El Rosario - Villa de Aragon

    static let line6Stations: [CommuteStation] = [
        CommuteStation(id: "6_00", name: "El Rosario", lineNumber: "6"),
        CommuteStation(id: "6_01", name: "Pradera", lineNumber: "6"),
        CommuteStation(id: "6_02", name: "San Jose de la Escalera", lineNumber: "6"),
        CommuteStation(id: "6_03", name: "Poniente 140", lineNumber: "6"),
        CommuteStation(id: "6_04", name: "Buenavista", lineNumber: "6"),
        CommuteStation(id: "6_05", name: "La Raza", lineNumber: "6"),
        CommuteStation(id: "6_06", name: "San Antonio Tomatlan", lineNumber: "6"),
        CommuteStation(id: "6_07", name: "Deportivo 18 de Marzo", lineNumber: "6"),
        CommuteStation(id: "6_08", name: "Rio de los Remedios", lineNumber: "6"),
        CommuteStation(id: "6_09", name: "Muzquiz", lineNumber: "6"),
        CommuteStation(id: "6_10", name: "Villa de Aragon", lineNumber: "6"),
    ]

    // MARK: - Line 7: Indios Verdes - Campo Marte

    static let line7Stations: [CommuteStation] = [
        CommuteStation(id: "7_00", name: "Indios Verdes", lineNumber: "7"),
        CommuteStation(id: "7_01", name: "La Raza", lineNumber: "7"),
        CommuteStation(id: "7_02", name: "Autobuses del Norte", lineNumber: "7"),
        CommuteStation(id: "7_03", name: "Lindavista", lineNumber: "7"),
        CommuteStation(id: "7_04", name: "Deportivo 18 de Marzo", lineNumber: "7"),
        CommuteStation(id: "7_05", name: "Potrero", lineNumber: "7"),
        CommuteStation(id: "7_06", name: "Buenavista", lineNumber: "7"),
        CommuteStation(id: "7_07", name: "Sullivan", lineNumber: "7"),
        CommuteStation(id: "7_08", name: "Reforma", lineNumber: "7"),
        CommuteStation(id: "7_09", name: "Hipodromo", lineNumber: "7"),
        CommuteStation(id: "7_10", name: "Auditorio", lineNumber: "7"),
        CommuteStation(id: "7_11", name: "Campo Marte", lineNumber: "7"),
    ]
}
