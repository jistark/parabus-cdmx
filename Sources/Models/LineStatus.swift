import Foundation

/// Estado de servicio de una linea de transporte
enum ServiceStatus: String, Codable, CaseIterable, Comparable {
    case regular = "Servicio Regular"
    case intervention = "Intervencion en la estacion"
    case limited = "Servicio Limitado"
    case delayed = "Servicio con Retraso"
    case suspended = "Servicio Suspendido"
    case protest = "Manifestacion"
    case unknown = "Desconocido"

    init(from text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Severity-descending order. The `.regular` check has to come AFTER
        // every abnormal status because operators sometimes write compound
        // phrases ("servicio limitado, regreso a regular") and a `regular`-
        // first chain would mis-tag those as healthy.
        if normalized.contains("manifestacion") || normalized.contains("manifestación") ||
                  normalized.contains("marcha") || normalized.contains("bloqueo") {
            self = .protest
        } else if normalized.contains("suspendido") || normalized.contains("sin servicio") {
            self = .suspended
        } else if normalized.contains("retraso") ||
                  normalized.contains("obstrucción") || normalized.contains("obstruccion") ||
                  normalized.contains("congestionamiento") {
            self = .delayed
        } else if normalized.contains("limitado") {
            self = .limited
        } else if normalized.contains("intervencion") || normalized.contains("intervención") {
            self = .intervention
        } else if normalized.contains("regular") {
            self = .regular
        } else {
            self = .unknown
        }
    }

    var isNormal: Bool {
        self == .regular
    }

    /// True if this status should trigger an urgent notification
    var isUrgent: Bool {
        self == .protest
    }

