import Foundation

/// Fuzzy matching compartido entre `AffectedStationsCard` y `TimelinePlanner`.
/// Diacritic/case-insensitive, contains en ambas direcciones — el scraper dice
/// "Plaza de la República", el GTFS dice "Plaza de la República L1" (y viceversa).
enum StationNameMatcher {

    static func normalize(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isWholeLineSentinel(_ name: String) -> Bool {
        let n = normalize(name)
        return n.contains("linea completa") || n.contains("toda la linea")
    }

    static func match(_ name: String, in stations: [GTFSStation]) -> GTFSStation? {
        let normalized = normalize(name)
        guard !normalized.isEmpty else { return nil }
        // Pase exacto primero: evita que "Reforma" capture "Reforma L7" cuando
        // existe un "Reforma L1" exacto-con-sufijo más adelante en la lista.
        if let exact = stations.first(where: { normalize($0.name) == normalized }) {
            return exact
        }
        return stations.first { station in
            let canonical = normalize(station.name)
            return canonical.contains(normalized) || normalized.contains(canonical)
        }
    }
}
