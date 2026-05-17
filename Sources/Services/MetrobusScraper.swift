import Foundation
import SwiftSoup

/// Errores del scraper
enum ScraperError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Error al parsear: \(message)"
        case .noData:
            return "No se encontraron datos"
        }
    }
}

/// Scraper para el estado del Metrobús CDMX
actor MetrobusScraper {

    // MARK: - Constants

    private let baseURL = "https://incidentesmovilidad.cdmx.gob.mx/public/bandejaEstadoServicio.xhtml"
    private let maintenanceURL = "https://www.metrobus.cdmx.gob.mx/ServicioMB"
    private let maxRetries = 2
    private let retryDelay: UInt64 = 2_000_000_000 // 2 segundos

    // MARK: - Browser Simulation

    /// User agents reales de Safari iOS para rotar
    private let userAgents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
    ]

    /// Session configurada como browser real
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default

        // Comportamiento de cache como browser
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        // Timeouts razonables
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        // Headers por defecto que envía un browser
        config.httpAdditionalHeaders = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": "es-MX,es;q=0.9,en;q=0.8",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
        ]

        // Permitir cookies como browser
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true

        return URLSession(configuration: config)
    }()

    // MARK: - Public Methods

    /// Obtiene el estado de todas las líneas del Metrobús
    func fetchStatus() async throws -> ScrapingResult {
        let url = try buildURL(for: .metrobus)
        let html = try await fetchHTMLWithRetry(from: url)
        let lines = try parseHTML(html, transportType: .metrobus)

        return ScrapingResult(
            lines: lines,
            scrapedAt: Date(),
            source: url
        )
    }

    /// Obtiene el estado de una línea específica
    func fetchStatus(forLine lineNumber: String) async throws -> LineStatus? {
        let result = try await fetchStatus()
        return result.lines.first { $0.lineNumber == lineNumber }
    }

    // MARK: - Maintenance Closures

    /// Fetches scheduled maintenance closures from metrobus.cdmx.gob.mx
    func fetchMaintenanceClosures() async throws -> MaintenanceResult {
        guard let url = URL(string: maintenanceURL) else {
            throw ScraperError.invalidURL
        }

        let html = try await fetchHTMLWithRetry(from: url)
        let closures = try parseMaintenanceHTML(html)

        return MaintenanceResult(
            closures: closures,
            scrapedAt: Date(),
            source: url
        )
    }

    /// Fetches closures for a specific line
    func fetchMaintenanceClosures(forLine lineNumber: String) async throws -> [ScheduledClosure] {
        let result = try await fetchMaintenanceClosures()
        return result.closures(forLine: lineNumber)
    }

    // MARK: - Private Methods

    private func buildURL(for transportType: TransportType) throws -> URL {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "idMedioTransporte", value: transportType.rawValue)
        ]

        guard let url = components?.url else {
            throw ScraperError.invalidURL
        }
        return url
    }

    private func fetchHTMLWithRetry(from url: URL) async throws -> String {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await fetchHTML(from: url)
            } catch {
                lastError = error

                // No reintentar si es error de parsing o datos vacíos
                if case ScraperError.parsingError = error { throw error }
                if case ScraperError.noData = error { throw error }

                // Esperar antes de reintentar
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: retryDelay)
                }
            }
        }

        throw lastError ?? ScraperError.networkError(NSError(domain: "Unknown", code: -1))
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)

        // User-Agent rotativo
        request.setValue(userAgents.randomElement()!, forHTTPHeaderField: "User-Agent")

        // Headers adicionales que envía Safari
        request.setValue(url.host, forHTTPHeaderField: "Host")
        request.setValue("https://\(url.host ?? "")/", forHTTPHeaderField: "Referer")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ScraperError.networkError(NSError(domain: "HTTP", code: -1))
            }

            // Manejar redirects y errores HTTP
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 429:
                throw ScraperError.networkError(NSError(domain: "HTTP", code: 429, userInfo: [
                    NSLocalizedDescriptionKey: "Demasiadas solicitudes, intenta más tarde"
                ]))
            case 503:
                throw ScraperError.networkError(NSError(domain: "HTTP", code: 503, userInfo: [
                    NSLocalizedDescriptionKey: "Servicio temporalmente no disponible"
                ]))
            default:
                throw ScraperError.networkError(NSError(domain: "HTTP", code: httpResponse.statusCode))
            }

            guard let html = String(data: data, encoding: .utf8) else {
                throw ScraperError.parsingError("No se pudo decodificar el HTML")
            }

            return html
        } catch let error as ScraperError {
            throw error
        } catch {
            throw ScraperError.networkError(error)
        }
    }

    private func parseHTML(_ html: String, transportType: TransportType) throws -> [LineStatus] {
        let document = try SwiftSoup.parse(html)

        // Buscar la tabla de datos
        // El ID del formulario es: frmEstadoServicio:tblEstadoServicio
        guard let table = try document.select("table.ui-datatable-data, tbody.ui-datatable-data").first() else {
            // Intentar selector alternativo
            guard let tableAlt = try document.select("[id*='tblEstadoServicio'] tbody").first() else {
                throw ScraperError.parsingError("No se encontró la tabla de estado")
            }
            return try parseTableRows(tableAlt, transportType: transportType)
        }

        return try parseTableRows(table, transportType: transportType)
    }

    private func parseTableRows(_ tableBody: Element, transportType: TransportType) throws -> [LineStatus] {
        let rows = try tableBody.select("tr")

        guard !rows.isEmpty() else {
            throw ScraperError.noData
        }

        // Parse all rows into (lineNumber, incident) tuples
        var incidentsByLine: [String: [Incident]] = [:]
        var lineOrder: [String] = [] // Preserve order of first appearance

        for row in rows {
            if let (lineNumber, incident) = try? parseRowToIncident(row) {
                if incidentsByLine[lineNumber] == nil {
                    lineOrder.append(lineNumber)
                    incidentsByLine[lineNumber] = []
                }
                incidentsByLine[lineNumber]?.append(incident)
            }
        }

        // Build LineStatus objects grouped by line number
        return lineOrder.compactMap { lineNumber -> LineStatus? in
            guard let incidents = incidentsByLine[lineNumber] else { return nil }

            // Filter out "regular" incidents with no affected stations
            // (they don't add meaningful information)
            let meaningfulIncidents = incidents.filter { incident in
                incident.status != .regular || !incident.affectedStations.isEmpty
            }

            return LineStatus(
                lineNumber: lineNumber,
                transportType: transportType,
                incidents: meaningfulIncidents
            )
        }
    }

    /// Parses a single row and returns the line number and incident data
    private func parseRowToIncident(_ row: Element) throws -> (lineNumber: String, incident: Incident) {
        let cells = try row.select("td")

        guard cells.size() >= 4 else {
            throw ScraperError.parsingError("Fila con formato incorrecto")
        }

        // Columna 1: Linea (extraer del icono o texto)
        let lineNumber = try extractLineNumber(from: cells.get(0))

        // Columna 2: Estado
        let statusText = try cells.get(1).text()
        let status = ServiceStatus(from: statusText)

        // Columna 3: Estaciones afectadas
        let stationsText = try cells.get(2).text()
        let affectedStations = parseStations(stationsText)

        // Columna 4: Informacion adicional
        let additionalInfo = try cells.get(3).text()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let incident = Incident(
            status: status,
            affectedStations: affectedStations,
            info: additionalInfo.isEmpty ? nil : additionalInfo
        )

        return (lineNumber, incident)
    }

    private func extractLineNumber(from cell: Element) throws -> String {
        // Intentar extraer del atributo src de la imagen (e.g., MB1.png -> 1)
        if let img = try cell.select("img").first(),
           let src = try? img.attr("src") {
            // Extraer número del nombre del archivo: MB1.png, MB2.png, etc.
            let filename = (src as NSString).lastPathComponent
            let pattern = #"MB(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
               let range = Range(match.range(at: 1), in: filename) {
                return String(filename[range])
            }
        }

        // Fallback: usar el texto de la celda
        let text = try cell.text().trimmingCharacters(in: .whitespacesAndNewlines)

        // Buscar patrones como "Línea 1", "L1", "1", etc.
        let patterns = [#"[Ll]ínea\s*(\d+)"#, #"[Ll](\d+)"#, #"(\d+)"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return text.isEmpty ? "?" : text
    }

    private func parseStations(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              trimmed.lowercased() != "n/a",
              trimmed != "-" else {
            return []
        }

        // Separar por comas o "y"
        return trimmed
            .replacingOccurrences(of: " y ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Maintenance Parsing

    private func parseMaintenanceHTML(_ html: String) throws -> [ScheduledClosure] {
        let document = try SwiftSoup.parse(html)

        var closures: [ScheduledClosure] = []

        // Find all tables and check if they have maintenance-like structure
        let allTables = try document.select("table")

        var maintenanceTable: Element?

        for table in allTables {
            // Check headers for maintenance-related keywords
            let headers = try table.select("th, thead td").map { try $0.text().lowercased() }
            let headerText = headers.joined(separator: " ")

            // Look for maintenance table: must have station (estación) and period (periodo) columns
            if headerText.contains("estaci") && headerText.contains("periodo") {
                maintenanceTable = table
                break
            }

            // Also try: linea + estacion
            if headerText.contains("linea") && headerText.contains("estaci") {
                maintenanceTable = table
                break
            }
        }

        // If no table with headers found, try collapse containers
        if maintenanceTable == nil {
            // Try specific collapse IDs that might contain maintenance info
            let collapseSelectors = ["#collapse1499", "#collapse1389", "[id^=collapse]"]

            for selector in collapseSelectors {
                if let collapse = try? document.select(selector).first(),
                   let table = try? collapse.select("table").first() {
                    let rowCount = try table.select("tbody tr").size()
                    if rowCount > 0 {
                        maintenanceTable = table
                        break
                    }
                }
            }
        }

        guard let table = maintenanceTable else {
            // No maintenance closures found - this is not an error, just empty data
            return []
        }

        // Parse table rows
        let rows = try table.select("tbody tr")

        for row in rows {
            if let closure = try? parseMaintenanceRow(row) {
                closures.append(closure)
            }
        }

        return closures
    }

    private func parseMaintenanceRow(_ row: Element) throws -> ScheduledClosure {
        let cells = try row.select("td")

        // Expected columns: Linea | Estacion | Sentido | Razon | Periodo de cierre
        guard cells.size() >= 5 else {
            throw ScraperError.parsingError("Maintenance row has insufficient columns")
        }

        // Column 0: Line number
        let lineText = try cells.get(0).text()
        let lineNumber = extractLineNumberFromText(lineText)

        // Column 1: Station name
        let stationName = try cells.get(1).text()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Column 2: Direction
        let directionText = try cells.get(2).text()
        let direction = ClosureDirection(from: directionText)

        // Column 3: Reason
        let reasonText = try cells.get(3).text()
        let reason = ClosureReason(from: reasonText)

        // Column 4: Closure period (dates and possibly hours)
        let periodText = try cells.get(4).text()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse dates and hours from period text
        let (parsedDates, hours) = parseClosurePeriod(periodText)

        return ScheduledClosure(
            lineNumber: lineNumber,
            stationName: stationName,
            direction: direction,
            reason: reason,
            closurePeriod: periodText,
            parsedDates: parsedDates,
            hours: hours
        )
    }

    private func extractLineNumberFromText(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try patterns: "Linea 1", "L1", "1", "Linea 1"
        let patterns = [#"[Ll][ií]nea\s*(\d+)"#, #"[Ll](\d+)"#, #"(\d+)"#]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
               let range = Range(match.range(at: 1), in: normalized) {
                return String(normalized[range])
            }
        }

        return normalized.isEmpty ? "?" : normalized
    }

    /// Parses closure period text into dates and hours
    /// Examples:
    /// - "4 y 5 de Diciembre"
    /// - "8 de diciembre, de las 20 horas al cierre"
    /// - "Del 2 al 6 de diciembre"
    private func parseClosurePeriod(_ text: String) -> (dates: [Date]?, hours: ClosureHours?) {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        var parsedDates: [Date] = []
        var hours: ClosureHours?

        // Extract hour information if present
        // Pattern: "de las XX horas al cierre" or "de XX a YY horas"
        let hourPattern = #"(?:de\s+las?\s+)?(\d{1,2})\s*(?:horas?)?(?:\s+(?:al?\s+)?(?:cierre|(\d{1,2})\s*(?:horas?)?))"#
        if let hourRegex = try? NSRegularExpression(pattern: hourPattern, options: .caseInsensitive),
           let match = hourRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let startHour = Int(text[Range(match.range(at: 1), in: text)!])

            var endHour: Int?
            if match.range(at: 2).location != NSNotFound,
               let range = Range(match.range(at: 2), in: text) {
                endHour = Int(text[range])
            }

            // Check if it says "al cierre"
            let matchText = text[Range(match.range, in: text)!]
            let untilClose = matchText.lowercased().contains("cierre")

            hours = ClosureHours(
                startHour: startHour,
                endHour: endHour,
                description: untilClose ? "hasta el cierre" : ""
            )
        }

        // Spanish month names to month numbers
        let monthMap: [String: Int] = [
            "enero": 1, "febrero": 2, "marzo": 3, "abril": 4,
            "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
            "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12
        ]

        // Try to find month in text
        var month: Int?
        for (name, num) in monthMap {
            if text.lowercased().contains(name) {
                month = num
                break
            }
        }

        guard let foundMonth = month else {
            return (nil, hours)
        }

        // Pattern: "X y Y de Mes" or "X, Y y Z de Mes"
        let multiDayPattern = #"(\d{1,2})(?:\s*[,y]\s*(\d{1,2}))*\s+de\s+"#
        if let regex = try? NSRegularExpression(pattern: multiDayPattern, options: .caseInsensitive) {
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in results {
                // Extract all day numbers from this match
                let matchStr = String(text[Range(match.range, in: text)!])
                let dayPattern = #"(\d{1,2})"#
                if let dayRegex = try? NSRegularExpression(pattern: dayPattern) {
                    let dayMatches = dayRegex.matches(in: matchStr, range: NSRange(matchStr.startIndex..., in: matchStr))
                    for dayMatch in dayMatches {
                        if let range = Range(dayMatch.range(at: 1), in: matchStr),
                           let day = Int(matchStr[range]) {
                            var components = DateComponents()
                            components.year = currentYear
                            components.month = foundMonth
                            components.day = day

                            if let date = calendar.date(from: components) {
                                parsedDates.append(date)
                            }
                        }
                    }
                }
            }
        }

        // Pattern: "Del X al Y de Mes" - date range
        let rangePattern = #"[Dd]el\s+(\d{1,2})\s+al\s+(\d{1,2})"#
        if let regex = try? NSRegularExpression(pattern: rangePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let startRange = Range(match.range(at: 1), in: text),
               let endRange = Range(match.range(at: 2), in: text),
               let startDay = Int(text[startRange]),
               let endDay = Int(text[endRange]) {
                // Generate all dates in range
                for day in startDay...endDay {
                    var components = DateComponents()
                    components.year = currentYear
                    components.month = foundMonth
                    components.day = day

                    if let date = calendar.date(from: components) {
                        parsedDates.append(date)
                    }
                }
            }
        }

        // If no multi-day pattern matched, try single day
        if parsedDates.isEmpty {
            let singleDayPattern = #"(\d{1,2})\s+de\s+"#
            if let regex = try? NSRegularExpression(pattern: singleDayPattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let day = Int(text[range]) {
                var components = DateComponents()
                components.year = currentYear
                components.month = foundMonth
                components.day = day

                if let date = calendar.date(from: components) {
                    parsedDates.append(date)
                }
            }
        }

        return (parsedDates.isEmpty ? nil : parsedDates, hours)
    }
}

// MARK: - Preview/Testing Helper

#if DEBUG
extension MetrobusScraper {
    /// Datos de ejemplo para previews y testing
    static var mockData: [LineStatus] {
        [
            LineStatus(
                lineNumber: "1",
                transportType: .metrobus,
                status: .regular,
                affectedStations: []
            ),
            LineStatus(
                lineNumber: "2",
                transportType: .metrobus,
                status: .intervention,
                affectedStations: ["La Joya", "Iztacalco"],
                additionalInfo: "Por mantenimiento a la estacion"
            ),
            LineStatus(
                lineNumber: "3",
                transportType: .metrobus,
                status: .regular,
                affectedStations: []
            ),
            LineStatus(
                lineNumber: "4",
                transportType: .metrobus,
                status: .delayed,
                affectedStations: ["Buenavista"],
                additionalInfo: "Manifestacion en inmediaciones"
            ),
        ]
    }

    /// Mock maintenance closure data for previews and testing
    static var mockMaintenanceData: [ScheduledClosure] {
        [
            ScheduledClosure(
                lineNumber: "1",
                stationName: "Manuel Gonzalez",
                direction: .both,
                reason: .majorMaintenance,
                closurePeriod: "4 y 5 de Diciembre",
                parsedDates: nil,
                hours: nil
            ),
            ScheduledClosure(
                lineNumber: "1",
                stationName: "Buenavista",
                direction: .northbound,
                reason: .maintenance,
                closurePeriod: "8 de diciembre, de las 20 horas al cierre",
                parsedDates: nil,
                hours: ClosureHours(startHour: 20, endHour: nil, description: "hasta el cierre")
            ),
            ScheduledClosure(
                lineNumber: "3",
                stationName: "Etiopía",
                direction: .both,
                reason: .majorMaintenance,
                closurePeriod: "Del 2 al 6 de diciembre",
                parsedDates: nil,
                hours: nil
            ),
        ]
    }
}
#endif