    var emoji: String {
        switch self {
        case .regular: return "✅"
        case .intervention: return "🔧"
        case .limited: return "⚠️"
        case .delayed: return "⏳"
        case .suspended: return "🚫"
        case .protest: return "🚨"
        case .unknown: return "❓"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .regular: return "checkmark.circle.fill"
        case .intervention: return "wrench.and.screwdriver.fill"
        case .limited: return "arrow.left.arrow.right"
        case .delayed: return "clock.badge.exclamationmark"
        case .suspended: return "exclamationmark.octagon.fill"
        case .protest: return "megaphone.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    /// Severity for comparison (higher = worse)
    /// Priority order: protest > suspended > delayed > limited > intervention > unknown > regular
    var severity: Int {
        switch self {
        case .regular: return 0
        case .unknown: return 1
        case .intervention: return 2  // Scheduled maintenance
        case .limited: return 3       // Limited service between stations
        case .delayed: return 4       // Real-time delays
        case .suspended: return 5     // Service suspended
        case .protest: return 6       // Protest/manifestation (highest - urgent)
        }
    }

    static func < (lhs: ServiceStatus, rhs: ServiceStatus) -> Bool {
        lhs.severity < rhs.severity
    }
}

/// Tipo de transporte
enum TransportType: String, Codable {
    case metrobus = "mb"
    case metro = "metro"

    var displayName: String {
        switch self {
        case .metrobus: return "Metrobus"
        case .metro: return "Metro"
        }
    }
}

/// Representa un incidente individual en una linea
struct Incident: Codable, Hashable {
    let status: ServiceStatus
    let affectedStations: [String]
    let info: String?

    init(status: ServiceStatus, affectedStations: [String] = [], info: String? = nil) {
        self.status = status
        self.affectedStations = affectedStations
        self.info = info
    }
}

/// Representa el estado de una linea de transporte (puede tener multiples incidentes)
struct LineStatus: Identifiable, Codable, Hashable {
    /// Identity derived from the natural key (line number). Was `let id: UUID`
    /// regenerated on every init, which broke SwiftUI animation/sheet identity
    /// because `APITransitDataProvider.convertToLineStatus` built fresh
    /// instances on every fetch — every line appeared to be a brand-new entity
    /// each refresh, churning the diff in `ForEach(lines)` and dismissing any
    /// presented sheet keyed on a stale UUID.
    var id: String { lineNumber }

    let lineNumber: String
    let lineName: String
    let transportType: TransportType
    let incidents: [Incident]
    let lastUpdated: Date

    init(
        lineNumber: String,
        lineName: String = "",
        transportType: TransportType,
        incidents: [Incident] = [],
        lastUpdated: Date = Date()
    ) {
        self.lineNumber = lineNumber
        self.lineName = lineName.isEmpty ? "Linea \(lineNumber)" : lineName
        self.transportType = transportType
        self.incidents = incidents
        self.lastUpdated = lastUpdated
    }

    /// Convenience initializer for single incident (backwards compatibility)
    init(
        lineNumber: String,
        lineName: String = "",
        transportType: TransportType,
        status: ServiceStatus,
        affectedStations: [String] = [],
        additionalInfo: String? = nil,
        lastUpdated: Date = Date()
    ) {
        let incident = Incident(
            status: status,
            affectedStations: affectedStations,
            info: additionalInfo
        )
        self.init(
            lineNumber: lineNumber,
            lineName: lineName,
            transportType: transportType,
            incidents: status == .regular && affectedStations.isEmpty ? [] : [incident],
            lastUpdated: lastUpdated
        )
    }

    // MARK: - Computed Properties

    /// The worst status across all incidents (suspended > intervention > delayed > regular)
    var status: ServiceStatus {
        incidents.map(\.status).max() ?? .regular
    }

    /// All affected stations across all incidents, deduplicated
    var affectedStations: [String] {
        let allStations = incidents.flatMap(\.affectedStations)
        // Preserve order while removing duplicates
        var seen = Set<String>()
        return allStations.filter { seen.insert($0).inserted }
    }

    /// Combined additional info from all incidents
    var additionalInfo: String? {
        let infos = incidents.compactMap(\.info).filter { !$0.isEmpty }
        return infos.isEmpty ? nil : infos.joined(separator: " | ")
    }

    /// Number of distinct incidents on this line
    var incidentCount: Int {
        incidents.count
    }

    /// Indica si hay alguna afectacion en la linea
    var hasIssues: Bool {
        !status.isNormal || !affectedStations.isEmpty
    }

    /// Texto descriptivo del estado
    var statusDescription: String {
        if !hasIssues {
            return "Servicio operando con normalidad"
        }

        if incidents.count == 1 {
            var description = status.rawValue
            if !affectedStations.isEmpty {
                description += " en: \(affectedStations.joined(separator: ", "))"
            }
            return description
        }

        // Multiple incidents
        var description = "\(incidents.count) incidentes activos"
        if !affectedStations.isEmpty {
            description += ". Estaciones afectadas: \(affectedStations.joined(separator: ", "))"
        }
        return description
    }
}

/// Resultado del scraping
struct ScrapingResult {
    let lines: [LineStatus]
    let scrapedAt: Date
    let source: URL
    /// True when the upstream API served cached data because a fresh fetch
    /// failed. Populated from APIMetrobusResponse.stale. Was previously
    /// dropped silently (REVIEW MED-02): callers should surface this to
    /// the user as "datos desactualizados" rather than treating the
    /// response as fresh.
    let isStale: Bool
    /// Upstream's explanation when serving stale or partial data (e.g.
    /// "Failed to fetch fresh data, serving cached response"). Optional;
    /// only present when the API set it.
    let sourceError: String?

    init(lines: [LineStatus], scrapedAt: Date, source: URL, isStale: Bool = false, sourceError: String? = nil) {
        self.lines = lines
        self.scrapedAt = scrapedAt
        self.source = source
        self.isStale = isStale
        self.sourceError = sourceError
    }

    var linesWithIssues: [LineStatus] {
        lines.filter { $0.hasIssues }
    }

    var allLinesNormal: Bool {
        linesWithIssues.isEmpty
    }
}

// MARK: - Scheduled Maintenance Closures

/// Represents a scheduled station closure for maintenance
struct ScheduledClosure: Identifiable, Codable, Hashable {
    let id: UUID
    let lineNumber: String
    let stationName: String
    let direction: ClosureDirection
    let reason: ClosureReason
    let closurePeriod: String
    let parsedDates: [Date]?
    let hours: ClosureHours?

    init(
        lineNumber: String,
        stationName: String,
        direction: ClosureDirection = .both,
        reason: ClosureReason = .maintenance,
        closurePeriod: String,
        parsedDates: [Date]? = nil,
        hours: ClosureHours? = nil
    ) {
        self.id = UUID()
        self.lineNumber = lineNumber
        self.stationName = stationName
        self.direction = direction
        self.reason = reason
        self.closurePeriod = closurePeriod
        self.parsedDates = parsedDates
        self.hours = hours
    }

    /// Check if closure is active for a given date
    func isActive(on date: Date = Date()) -> Bool {
        guard let dates = parsedDates, !dates.isEmpty else {
            // If we couldn't parse dates, assume it might be active
            return true
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        return dates.contains { closureDate in
            calendar.isDate(closureDate, inSameDayAs: today)
        }
    }
}

/// Direction of station closure
enum ClosureDirection: Codable, Hashable {
    case both
    case northbound
    case southbound
    case eastbound
    case westbound
    case custom(String) // For specific terminal directions like "Preparatoria 1"

    init(from text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("ambos") || normalized.contains("ambas") {
            self = .both
        } else if normalized.contains("norte") {
            self = .northbound
        } else if normalized.contains("sur") {
            self = .southbound
        } else if normalized.contains("oriente") {
            self = .eastbound
        } else if normalized.contains("poniente") {
            self = .westbound
        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Keep original text for specific directions like "Preparatoria 1"
            self = .custom(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            self = .custom("N/D")
        }
    }

    var displayName: String {
        switch self {
        case .both: return "Ambos sentidos"
        case .northbound: return "Direccion Norte"
        case .southbound: return "Direccion Sur"
        case .eastbound: return "Direccion Oriente"
        case .westbound: return "Direccion Poniente"
        case .custom(let direction): return direction
        }
    }

    var shortName: String {
        switch self {
        case .both: return "Ambos"
        case .northbound: return "Norte"
        case .southbound: return "Sur"
        case .eastbound: return "Oriente"
        case .westbound: return "Poniente"
        case .custom(let direction):
            // Truncate if too long
            if direction.count > 15 {
                return String(direction.prefix(12)) + "..."
            }
            return direction
        }
    }
}

/// Reason for station closure
enum ClosureReason: String, Codable {
    case majorMaintenance = "Mantenimiento Mayor"
    case maintenance = "Mantenimiento"
    case construction = "Obra"
    case other = "Otro"

    init(from text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("mayor") {
            self = .majorMaintenance
        } else if normalized.contains("mantenimiento") {
            self = .maintenance
        } else if normalized.contains("obra") {
            self = .construction
        } else {
            self = .other
        }
    }

    var displayName: String {
        rawValue
    }
}

/// Hours during which a closure is in effect
struct ClosureHours: Codable, Hashable {
    let startHour: Int?
    let endHour: Int?
    let description: String

    /// True if closure is until end of service
    var untilClose: Bool {
        description.lowercased().contains("cierre")
    }

    init(startHour: Int? = nil, endHour: Int? = nil, description: String = "") {
        self.startHour = startHour
        self.endHour = endHour
        self.description = description
    }
}

/// Result of fetching maintenance closures
struct MaintenanceResult {
    let closures: [ScheduledClosure]
    let scrapedAt: Date
    let source: URL

    /// Closures affecting a specific line
    func closures(forLine lineNumber: String) -> [ScheduledClosure] {
        closures.filter { $0.lineNumber == lineNumber }
    }

    /// Closures that are active today
    var activeClosures: [ScheduledClosure] {
        closures.filter { $0.isActive() }
    }

    /// Group closures by line number
    var closuresByLine: [String: [ScheduledClosure]] {
        Dictionary(grouping: closures, by: \.lineNumber)
    }
}
