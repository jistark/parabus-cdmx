import Foundation

/// Maneja la persistencia de datos en App Groups para compartir con widgets
actor CacheManager {

    // MARK: - Constants

    /// Identificador del App Group (configurar en Xcode)
    static let appGroupIdentifier = "group.starkji.parabus-cdmx.app"

    private let fileName = "metrobus_status.json"
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutos

    // MARK: - Cached Data Structure

    struct CachedData: Codable {
        let lines: [LineStatus]
        let cachedAt: Date
        let sourceURL: String

        var isStale: Bool {
            Date().timeIntervalSince(cachedAt) > 300 // 5 min
        }

        var age: TimeInterval {
            Date().timeIntervalSince(cachedAt)
        }

        var ageDescription: String {
            let minutes = Int(age / 60)
            if minutes < 1 {
                return "Ahora"
            } else if minutes == 1 {
                return "Hace 1 minuto"
            } else if minutes < 60 {
                return "Hace \(minutes) minutos"
            } else {
                let hours = minutes / 60
                return hours == 1 ? "Hace 1 hora" : "Hace \(hours) horas"
            }
        }
    }

    // MARK: - File URL

    private var cacheURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    /// Fallback para desarrollo sin App Groups configurado
    private var fallbackURL: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private var fileURL: URL {
        cacheURL ?? fallbackURL
    }

    // MARK: - Public Methods

    /// Guarda el resultado del scraping en cache y actualiza widget
    func save(_ result: ScrapingResult) throws {
        let cached = CachedData(
            lines: result.lines,
            cachedAt: result.scrapedAt,
            sourceURL: result.source.absoluteString
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(cached)
        try data.write(to: fileURL, options: .atomic)

        // Also update widget data
        let widgetLines = result.lines.map { line in
            WidgetLineStatus(
                id: line.lineNumber,
                lineNumber: line.lineNumber,
                status: WidgetServiceStatus(from: line.status),
                affectedStationsCount: line.affectedStations.count,
                incidentCount: line.incidentCount
            )
        }

        let widgetData = WidgetData(
            lines: widgetLines,
            updatedAt: result.scrapedAt,
            isStale: false
        )

        try? WidgetCacheReader.save(widgetData)
    }

    /// Carga datos del cache
    func load() throws -> CachedData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(CachedData.self, from: data)
    }

    /// Carga datos solo si son válidos (no expirados)
    func loadIfValid() throws -> CachedData? {
        guard let cached = try load() else { return nil }

        if cached.age < cacheValiditySeconds {
            return cached
        }
        return nil
    }

    /// Elimina el cache
    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Indica si hay datos en cache (validos o no)
    func hasCachedData() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Widget Integration

    /// Saves scraping result and updates widget data
    func saveAndUpdateWidget(_ result: ScrapingResult) throws {
        // Save main cache
        try save(result)

        // Convert to widget format and save
        let widgetLines = result.lines.map { line in
            WidgetLineStatus(
                id: line.lineNumber,
                lineNumber: line.lineNumber,
                status: WidgetServiceStatus(from: line.status),
                affectedStationsCount: line.affectedStations.count,
                incidentCount: line.incidentCount
            )
        }

        let widgetData = WidgetData(
            lines: widgetLines,
            updatedAt: result.scrapedAt,
            isStale: false
        )

        try WidgetCacheReader.save(widgetData)
    }
}

// MARK: - WidgetServiceStatus Conversion

extension WidgetServiceStatus {
    init(from status: ServiceStatus) {
        switch status {
        case .regular: self = .regular
        case .intervention: self = .intervention
        case .limited: self = .delayed  // Map limited to delayed for widget
        case .delayed: self = .delayed
        case .suspended: self = .suspended
        case .protest: self = .suspended  // Map protest to suspended for widget (urgent)
        case .unknown: self = .unknown
        }
    }
}
